"""
Integration tests for FastAPI endpoints (Standard & Ollama Compatibility).
"""

import json
import pytest
from fastapi.testclient import TestClient

from airllm_service.config import AirLLMConfig
from airllm_service.model_manager import ModelManager
from airllm_service.api import create_app


@pytest.fixture
def client():
    config = AirLLMConfig(
        mock_mode=True,
        model_id="hf-internal-testing/tiny-random-LlamaForCausalLM",
        auto_warmup_on_startup=True,
    )
    manager = ModelManager(config)
    app = create_app(config=config, model_manager=manager)
    with TestClient(app) as test_client:
        yield test_client


def test_health_endpoint(client):
    res = client.get("/health")
    assert res.status_code == 200
    data = res.json()
    assert data["status"] == "healthy"
    assert data["provider"] == "airllm"


def test_status_endpoint(client):
    res = client.get("/api/ai/status")
    assert res.status_code == 200
    data = res.json()
    assert data["provider"] == "airllm"
    assert "rss_memory_mb" in data
    assert "free_disk_gb" in data


def test_models_endpoint(client):
    res = client.get("/api/ai/models")
    assert res.status_code == 200
    data = res.json()
    assert "models" in data
    assert len(data["models"]) > 0


def test_generate_endpoint(client):
    payload = {
        "prompt": "Hello AirLLM! Can you write Dart code?",
        "max_tokens": 50,
        "temperature": 0.7,
    }
    res = client.post("/api/ai/generate", json=payload)
    assert res.status_code == 200
    data = res.json()
    assert "text" in data
    assert "id" in data
    assert "metrics" in data
    assert data["metrics"]["total_tokens"] > 0


def test_generate_stream_sse_endpoint(client):
    payload = {
        "prompt": "Stream this prompt",
        "max_tokens": 20,
    }
    with client.stream("POST", "/api/ai/generate/stream", json=payload) as response:
        assert response.status_code == 200
        content = response.read().decode("utf-8")
        assert "event: token" in content
        assert "event: done" in content


def test_ollama_version_compatibility(client):
    res = client.get("/api/version")
    assert res.status_code == 200
    assert "version" in res.json()


def test_ollama_tags_compatibility(client):
    res = client.get("/api/tags")
    assert res.status_code == 200
    data = res.json()
    assert "models" in data
    assert len(data["models"]) > 0
    assert "airllm" in data["models"][0]["name"]


def test_ollama_generate_compatibility_streaming(client):
    payload = {
        "model": "airllm:8b",
        "prompt": "Explain layer streaming",
        "stream": True,
    }
    with client.stream("POST", "/api/generate", json=payload) as response:
        assert response.status_code == 200
        lines = [line for line in response.iter_lines() if line.strip()]
        assert len(lines) > 0
        parsed = json.loads(lines[0])
        assert "response" in parsed
        assert "done" in parsed


def test_ollama_generate_compatibility_non_streaming(client):
    payload = {
        "model": "airllm:8b",
        "prompt": "Explain layer streaming non streaming",
        "stream": False,
    }
    res = client.post("/api/generate", json=payload)
    assert res.status_code == 200
    data = res.json()
    assert data["done"] is True
    assert "response" in data
    assert "total_duration" in data


def test_cors_origin_restriction(client):
    # Malicious external web origin should NOT be allowed
    res_malicious = client.options(
        "/api/ai/status",
        headers={
            "Origin": "https://evil-attacker.com",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert res_malicious.headers.get("access-control-allow-origin") != "https://evil-attacker.com"

    # Local loopback origin should be allowed
    res_local = client.options(
        "/api/ai/status",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert res_local.headers.get("access-control-allow-origin") == "http://localhost:3000"

    # App scheme origin should be allowed
    res_app = client.options(
        "/api/ai/status",
        headers={
            "Origin": "app://ollivo",
            "Access-Control-Request-Method": "GET",
        },
    )
    assert res_app.headers.get("access-control-allow-origin") == "app://ollivo"


def test_dns_rebinding_trusted_host():
    """Verify that requests with untrusted Host headers (e.g. DNS rebinding via attacker.com) are rejected."""
    config = AirLLMConfig(mock_mode=True, model_id="hf-internal-testing/tiny-random-LlamaForCausalLM")
    manager = ModelManager(config)
    app = create_app(config=config, model_manager=manager)

    with TestClient(app, base_url="http://attacker-rebinding.com") as c:
        res = c.get("/health", headers={"Host": "attacker-rebinding.com"})
        assert res.status_code == 400
        assert "invalid host" in res.text.lower()


def test_api_key_enforcement_on_ollama_generate():
    """Verify that /api/generate requires valid Bearer token when api_key is configured."""
    config = AirLLMConfig(
        mock_mode=True,
        model_id="hf-internal-testing/tiny-random-LlamaForCausalLM",
        api_key="secret-token-12345",
    )
    manager = ModelManager(config)
    app = create_app(config=config, model_manager=manager)

    with TestClient(app) as c:
        payload = {"prompt": "Hello unauthenticated"}
        # 1. Unauthenticated request should be 401
        res = c.post("/api/generate", json=payload)
        assert res.status_code == 401

        # 2. Wrong token should be 401
        res_wrong = c.post("/api/generate", json=payload, headers={"Authorization": "Bearer wrong-token"})
        assert res_wrong.status_code == 401

        # 3. Correct token should succeed
        res_auth = c.post("/api/generate", json=payload, headers={"Authorization": "Bearer secret-token-12345"})
        assert res_auth.status_code == 200


def test_oversized_prompt_rejected(client):
    """Verify that prompts exceeding 131072 characters are rejected with HTTP 422."""
    huge_prompt = "A" * 140000
    res = client.post("/api/generate", json={"prompt": huge_prompt})
    assert res.status_code == 422


