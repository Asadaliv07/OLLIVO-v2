"""
FastAPI REST & Streaming API for AirLLM Inference Service
Implements Section 5 of the Master Implementation Specification.
"""

import json
import logging
import time
from typing import Any, Dict, List, Optional
from fastapi import FastAPI, HTTPException, Request, Response, Security, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import StreamingResponse
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

from .config import AirLLMConfig
from .model_manager import ModelManager, ModelStatusInfo

logger = logging.getLogger("airllm_service.api")


# --- Request and Response Schemas ---

class GenerateRequest(BaseModel):
    prompt: str = Field(..., min_length=1, max_length=131072, description="Input prompt text")
    model: Optional[str] = Field(default=None, description="Requested model identifier")
    max_tokens: Optional[int] = Field(default=None, ge=1, le=8192, description="Maximum new tokens to generate")
    temperature: float = Field(default=0.7, ge=0.0, le=2.0, description="Sampling temperature")
    top_p: float = Field(default=0.9, ge=0.0, le=1.0, description="Nucleus sampling threshold")
    stop: Optional[List[str]] = Field(default=None, description="Stop sequence strings")
    stream: bool = Field(default=False, description="Enable streaming response")


class GenerateResponse(BaseModel):
    id: str
    model: str
    text: str
    finish_reason: str = "stop"
    metrics: Dict[str, Any] = Field(default_factory=dict)


class ModelLoadRequest(BaseModel):
    model_id: str = Field(..., description="Approved model identifier to load")


class OllamaGenerateOptions(BaseModel):
    num_predict: Optional[int] = None
    temperature: Optional[float] = None
    top_p: Optional[float] = None
    stop: Optional[List[str]] = None


class OllamaGenerateRequest(BaseModel):
    model: Optional[str] = None
    prompt: str = Field(default="", max_length=131072, description="Input prompt text")
    system: Optional[str] = None
    stream: bool = Field(default=True)
    options: Optional[Dict[str, Any]] = None


from contextlib import asynccontextmanager

# --- FastAPI Factory ---

def create_app(config: Optional[AirLLMConfig] = None, model_manager: Optional[ModelManager] = None) -> FastAPI:
    cfg = config or AirLLMConfig.from_env()
    manager = model_manager or ModelManager(cfg)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        logger.info(f"AirLLM Service starting up on {cfg.host}:{cfg.port}")
        if cfg.auto_warmup_on_startup:
            logger.info("Auto warmup requested: preloading default model...")
            try:
                await manager.load_model()
            except Exception as e:
                logger.error(f"Startup model load failed: {e}")
        yield
        logger.info("AirLLM Service shutting down cleanly...")
        await manager.unload_model()

    app = FastAPI(
        title="Ollivo AirLLM Local Inference Engine",
        version="1.0.0",
        description="High-efficiency layer-streaming local AI inference service for Ollivo Desktop",
        docs_url="/docs" if cfg.log_level == "DEBUG" else None,
        redoc_url=None,
        lifespan=lifespan,
    )

    # Prevent DNS rebinding attacks by validating Host header
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=["localhost", "127.0.0.1", "*.localhost", "testserver"],
    )

    # Restrictive Local CORS (protects against browser CSRF / cross-site hijacking)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["app://ollivo", "vscode-webview://*"],
        allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:[0-9]+)?$",
        allow_credentials=True,
        allow_methods=["GET", "POST", "DELETE", "OPTIONS"],
        allow_headers=["*"],
    )

    # Security dependency (Bearer token verification if api_key is configured)
    security = HTTPBearer(auto_error=False)

    async def verify_auth(credentials: Optional[HTTPAuthorizationCredentials] = Security(security)):
        if cfg.api_key:
            if not credentials or credentials.credentials != cfg.api_key:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid or missing API key authorization",
                )
        return True

    # --- Standard Endpoints (Section 5) ---

    @app.get("/health", tags=["Health"])
    async def health_check():
        status_info = manager.get_status()
        is_healthy = status_info.state in ["ready", "busy", "unloaded"]
        status_code = status.HTTP_200_OK if is_healthy else status.HTTP_503_SERVICE_UNAVAILABLE
        return Response(
            content=json.dumps({
                "status": "healthy" if is_healthy else "unhealthy",
                "model_state": status_info.state,
                "model_id": status_info.model_id,
                "provider": "airllm",
                "ready": status_info.state == "ready",
                "uptime_seconds": status_info.uptime_seconds,
            }),
            media_type="application/json",
            status_code=status_code,
        )

    @app.get("/api/ai/status", response_model=ModelStatusInfo, tags=["Status"])
    async def get_status(authorized: bool = Security(verify_auth)):
        return manager.get_status()

    @app.get("/api/ai/models", tags=["Models"])
    async def list_models(authorized: bool = Security(verify_auth)):
        status_info = manager.get_status()
        models = []
        for m in cfg.approved_models:
            is_active = (status_info.model_id == m)
            models.append({
                "id": m,
                "name": m.split("/")[-1],
                "provider": "airllm",
                "is_active": is_active,
                "layer_streaming": True,
                "recommended_compression": cfg.compression or "4bit",
            })
        return {"models": models, "active_model": status_info.model_id}

    @app.post("/api/ai/models/load", tags=["Models"])
    async def load_model(request: ModelLoadRequest, authorized: bool = Security(verify_auth)):
        if not manager.is_model_approved(request.model_id):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Model '{request.model_id}' is not in the approved models allowlist.",
            )
        try:
            await manager.load_model(request.model_id)
            return {"status": "success", "model_id": request.model_id, "state": "ready"}
        except Exception as e:
            logger.exception("Failed to load model %s", request.model_id)
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Model loading error: {type(e).__name__}")

    @app.post("/api/ai/models/unload", tags=["Models"])
    async def unload_model(authorized: bool = Security(verify_auth)):
        try:
            await manager.unload_model()
            return {"status": "success", "state": "unloaded"}
        except Exception as e:
            logger.exception("Failed to unload model")
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Model unload error: {type(e).__name__}")

    @app.post("/api/ai/generate", response_model=GenerateResponse, tags=["Inference"])
    async def generate_text(request: GenerateRequest, authorized: bool = Security(verify_auth)):
        if request.model and not manager.is_model_approved(request.model):
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=f"Model '{request.model}' is not approved.")

        try:
            result = await manager.generate(
                prompt=request.prompt,
                max_new_tokens=request.max_tokens,
                temperature=request.temperature,
                top_p=request.top_p,
                stop_sequences=request.stop,
            )
            return GenerateResponse(
                id=result.request_id,
                model=result.model_id,
                text=result.text,
                finish_reason=result.finish_reason,
                metrics=result.metrics.model_dump(),
            )
        except RuntimeError as e:
            if "queue depth limit" in str(e).lower():
                raise HTTPException(status_code=status.HTTP_429_TOO_MANY_REQUESTS, detail=str(e))
            raise HTTPException(status_code=status.HTTP_503_SERVICE_UNAVAILABLE, detail=str(e))
        except TimeoutError as e:
            raise HTTPException(status_code=status.HTTP_504_GATEWAY_TIMEOUT, detail=str(e))
        except Exception as e:
            logger.exception("Generation failure")
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Inference error: {type(e).__name__}")

    @app.post("/api/ai/generate/stream", tags=["Inference"])
    async def generate_stream_sse(request: GenerateRequest, authorized: bool = Security(verify_auth)):
        """Server-Sent Events streaming token generation."""
        async def event_generator():
            try:
                start = time.perf_counter()
                count = 0
                async for chunk in manager.generate_stream(
                    prompt=request.prompt,
                    max_new_tokens=request.max_tokens,
                    temperature=request.temperature,
                    top_p=request.top_p,
                    stop_sequences=request.stop,
                ):
                    count += 1
                    data = json.dumps({"token": chunk, "done": False})
                    yield f"event: token\ndata: {data}\n\n"

                duration_sec = time.perf_counter() - start
                tps = round(count / duration_sec, 2) if duration_sec > 0 else 0.0
                end_data = json.dumps({
                    "done": True,
                    "metrics": {
                        "total_tokens": count,
                        "duration_ms": int(duration_sec * 1000),
                        "tokens_per_second": tps,
                    },
                })
                yield f"event: done\ndata: {end_data}\n\n"
            except Exception as e:
                err_data = json.dumps({"error": str(e), "done": True})
                yield f"event: error\ndata: {err_data}\n\n"

        return StreamingResponse(event_generator(), media_type="text/event-stream")

    # --- Seamless Ollama Compatibility Routes ---

    @app.get("/api/version", tags=["Ollama Compatibility"])
    async def ollama_version():
        return {"version": "0.4.0-airllm-bridge"}

    @app.get("/api/tags", tags=["Ollama Compatibility"])
    async def ollama_tags():
        status_info = manager.get_status()
        active_id = status_info.model_id or cfg.model_id
        short_name = active_id.split("/")[-1].lower()

        models = [
            {
                "name": f"airllm:{short_name}",
                "model": active_id,
                "modified_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "size": int(1024 * 1024 * 1024 * 4.5),
                "digest": f"sha256:{abs(hash(active_id))}",
                "details": {
                    "parent_model": "",
                    "format": "safetensors-layer-sharded",
                    "family": "llama" if "llama" in active_id.lower() else "qwen",
                    "parameter_size": "70B" if "70b" in active_id.lower() else "8B",
                    "quantization_level": cfg.compression or "none",
                },
            }
        ]
        return {"models": models}

    @app.get("/api/ps", tags=["Ollama Compatibility"])
    async def ollama_ps():
        status_info = manager.get_status()
        if status_info.state not in ["ready", "busy"] or not status_info.model_id:
            return {"models": []}

        short_name = status_info.model_id.split("/")[-1].lower()
        return {
            "models": [
                {
                    "name": f"airllm:{short_name}",
                    "model": status_info.model_id,
                    "size": int(1024 * 1024 * 1024 * 4.5),
                    "size_vram": int(status_info.rss_memory_mb * 1024 * 1024),
                    "digest": f"sha256:{abs(hash(status_info.model_id))}",
                    "expires_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() + 3600)),
                    "details": {
                        "parent_model": "",
                        "format": "safetensors-layer-sharded",
                        "family": "llama",
                        "parameter_size": "70B" if "70b" in status_info.model_id.lower() else "8B",
                        "quantization_level": cfg.compression or "none",
                    },
                }
            ]
        }

    @app.post("/api/generate", tags=["Ollama Compatibility"])
    async def ollama_generate(req: OllamaGenerateRequest, authorized: bool = Security(verify_auth)):
        prompt = req.prompt
        if req.system and req.system.strip():
            prompt = f"{req.system.strip()}\n\n{prompt}"

        # Extract options
        opts = req.options or {}
        max_tokens = opts.get("num_predict", cfg.max_new_tokens)
        temp = float(opts.get("temperature", 0.7))
        top_p = float(opts.get("top_p", 0.9))
        stop_seq = opts.get("stop")

        if not req.stream:
            # Non-streaming NDJSON single response
            result = await manager.generate(
                prompt=prompt,
                max_new_tokens=max_tokens,
                temperature=temp,
                top_p=top_p,
                stop_sequences=stop_seq,
            )
            return {
                "model": result.model_id,
                "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                "response": result.text,
                "done": True,
                "total_duration": result.metrics.duration_ms * 1_000_000,
                "eval_count": result.metrics.total_tokens,
                "eval_duration": result.metrics.duration_ms * 1_000_000,
            }

        # Streaming NDJSON response (Ollama format: line-delimited JSON)
        async def ndjson_stream():
            try:
                start = time.perf_counter()
                tok_count = 0
                async for piece in manager.generate_stream(
                    prompt=prompt,
                    max_new_tokens=max_tokens,
                    temperature=temp,
                    top_p=top_p,
                    stop_sequences=stop_seq,
                ):
                    tok_count += 1
                    line = json.dumps({
                        "model": getattr(manager._engine, "_model_id", "airllm"),
                        "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                        "response": piece,
                        "done": False,
                    })
                    yield f"{line}\n"

                duration_ns = int((time.perf_counter() - start) * 1_000_000_000)
                final_line = json.dumps({
                    "model": getattr(manager._engine, "_model_id", "airllm"),
                    "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                    "response": "",
                    "done": True,
                    "total_duration": duration_ns,
                    "eval_count": tok_count,
                    "eval_duration": duration_ns,
                })
                yield f"{final_line}\n"
            except Exception as e:
                err_line = json.dumps({"error": str(e), "done": True})
                yield f"{err_line}\n"

        return StreamingResponse(ndjson_stream(), media_type="application/x-ndjson")

    return app
