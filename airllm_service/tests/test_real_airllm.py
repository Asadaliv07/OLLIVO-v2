"""
Hardware-level test verifying real AirLLM layer streaming on the target platform.
Uses the verified tiny random Llama checkpoint.
"""

import pytest
from airllm_service.config import AirLLMConfig
from airllm_service.model_manager import ModelManager


@pytest.mark.asyncio
async def test_real_airllm_layer_streaming_inference():
    config = AirLLMConfig(
        mock_mode=False,
        model_id="hf-internal-testing/tiny-random-LlamaForCausalLM",
        max_seq_len=256,
        max_new_tokens=10,
        compression=None,
    )

    manager = ModelManager(config)
    await manager.load_model()
    assert manager.state == "ready"

    # Test non-streaming generation
    result = await manager.generate(
        prompt="Hardware test AirLLM prompt",
        max_new_tokens=5,
        temperature=0.7,
    )
    assert result.text is not None
    assert result.metrics.total_tokens > 0
    assert result.metrics.duration_ms > 0

    # Test streaming generation
    streamed_chunks = []
    async for chunk in manager.generate_stream(
        prompt="Hardware test AirLLM stream",
        max_new_tokens=5,
    ):
        streamed_chunks.append(chunk)

    assert len(streamed_chunks) > 0
    assert len("".join(streamed_chunks)) > 0

    await manager.unload_model()
    assert manager.state == "unloaded"
