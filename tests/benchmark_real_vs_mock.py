#!/usr/bin/env python3
"""
Independent Performance Benchmark: Lightweight API Overhead vs. Real Neural Network Inference.
Contrasts pure ASGI framework dispatch against real layer-streaming / transformer forward passes.
Outputs verified metrics: TTFT (ms), generation latency (ms), tokens/sec throughput, and RSS memory.
"""

import asyncio
import json
import os
import sys
import time
from typing import Any, Dict, List
import psutil
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

from airllm_service.api import create_app
from airllm_service.config import AirLLMConfig
from airllm_service.model_manager import ModelManager
import httpx


async def benchmark_mock_framework_overhead(total_requests: int = 100, concurrency: int = 10) -> Dict[str, Any]:
    """Measure in-process FastAPI endpoint dispatch overhead using MockInferenceEngine."""
    config = AirLLMConfig(
        mock_mode=True,
        model_id="hf-internal-testing/tiny-random-LlamaForCausalLM",
        auto_warmup_on_startup=True,
    )
    manager = ModelManager(config)
    await manager.load_model()
    app = create_app(config=config, model_manager=manager)

    sem = asyncio.Semaphore(concurrency)
    latencies: List[float] = []
    payload = {"prompt": "Write a 3-word sentence.", "max_tokens": 16}

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        start_time = time.perf_counter()

        async def worker():
            async with sem:
                t0 = time.perf_counter()
                res = await client.post("/api/ai/generate", json=payload, timeout=10.0)
                dt = (time.perf_counter() - t0) * 1000.0
                if res.status_code == 200:
                    latencies.append(dt)

        tasks = [asyncio.create_task(worker()) for _ in range(total_requests)]
        await asyncio.gather(*tasks)
        total_time = time.perf_counter() - start_time

    latencies.sort()
    return {
        "benchmark_type": "Lightweight API Framework Overhead (MockEngine)",
        "total_requests": total_requests,
        "concurrency": concurrency,
        "total_time_seconds": round(total_time, 4),
        "requests_per_second": round(len(latencies) / total_time, 2) if total_time > 0 else 0,
        "median_latency_ms": round(latencies[len(latencies) // 2], 3) if latencies else 0,
        "p95_latency_ms": round(latencies[int(len(latencies) * 0.95)], 3) if latencies else 0,
        "note": "Measures HTTP route matching, Pydantic serialization, and event loop overhead only.",
    }


def benchmark_real_neural_inference(model_id: str = "hf-internal-testing/tiny-random-LlamaForCausalLM", num_runs: int = 5) -> Dict[str, Any]:
    """Measure real neural network forward pass, TTFT, token throughput, and memory delta."""
    process = psutil.Process()
    rss_before_mb = process.memory_info().rss / (1024 * 1024)

    t0_load = time.perf_counter()
    tokenizer = AutoTokenizer.from_pretrained(model_id)
    if tokenizer.pad_token_id is None:
        tokenizer.pad_token = tokenizer.eos_token
    model = AutoModelForCausalLM.from_pretrained(model_id, torch_dtype=torch.float32)
    model.eval()
    model_load_time_sec = time.perf_counter() - t0_load

    rss_after_load_mb = process.memory_info().rss / (1024 * 1024)

    prompt = "Artificial intelligence and local language models enable"
    input_ids = tokenizer(prompt, return_tensors="pt").input_ids

    ttft_list_ms: List[float] = []
    total_latency_list_ms: List[float] = []
    tokens_per_sec_list: List[float] = []
    generated_token_counts: List[int] = []

    for run_idx in range(num_runs):
        t0 = time.perf_counter()
        with torch.no_grad():
            # First token latency (TTFT)
            out_first = model(input_ids)
            first_token_time = time.perf_counter() - t0
            ttft_list_ms.append(first_token_time * 1000.0)

            # Full sequence generation (max 32 new tokens)
            t_gen_start = time.perf_counter()
            outputs = model.generate(
                input_ids,
                max_new_tokens=32,
                do_sample=False,
                pad_token_id=tokenizer.pad_token_id,
            )
            gen_time = time.perf_counter() - t_gen_start
            new_tokens = outputs.shape[1] - input_ids.shape[1]
            generated_token_counts.append(new_tokens)
            total_latency_list_ms.append((time.perf_counter() - t0) * 1000.0)
            if gen_time > 0 and new_tokens > 0:
                tokens_per_sec_list.append(new_tokens / gen_time)

    rss_peak_mb = process.memory_info().rss / (1024 * 1024)

    return {
        "benchmark_type": "Real Neural Network Inference (Autoregressive Token Generation)",
        "model_id": model_id,
        "parameters": sum(p.numel() for p in model.parameters()),
        "model_load_time_seconds": round(model_load_time_sec, 3),
        "rss_memory_before_mb": round(rss_before_mb, 2),
        "rss_memory_loaded_mb": round(rss_after_load_mb, 2),
        "rss_memory_peak_mb": round(rss_peak_mb, 2),
        "num_runs": num_runs,
        "avg_ttft_ms": round(sum(ttft_list_ms) / len(ttft_list_ms), 3),
        "avg_generation_latency_ms": round(sum(total_latency_list_ms) / len(total_latency_list_ms), 3),
        "avg_tokens_per_second": round(sum(tokens_per_sec_list) / len(tokens_per_sec_list), 2) if tokens_per_sec_list else 0,
        "avg_new_tokens": sum(generated_token_counts) / len(generated_token_counts) if generated_token_counts else 0,
        "note": "Measures actual PyTorch tensor math and autoregressive generation.",
    }


async def main():
    print("=" * 80)
    print("OLLIVO INDEPENDENT BENCHMARK: MOCK API OVERHEAD VS REAL NEURAL INFERENCE")
    print("=" * 80)

    print("\n[1/2] Benchmarking Mock API Framework Overhead (FastAPI dispatch)...")
    mock_results = await benchmark_mock_framework_overhead(total_requests=200, concurrency=10)
    print(json.dumps(mock_results, indent=2))

    print("\n[2/2] Benchmarking Real Neural Network Inference (PyTorch forward pass)...")
    real_results = benchmark_real_neural_inference()
    print(json.dumps(real_results, indent=2))

    print("\n" + "=" * 80)
    print("ANALYSIS SUMMARY & DISCREPANCY VERIFICATION:")
    print(f"- Mock Framework Throughput: {mock_results['requests_per_second']} req/s (synthetic string echo)")
    print(f"- Real Neural Generation:    {real_results['avg_tokens_per_second']} tokens/s (PyTorch tensor generation)")
    print(f"- Real Time-to-First-Token:  {real_results['avg_ttft_ms']} ms")
    print(f"- Model Loading Latency:     {real_results['model_load_time_seconds']} seconds")
    print("Conclusion: Claiming thousands of RPS for an LLM is invalid; thousands of RPS")
    print("measures ASGI event-loop routing, whereas actual LLM throughput is measured")
    print("in tokens/second and TTFT latency.")
    print("=" * 80)


if __name__ == "__main__":
    asyncio.run(main())
