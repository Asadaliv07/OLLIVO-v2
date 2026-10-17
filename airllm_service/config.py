"""
Centralized Configuration and Resource Management for AirLLM Inference Service
Implements Section 4 of Master Implementation Specification.
"""

import os
import shutil
from pathlib import Path
from typing import List, Optional
from pydantic import BaseModel, Field, field_validator


class AirLLMConfig(BaseModel):
    # Service Network Settings
    host: str = Field(default="127.0.0.1", description="Service bind address")
    port: int = Field(default=8765, description="Service bind port")
    api_key: Optional[str] = Field(default=None, description="Optional bearer token for secured internal communication")

    # Model Configuration
    model_id: str = Field(
        default="meta-llama/Meta-Llama-3-8B-Instruct",
        description="Default HuggingFace repository ID or local model path"
    )
    model_revision: Optional[str] = Field(default=None, description="Pinned commit hash or branch name")
    approved_models: List[str] = Field(
        default=[
            "meta-llama/Meta-Llama-3-8B-Instruct",
            "meta-llama/Meta-Llama-3-70B-Instruct",
            "meta-llama/Llama-3.2-3B-Instruct",
            "meta-llama/Llama-3.2-1B-Instruct",
            "Qwen/Qwen2.5-Coder-7B-Instruct",
            "Qwen/Qwen2.5-Coder-32B-Instruct",
            "Qwen/Qwen2.5-72B-Instruct",
            "deepseek-ai/DeepSeek-R1-Distill-Qwen-8B",
            "deepseek-ai/DeepSeek-R1-Distill-Llama-70B",
            "mistralai/Mistral-7B-Instruct-v0.3",
            "hf-internal-testing/tiny-random-LlamaForCausalLM",
        ],
        description="Allowlist of approved models that untrusted clients cannot bypass"
    )
    hf_token: Optional[str] = Field(
        default=None,
        description="HuggingFace token for gated models (e.g., Llama-3 weights)"
    )

    # Hardware & Layer-Streaming Execution
    device: str = Field(
        default="auto",
        description="Compute device: 'auto', 'cuda:0', 'mps', or 'cpu'"
    )
    compression: Optional[str] = Field(
        default="4bit",
        description="Optional block-wise weight compression: '4bit', '8bit', or None"
    )
    max_seq_len: int = Field(
        default=2048,
        description="Maximum combined context sequence length"
    )
    max_new_tokens: int = Field(
        default=512,
        description="Default maximum generated tokens"
    )
    profiling_mode: bool = Field(
        default=False,
        description="Enable layer-by-layer latency profiling"
    )

    # Storage & Shard Cache Management
    model_cache_dir: Path = Field(
        default_factory=lambda: Path.home() / ".cache" / "ollivo" / "airllm" / "hub",
        description="Hugging Face models cache directory"
    )
    layer_shards_dir: Path = Field(
        default_factory=lambda: Path.home() / ".cache" / "ollivo" / "airllm" / "shards",
        description="Directory where AirLLM layer-split weights are stored"
    )
    min_free_disk_gb: float = Field(
        default=10.0,
        description="Minimum free disk space in GB required before starting model download or sharding"
    )

    # Concurrency, Timeouts & Safety
    max_queue_depth: int = Field(
        default=16,
        description="Maximum concurrent inference requests in waiting queue"
    )
    inference_timeout_seconds: int = Field(
        default=180,
        description="Inference execution timeout in seconds"
    )
    auto_warmup_on_startup: bool = Field(
        default=False,
        description="Whether to eagerly preload and warm up model on service start"
    )
    mock_mode: bool = Field(
        default=False,
        description="Run in mock mode for fast testing without GPU weights"
    )
    log_level: str = Field(
        default="INFO",
        description="Logging verbosity (DEBUG, INFO, WARNING, ERROR)"
    )

    @field_validator("compression")
    @classmethod
    def validate_compression(cls, v: Optional[str]) -> Optional[str]:
        if v is None:
            return None
        v_clean = v.strip().lower()
        if v_clean in ["none", "", "null", "false"]:
            return None
        if v_clean not in ["4bit", "8bit"]:
            raise ValueError(f"compression must be '4bit', '8bit', or None, got: {v}")
        return v_clean

    @field_validator("device")
    @classmethod
    def validate_device(cls, v: str) -> str:
        clean = v.strip().lower()
        if clean in ["auto", "mps", "cpu"] or clean.startswith("cuda"):
            return clean
        raise ValueError(f"Unsupported device: {v}. Use 'auto', 'cuda', 'mps', or 'cpu'.")

    def ensure_directories(self) -> None:
        """Create storage directories if they do not exist."""
        self.model_cache_dir.mkdir(parents=True, exist_ok=True)
        self.layer_shards_dir.mkdir(parents=True, exist_ok=True)

    def check_disk_space(self, target_path: Optional[Path] = None) -> float:
        """Return free disk space in GB for the target storage directory."""
        path = target_path or self.layer_shards_dir
        curr = path
        while not curr.exists() and curr != curr.parent:
            curr = curr.parent
        usage = shutil.disk_usage(str(curr))
        free_gb = usage.free / (1024 ** 3)
        return free_gb

    def has_sufficient_disk_space(self, required_gb: Optional[float] = None) -> bool:
        """Verify whether sufficient disk space is available."""
        req = required_gb or self.min_free_disk_gb
        return self.check_disk_space() >= req

    @classmethod
    def from_env(cls) -> "AirLLMConfig":
        """Load configuration from environment variables or .env file."""
        # Optional: load .env if present
        env_file = Path(__file__).resolve().parent / ".env"
        if env_file.exists():
            from dotenv import load_dotenv  # type: ignore
            load_dotenv(env_file)

        model_id = os.getenv("AIRLLM_MODEL_ID", "meta-llama/Meta-Llama-3-8B-Instruct")
        approved_env = os.getenv("AIRLLM_APPROVED_MODELS")
        approved_list = [m.strip() for m in approved_env.split(",") if m.strip()] if approved_env else None

        cache_dir_env = os.getenv("AIRLLM_CACHE_DIR")
        shards_dir_env = os.getenv("AIRLLM_SHARDS_DIR")

        config = cls(
            host=os.getenv("AIRLLM_HOST", "127.0.0.1"),
            port=int(os.getenv("AIRLLM_PORT", "8765")),
            api_key=os.getenv("AIRLLM_API_KEY"),
            model_id=model_id,
            approved_models=approved_list or cls.model_fields["approved_models"].default,  # type: ignore
            hf_token=os.getenv("HF_TOKEN") or os.getenv("HUGGING_FACE_HUB_TOKEN"),
            device=os.getenv("AIRLLM_DEVICE", "auto"),
            compression=os.getenv("AIRLLM_COMPRESSION", "4bit"),
            max_seq_len=int(os.getenv("AIRLLM_MAX_SEQ_LEN", "2048")),
            max_new_tokens=int(os.getenv("AIRLLM_MAX_NEW_TOKENS", "512")),
            profiling_mode=os.getenv("AIRLLM_PROFILING", "false").lower() in ("true", "1", "yes"),
            model_cache_dir=Path(cache_dir_env) if cache_dir_env else Path.home() / ".cache" / "ollivo" / "airllm" / "hub",
            layer_shards_dir=Path(shards_dir_env) if shards_dir_env else Path.home() / ".cache" / "ollivo" / "airllm" / "shards",
            min_free_disk_gb=float(os.getenv("AIRLLM_MIN_FREE_DISK_GB", "10.0")),
            max_queue_depth=int(os.getenv("AIRLLM_MAX_QUEUE_DEPTH", "16")),
            inference_timeout_seconds=int(os.getenv("AIRLLM_TIMEOUT", "180")),
            auto_warmup_on_startup=os.getenv("AIRLLM_WARMUP", "false").lower() in ("true", "1", "yes"),
            mock_mode=os.getenv("AIRLLM_MOCK_MODE", "false").lower() in ("true", "1", "yes"),
            log_level=os.getenv("AIRLLM_LOG_LEVEL", "INFO"),
        )
        config.ensure_directories()
        return config
