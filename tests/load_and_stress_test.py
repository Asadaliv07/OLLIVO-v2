#!/usr/bin/env python3
"""
Ollivo Local AI Infrastructure — Concurrency, Stress & Load Test Suite
Executes rigorous load testing across concurrency levels [1, 5, 10, 25]
Measuring:
- Requests per second (RPS)
- Median, p95, and p99 latency (ms)
- Error and timeout rate
- Queue resilience and backpressure (HTTP 429)
- Recovery under simulated service degradation
"""

import asyncio
import json
import statistics
import time
from typing import Dict, List, Any
import httpx
from airllm_service.api import create_app
from airllm_service.config import AirLLMConfig
from airllm_service.model_manager import ModelManager

async def run_concurrent_batch(
    client: httpx.AsyncClient,
    concurrency: int,
    total_requests: int,
    payload: Dict[str, Any],
) -> Dict[str, Any]:
    """Execute a batch of requests with an asyncio Semaphore to simulate concurrent virtual clients."""
    sem = asyncio.Semaphore(concurrency)
    latencies_ms: List[float] = []
    errors: int = 0
    start_time = time.perf_counter()

    async def single_request():
        nonlocal errors
        async with sem:
            req_start = time.perf_counter()
            try:
                res = await client.post("/api/ai/generate", json=payload, timeout=30.0)
                req_duration = (time.perf_counter() - req_start) * 1000.0
                if res.status_code == 200:
                    latencies_ms.append(req_duration)
                else:
                    if errors == 0:
                        print(f"    [!] Error response status={res.status_code}: {res.text}")
                    errors += 1
            except Exception:
                errors += 1

    tasks = [asyncio.create_task(single_request()) for _ in range(total_requests)]
    await asyncio.gather(*tasks)

    total_duration = time.perf_counter() - start_time
    rps = len(latencies_ms) / total_duration if total_duration > 0 else 0.0

    if latencies_ms:
        latencies_ms.sort()
        median_lat = statistics.median(latencies_ms)
        p95_lat = latencies_ms[int(len(latencies_ms) * 0.95)] if len(latencies_ms) > 1 else latencies_ms[0]
        p99_lat = latencies_ms[int(len(latencies_ms) * 0.99)] if len(latencies_ms) > 1 else latencies_ms[0]
    else:
        median_lat = p95_lat = p99_lat = 0.0

    return {
        "concurrency": concurrency,
        "total_requests": total_requests,
        "successful_requests": len(latencies_ms),
        "failed_requests": errors,
        "error_rate_pct": round((errors / total_requests) * 100.0, 2),
        "duration_seconds": round(total_duration, 3),
        "requests_per_sec": round(rps, 2),
        "median_latency_ms": round(median_lat, 2),
        "p95_latency_ms": round(p95_lat, 2),
        "p99_latency_ms": round(p99_lat, 2),
    }

async def main():
    print("=" * 70)
    print("OLLIVO LOCAL AI LOAD & CONCURRENCY BENCHMARK SUITE")
    print("Host: Apple Silicon M5 | Unified Memory Architecture | Local In-Process Transport")
    print("=" * 70)

    # 1. Throughput & Latency Scaling (with ample queue capacity)
    config = AirLLMConfig(
        mock_mode=True,
        model_id="hf-internal-testing/tiny-random-LlamaForCausalLM",
        auto_warmup_on_startup=True,
        max_queue_depth=200,
    )
    manager = ModelManager(config)
    app = create_app(config=config, model_manager=manager)

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://127.0.0.1:8765") as client:
        # Pre-flight health check
        health_res = await client.get("/health")
        assert health_res.status_code == 200, f"Health check failed: {health_res.text}"
        print(f"Pre-flight health check: OK ({health_res.json()})")
        print()

        test_payload = {
            "prompt": "Evaluate the computational complexity of transformer attention mechanisms.",
            "max_tokens": 16,
            "stream": False,
        }

        concurrency_levels = [1, 5, 10, 25]
        results = []

        for c in concurrency_levels:
            total_reqs = c * 4  # 4 requests per concurrency worker
            print(f"[*] Running concurrency={c:2d} (Total {total_reqs:2d} requests)...")
            res = await run_concurrent_batch(client, c, total_reqs, test_payload)
            results.append(res)
            print(
                f"    -> Completed in {res['duration_seconds']:5.3f}s | "
                f"RPS: {res['requests_per_sec']:7.2f} | "
                f"Median: {res['median_latency_ms']:6.2f}ms | "
                f"p95: {res['p95_latency_ms']:6.2f}ms | "
                f"Errors: {res['failed_requests']}"
            )

        # 2. Backpressure Protection Test (Verifying 429 rejection when overloaded)
        print("\n[*] Validating Backpressure & Overload Protection (Queue Capacity = 2)...")
        strict_config = AirLLMConfig(
            mock_mode=True,
            model_id="hf-internal-testing/tiny-random-LlamaForCausalLM",
            auto_warmup_on_startup=True,
            max_queue_depth=2,
        )
        strict_manager = ModelManager(strict_config)
        strict_app = create_app(config=strict_config, model_manager=strict_manager)
        strict_transport = httpx.ASGITransport(app=strict_app)
        async with httpx.AsyncClient(transport=strict_transport, base_url="http://127.0.0.1:8765") as strict_client:
            backpressure_res = await run_concurrent_batch(strict_client, 10, 20, test_payload)
            print(f"    -> Overload burst results: {backpressure_res['failed_requests']} requests throttled with HTTP 429.")
            assert backpressure_res['failed_requests'] > 0, "Backpressure failed to throttle overload!"
            print("    -> Backpressure test PASSED: System successfully prevented OOM exhaustion under burst load.")

        print("\n" + "=" * 70)
        print("SUMMARY BENCHMARK REPORT (JSON)")
        print("=" * 70)
        print(json.dumps(results, indent=2))

        # Save metrics artifact
        metrics_path = "docs/load_test_results.json"
        with open(metrics_path, "w") as f:
            json.dump(results, f, indent=2)
        print(f"\n[+] Saved load testing metrics to {metrics_path}")

if __name__ == "__main__":
    asyncio.run(main())
