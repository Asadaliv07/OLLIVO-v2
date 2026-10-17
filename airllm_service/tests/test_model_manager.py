"""
Unit tests for ModelManager, queue concurrency, and mock inference engine.
"""

import asyncio
import pytest

from airllm_service.config import AirLLMConfig
from airllm_service.model_manager import ModelManager, MockInferenceEngine


@pytest.fixture
def mock_config():
    return AirLLMConfig(
        mock_mode=True,
        model_id="hf-internal-testing/tiny-random-LlamaForCausalLM",
        max_queue_depth=2,
        inference_timeout_seconds=5,
    )


@pytest.mark.asyncio
async def test_mock_engine_lifecycle(mock_config):
    manager = ModelManager(mock_config)
    assert manager.state == "unloaded"

    status = manager.get_status()
    assert status.state == "unloaded"
    assert status.provider == "airllm"

    await manager.load_model()
    assert manager.state == "ready"

    gen_res = await manager.generate("Hello AirLLM!", max_new_tokens=20)
    assert gen_res.text is not None
    assert gen_res.metrics.total_tokens > 0

    await manager.unload_model()
    assert manager.state == "unloaded"


@pytest.mark.asyncio
async def test_streaming_generation(mock_config):
    manager = ModelManager(mock_config)
    await manager.load_model()

    tokens = []
    async for chunk in manager.generate_stream("Tell me about streaming", max_new_tokens=30):
        tokens.append(chunk)

    assert len(tokens) > 0
    full_text = "".join(tokens)
    assert "[AirLLM Local Inference]" in full_text


@pytest.mark.asyncio
async def test_unapproved_model_rejected(mock_config):
    manager = ModelManager(mock_config)
    with pytest.raises(PermissionError):
        await manager.load_model("unapproved/malicious-model-repo")


@pytest.mark.asyncio
async def test_queue_overflow_rejection(mock_config):
    # Set queue limit to 0 so any queued request triggers overflow
    mock_config.max_queue_depth = 0
    manager = ModelManager(mock_config)
    await manager.load_model()

    with pytest.raises(RuntimeError) as exc_info:
        await manager.generate("This should be rejected")
    assert "queue depth limit reached" in str(exc_info.value).lower()
