"""
Unit tests for AirLLM centralized configuration and resource management.
"""

import os
from pathlib import Path
import pytest
from pydantic import ValidationError

from airllm_service.config import AirLLMConfig


def test_default_config_initialization():
    config = AirLLMConfig()
    assert config.host == "127.0.0.1"
    assert config.port == 8765
    assert config.compression == "4bit"
    assert config.device == "auto"
    assert config.max_seq_len == 2048
    assert config.max_new_tokens == 512
    assert config.min_free_disk_gb == 10.0
    assert len(config.approved_models) > 0


def test_compression_validation():
    # Valid compressions
    assert AirLLMConfig(compression="4bit").compression == "4bit"
    assert AirLLMConfig(compression="8bit").compression == "8bit"
    assert AirLLMConfig(compression=None).compression is None
    assert AirLLMConfig(compression="none").compression is None

    # Invalid compression
    with pytest.raises(ValidationError):
        AirLLMConfig(compression="16bit")


def test_device_validation():
    assert AirLLMConfig(device="auto").device == "auto"
    assert AirLLMConfig(device="cuda:0").device == "cuda:0"
    assert AirLLMConfig(device="mps").device == "mps"
    assert AirLLMConfig(device="cpu").device == "cpu"

    with pytest.raises(ValidationError):
        AirLLMConfig(device="tpu_v4")


def test_disk_space_verification(tmp_path):
    config = AirLLMConfig(layer_shards_dir=tmp_path)
    free_gb = config.check_disk_space()
    assert free_gb > 0.0
    assert config.has_sufficient_disk_space(required_gb=0.01) is True


def test_from_env_parsing(monkeypatch, tmp_path):
    monkeypatch.setenv("AIRLLM_PORT", "9999")
    monkeypatch.setenv("AIRLLM_COMPRESSION", "8bit")
    monkeypatch.setenv("AIRLLM_MODEL_ID", "Qwen/Qwen2.5-Coder-7B-Instruct")
    monkeypatch.setenv("AIRLLM_SHARDS_DIR", str(tmp_path))

    cfg = AirLLMConfig.from_env()
    assert cfg.port == 9999
    assert cfg.compression == "8bit"
    assert cfg.model_id == "Qwen/Qwen2.5-Coder-7B-Instruct"
    assert cfg.layer_shards_dir == tmp_path
