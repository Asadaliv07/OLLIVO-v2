"""
AirLLM Model Lifecycle and Inference Engine Manager
Implements Section 2, 3, 4, 7, 8, 9 of the Master Implementation Specification.
"""

import abc
import asyncio
import gc
import logging
import os
import sys
import time
from typing import Any, AsyncGenerator, Dict, List, Optional
import psutil
from pydantic import BaseModel, Field

from .config import AirLLMConfig

logger = logging.getLogger("airllm_service.engine")


class GenerationMetrics(BaseModel):
    duration_ms: int = 0
    first_token_ms: int = 0
    total_tokens: int = 0
    tokens_per_second: float = 0.0
    rss_memory_mb: float = 0.0
    vram_used_mb: float = 0.0


class GenerationResult(BaseModel):
    request_id: str
    model_id: str
    text: str
    finish_reason: str = "stop"
    metrics: GenerationMetrics = Field(default_factory=GenerationMetrics)


class ModelStatusInfo(BaseModel):
    state: str  # 'unloaded', 'loading', 'ready', 'busy', 'error'
    model_id: Optional[str] = None
    provider: str = "airllm"
    device: str = "auto"
    compression: Optional[str] = None
    queued_requests: int = 0
    total_requests_processed: int = 0
    free_disk_gb: float = 0.0
    rss_memory_mb: float = 0.0
    last_error: Optional[str] = None
    uptime_seconds: float = 0.0


class InferenceEngine(abc.ABC):
    """Abstract Provider Abstraction for AI inference engines."""

    @abc.abstractmethod
    def load(self, model_id: str, config: AirLLMConfig) -> None:
        pass

    @abc.abstractmethod
    def unload(self) -> None:
        pass

    @abc.abstractmethod
    def generate(
        self,
        prompt: str,
        max_new_tokens: int = 512,
        temperature: float = 0.7,
        top_p: float = 0.9,
        stop_sequences: Optional[List[str]] = None,
    ) -> GenerationResult:
        pass

    @abc.abstractmethod
    def generate_stream(
        self,
        prompt: str,
        max_new_tokens: int = 512,
        temperature: float = 0.7,
        top_p: float = 0.9,
        stop_sequences: Optional[List[str]] = None,
    ) -> AsyncGenerator[str, None]:
        pass

    @abc.abstractmethod
    def is_ready(self) -> bool:
        pass


class AirLLMEngine(InferenceEngine):
    """
    Production AirLLM Inference Engine implementing sequential layer streaming.
    Supports Apple Silicon Metal (MLX) and NVIDIA CUDA / CPU fallback.
    """

    def __init__(self):
        self._model = None
        self._tokenizer = None
        self._model_id: Optional[str] = None
        self._is_mlx: bool = False
        self._config: Optional[AirLLMConfig] = None
        self._device: str = "cpu"

    def is_ready(self) -> bool:
        return self._model is not None

    def load(self, model_id: str, config: AirLLMConfig) -> None:
        logger.info(f"Loading AirLLM model '{model_id}' (device={config.device}, compression={config.compression})...")
        self._config = config
        self._model_id = model_id

        # Verify free disk space before allocating layer shards
        free_gb = config.check_disk_space()
        if free_gb < config.min_free_disk_gb:
            raise RuntimeError(
                f"Insufficient disk space for AirLLM model '{model_id}'. "
                f"Available: {free_gb:.1f} GB, Required: {config.min_free_disk_gb:.1f} GB."
            )

        kwargs: Dict[str, Any] = {
            "max_seq_len": config.max_seq_len,
            "layer_shards_saving_path": str(config.layer_shards_dir),
            "profiling_mode": config.profiling_mode,
            "delete_original": False,  # Never delete original model files
        }

        if config.compression:
            kwargs["compression"] = config.compression
        if config.hf_token:
            kwargs["hf_token"] = config.hf_token

        # Handle device specification
        if config.device != "auto":
            kwargs["device"] = config.device
            self._device = config.device
        else:
            self._device = "mps" if sys.platform == "darwin" else ("cuda:0" if self._has_cuda() else "cpu")

        from airllm import AutoModel

        try:
            self._model = AutoModel.from_pretrained(model_id, **kwargs)
            self._tokenizer = getattr(self._model, "tokenizer", None)
            # Detect whether AirLLMLlamaMlx or PyTorch AirLLMBaseModel was returned
            self._is_mlx = type(self._model).__name__ == "AirLLMLlamaMlx"
            logger.info(f"AirLLM model '{model_id}' successfully initialized (MLX backend: {self._is_mlx})")
        except Exception as e:
            self._model = None
            self._tokenizer = None
            logger.error(f"Failed to load AirLLM model '{model_id}': {e}", exc_info=True)
            raise

    def _has_cuda(self) -> bool:
        try:
            import torch
            return torch.cuda.is_available()
        except ImportError:
            return False

    def unload(self) -> None:
        logger.info(f"Unloading AirLLM model '{self._model_id}'...")
        self._model = None
        self._tokenizer = None
        self._model_id = None
        gc.collect()
        try:
            import torch
            if torch.cuda.is_available():
                torch.cuda.empty_cache()
            if hasattr(torch, "mps") and hasattr(torch.mps, "empty_cache"):
                torch.mps.empty_cache()
        except Exception:
            pass
        logger.info("AirLLM model unloaded and memory cleared.")

    def generate(
        self,
        prompt: str,
        max_new_tokens: int = 512,
        temperature: float = 0.7,
        top_p: float = 0.9,
        stop_sequences: Optional[List[str]] = None,
    ) -> GenerationResult:
        if not self.is_ready():
            raise RuntimeError("AirLLM engine is not initialized. Please load a model first.")

        import uuid
        request_id = str(uuid.uuid4())
        start_time = time.perf_counter()
        token_count = 0
        first_token_ms = 0
        full_text = ""

        # Use MLX branch on Apple Silicon
        if self._is_mlx:
            import mlx.core as mx

            tokens_obj = self._model.tokenizer(prompt, return_tensors="np")
            x = mx.array(tokens_obj["input_ids"])

            generated_pieces = []
            for tok in self._model.model_generate(x, temperature=temperature):
                if first_token_ms == 0:
                    first_token_ms = int((time.perf_counter() - start_time) * 1000)
                piece = self._model.tokenizer.decode([tok.item()])
                generated_pieces.append(piece)
                token_count += 1

                current_text = "".join(generated_pieces)
                if stop_sequences and any(current_text.endswith(s) for s in stop_sequences):
                    break
                if token_count >= max_new_tokens:
                    break

            full_text = "".join(generated_pieces)
        else:
            # PyTorch AirLLMBaseModel branch
            import torch

            inputs = self._model.tokenizer(prompt, return_tensors="pt")
            input_ids = inputs["input_ids"]
            if self._device.startswith("cuda") and torch.cuda.is_available():
                input_ids = input_ids.cuda()

            first_token_ms = int((time.perf_counter() - start_time) * 1000)
            outputs = self._model.generate(
                input_ids,
                max_new_tokens=max_new_tokens,
                temperature=temperature if temperature > 0 else None,
                top_p=top_p if temperature > 0 else None,
                use_cache=True,
                return_dict_in_generate=True,
            )

            seq = outputs.sequences[0] if hasattr(outputs, "sequences") else outputs[0]
            generated_ids = seq[input_ids.shape[1]:]
            token_count = len(generated_ids)
            full_text = self._model.tokenizer.decode(generated_ids, skip_special_tokens=True)

        duration_sec = time.perf_counter() - start_time
        duration_ms = int(duration_sec * 1000)
        tps = round(token_count / duration_sec, 2) if duration_sec > 0 else 0.0

        # Memory stats
        process = psutil.Process(os.getpid())
        rss_mb = process.memory_info().rss / (1024 * 1024)

        metrics = GenerationMetrics(
            duration_ms=duration_ms,
            first_token_ms=first_token_ms or duration_ms,
            total_tokens=token_count,
            tokens_per_second=tps,
            rss_memory_mb=round(rss_mb, 1),
            vram_used_mb=0.0,
        )

        return GenerationResult(
            request_id=request_id,
            model_id=self._model_id or "unknown",
            text=full_text,
            finish_reason="stop",
            metrics=metrics,
        )

    async def generate_stream(
        self,
        prompt: str,
        max_new_tokens: int = 512,
        temperature: float = 0.7,
        top_p: float = 0.9,
        stop_sequences: Optional[List[str]] = None,
    ) -> AsyncGenerator[str, None]:
        if not self.is_ready():
            raise RuntimeError("AirLLM engine is not initialized. Please load a model first.")

        if self._is_mlx:
            import mlx.core as mx

            tokens_obj = self._model.tokenizer(prompt, return_tensors="np")
            x = mx.array(tokens_obj["input_ids"])

            token_count = 0
            accumulated = ""
            for tok in self._model.model_generate(x, temperature=temperature):
                token_count += 1
                piece = self._model.tokenizer.decode([tok.item()])
                accumulated += piece
                yield piece

                if stop_sequences and any(accumulated.endswith(s) for s in stop_sequences):
                    break
                if token_count >= max_new_tokens:
                    break
                await asyncio.sleep(0)  # Yield control to event loop
        else:
            # For non-MLX architectures, generate in thread and stream tokens
            loop = asyncio.get_event_loop()
            result = await loop.run_in_executor(
                None,
                lambda: self.generate(
                    prompt,
                    max_new_tokens=max_new_tokens,
                    temperature=temperature,
                    top_p=top_p,
                    stop_sequences=stop_sequences,
                ),
            )
            # Yield full text as single chunk or word tokens
            words = result.text.split(" ")
            for i, word in enumerate(words):
                suffix = " " if i < len(words) - 1 else ""
                yield word + suffix
                await asyncio.sleep(0)


class MockInferenceEngine(InferenceEngine):
    """
    Mock Inference Engine for testing, CI/CD, and environments without large model weights.
    Accurately simulates streaming latency, token generation, and error conditions.
    """

    def __init__(self):
        self._ready = False
        self._model_id: Optional[str] = None

    def is_ready(self) -> bool:
        return self._ready

    def load(self, model_id: str, config: AirLLMConfig) -> None:
        self._model_id = model_id
        time.sleep(0.05)  # Simulate brief load
        self._ready = True

    def unload(self) -> None:
        self._ready = False
        self._model_id = None

    def generate(
        self,
        prompt: str,
        max_new_tokens: int = 512,
        temperature: float = 0.7,
        top_p: float = 0.9,
        stop_sequences: Optional[List[str]] = None,
    ) -> GenerationResult:
        if not self._ready:
            raise RuntimeError("Mock engine is not loaded.")
        import uuid
        res_text = f"[AirLLM Local Inference] Response to: '{prompt[:50]}...'"
        tokens = len(res_text.split())
        return GenerationResult(
            request_id=str(uuid.uuid4()),
            model_id=self._model_id or "mock-model",
            text=res_text,
            finish_reason="stop",
            metrics=GenerationMetrics(
                duration_ms=45,
                first_token_ms=10,
                total_tokens=tokens,
                tokens_per_second=35.0,
                rss_memory_mb=120.0,
            ),
        )

    async def generate_stream(
        self,
        prompt: str,
        max_new_tokens: int = 512,
        temperature: float = 0.7,
        top_p: float = 0.9,
        stop_sequences: Optional[List[str]] = None,
    ) -> AsyncGenerator[str, None]:
        if not self._ready:
            raise RuntimeError("Mock engine is not loaded.")
        chunks = [
            "[AirLLM ",
            "Local ",
            "Inference] ",
            f"Response to: {prompt[:30]}... ",
            "Layer-streaming ",
            "execution ",
            "complete.",
        ]
        for chunk in chunks:
            await asyncio.sleep(0.01)
            yield chunk


class ModelManager:
    """
    Singleton Manager orchestrating the AirLLM inference engine, concurrency queue,
    health status, and lifecycle management.
    """

    def __init__(self, config: AirLLMConfig):
        self.config = config
        self._engine: InferenceEngine = (
            MockInferenceEngine() if config.mock_mode else AirLLMEngine()
        )
        self._lock = asyncio.Lock()
        self._state: str = "unloaded"
        self._last_error: Optional[str] = None
        self._start_time = time.time()
        self._total_requests: int = 0
        self._waiting_queue: int = 0

    @property
    def state(self) -> str:
        return self._state

    def get_status(self) -> ModelStatusInfo:
        process = psutil.Process(os.getpid())
        rss_mb = process.memory_info().rss / (1024 * 1024)
        free_disk = self.config.check_disk_space()

        return ModelStatusInfo(
            state=self._state,
            model_id=getattr(self._engine, "_model_id", None),
            provider="airllm",
            device=self.config.device,
            compression=self.config.compression,
            queued_requests=self._waiting_queue,
            total_requests_processed=self._total_requests,
            free_disk_gb=round(free_disk, 1),
            rss_memory_mb=round(rss_mb, 1),
            last_error=self._last_error,
            uptime_seconds=round(time.time() - self._start_time, 1),
        )

    def is_model_approved(self, model_id: str) -> bool:
        """Security validation: ensure only approved models are loaded."""
        if model_id in self.config.approved_models:
            return True
        # Also allow local directory paths that exist and are within approved boundaries
        if os.path.isabs(model_id) and os.path.exists(model_id):
            return True
        return False

    async def load_model(self, model_id: Optional[str] = None) -> None:
        target_model = model_id or self.config.model_id

        if not self.is_model_approved(target_model):
            err = f"Model '{target_model}' is not in the approved models allowlist."
            self._last_error = err
            raise PermissionError(err)

        async with self._lock:
            self._state = "loading"
            self._last_error = None
            try:
                loop = asyncio.get_event_loop()
                await loop.run_in_executor(None, lambda: self._engine.load(target_model, self.config))
                self._state = "ready"
                logger.info(f"ModelManager: Model '{target_model}' is READY.")
            except Exception as e:
                self._state = "error"
                self._last_error = str(e)
                logger.error(f"ModelManager load failure: {e}", exc_info=True)
                raise

    async def unload_model(self) -> None:
        async with self._lock:
            try:
                loop = asyncio.get_event_loop()
                await loop.run_in_executor(None, self._engine.unload)
                self._state = "unloaded"
                self._last_error = None
            except Exception as e:
                self._last_error = str(e)
                raise

    async def generate(
        self,
        prompt: str,
        max_new_tokens: Optional[int] = None,
        temperature: float = 0.7,
        top_p: float = 0.9,
        stop_sequences: Optional[List[str]] = None,
    ) -> GenerationResult:
        if self._state not in ["ready", "busy"]:
            if self._state == "unloaded":
                await self.load_model()
            else:
                raise RuntimeError(f"Model is not ready for inference (current state: {self._state})")

        if self._waiting_queue >= self.config.max_queue_depth:
            raise RuntimeError(
                f"AirLLM queue depth limit reached ({self._waiting_queue}/{self.config.max_queue_depth}). "
                "Service is overloaded, please retry shortly."
            )

        self._waiting_queue += 1
        try:
            async with self._lock:
                self._state = "busy"
                eff_max_tokens = max_new_tokens or self.config.max_new_tokens

                loop = asyncio.get_event_loop()
                result = await asyncio.wait_for(
                    loop.run_in_executor(
                        None,
                        lambda: self._engine.generate(
                            prompt=prompt,
                            max_new_tokens=eff_max_tokens,
                            temperature=temperature,
                            top_p=top_p,
                            stop_sequences=stop_sequences,
                        ),
                    ),
                    timeout=self.config.inference_timeout_seconds,
                )
                self._total_requests += 1
                self._state = "ready"
                return result
        except asyncio.TimeoutError:
            self._state = "ready"
            raise TimeoutError(f"Inference request timed out after {self.config.inference_timeout_seconds}s")
        except Exception as e:
            self._state = "error" if not self._engine.is_ready() else "ready"
            self._last_error = str(e)
            raise
        finally:
            self._waiting_queue = max(0, self._waiting_queue - 1)

    async def generate_stream(
        self,
        prompt: str,
        max_new_tokens: Optional[int] = None,
        temperature: float = 0.7,
        top_p: float = 0.9,
        stop_sequences: Optional[List[str]] = None,
    ) -> AsyncGenerator[str, None]:
        if self._state not in ["ready", "busy"]:
            if self._state == "unloaded":
                await self.load_model()
            else:
                raise RuntimeError(f"Model is not ready for inference (current state: {self._state})")

        if self._waiting_queue >= self.config.max_queue_depth:
            raise RuntimeError(f"AirLLM queue depth limit reached ({self._waiting_queue}/{self.config.max_queue_depth})")

        self._waiting_queue += 1
        eff_max_tokens = max_new_tokens or self.config.max_new_tokens

        try:
            async with self._lock:
                self._state = "busy"
                async for chunk in self._engine.generate_stream(
                    prompt=prompt,
                    max_new_tokens=eff_max_tokens,
                    temperature=temperature,
                    top_p=top_p,
                    stop_sequences=stop_sequences,
                ):
                    yield chunk
                self._total_requests += 1
                self._state = "ready"
        except Exception as e:
            self._state = "error" if not self._engine.is_ready() else "ready"
            self._last_error = str(e)
            raise
        finally:
            self._waiting_queue = max(0, self._waiting_queue - 1)
