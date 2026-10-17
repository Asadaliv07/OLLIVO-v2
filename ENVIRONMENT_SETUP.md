# OLLIVO v2 — Environment Configuration & Secrets Guide

This document details the environment configuration system, required variables, default fallbacks, and safe secret restoration procedures for **OLLIVO v2**.

---

## 1. Zero-Cloud / Local-First Policy

OLLIVO is designed to operate 100% locally with zero required external API keys or cloud credentials.
By default:
- No OpenAI, Anthropic, or external cloud tokens are required.
- All inference defaults to on-device endpoints (Ollama at `127.0.0.1:11434` or AirLLM at `127.0.0.1:8008` / `8765`).
- The database is local SQLite on your SSD.

---

## 2. Optional Environment Variables & Secret Restoration

If you wish to use gated models (such as Meta Llama weights from Hugging Face) or customize backend service addresses:

### A. Root Application Template: `.env.example`
To configure, copy `.env.example` to `.env`:
```bash
cp /Users/asadalishaikh/OLLIVO\ v2/.env.example /Users/asadalishaikh/OLLIVO\ v2/.env
chmod 600 /Users/asadalishaikh/OLLIVO\ v2/.env
```

| Variable Name | Default Value | Description / When Needed |
| :--- | :--- | :--- |
| `AIRLLM_HOST` | `127.0.0.1` | Loopback IP address for AirLLM service |
| `AIRLLM_PORT` | `8765` | Service port (or `8008` in service.py) |
| `AIRLLM_DEVICE` | `mps` | `mps` (Apple Silicon Metal), `cuda:0`, or `cpu` |
| `AIRLLM_COMPRESSION` | `4bit` | `4bit`, `8bit`, or `none` |
| `AIRLLM_DEFAULT_MODEL`| `meta-llama/Meta-Llama-3-8B-Instruct` | Default model repository |
| `AIRLLM_HF_TOKEN` | *(Empty)* | **Secret:** Optional Hugging Face token for gated models |
| `OLLAMA_BASE_URL` | `http://127.0.0.1:11434` | Ollama local daemon endpoint |
| `LOCALAI_BASE_URL` | `http://127.0.0.1:8080` | LocalAI endpoint |
| `GUARDRAILS_POLICY` | `standard` | Input sanitization policy (`standard`, `strict`, `relaxed`) |
| `VECTOR_STORE_BACKEND`| `sqliteVec` | Local vector engine (`sqliteVec`, `chroma`, `qdrant`) |

### B. Python AirLLM Microservice Template: `airllm_service/.env.example`
```bash
cp /Users/asadalishaikh/OLLIVO\ v2/airllm_service/.env.example /Users/asadalishaikh/OLLIVO\ v2/airllm_service/.env
chmod 600 /Users/asadalishaikh/OLLIVO\ v2/airllm_service/.env
```

| Variable Name | Default Value | Description |
| :--- | :--- | :--- |
| `HF_TOKEN` | *(Empty)* | Hugging Face user access token (`hf_...`) for downloading gated Llama weights |
| `AIRLLM_API_KEY` | *(Empty)* | Optional bearer token for restricting local daemon calls |
| `AIRLLM_CACHE_DIR` | `~/.cache/ollivo/airllm/hub` | Cache directory for downloaded model weights |
| `AIRLLM_SHARDS_DIR`| `~/.cache/ollivo/airllm/shards` | Directory for sequential layer-split weights |
| `AIRLLM_MIN_FREE_DISK_GB` | `10.0` | Minimum disk safety margin before streaming shards |

---

## 3. Best Practices for Secret Management

1. **Never Commit Secrets:** `.env` is included in `.gitignore` and must never be committed to Git.
2. **File Permissions:** Ensure local `.env` files are readable only by your user account (`chmod 600 .env`).
3. **Restoring Hugging Face Token:**
   - If downloading Llama 3 models directly from Hugging Face via AirLLM, set `HF_TOKEN=hf_...` in `airllm_service/.env`.
   - Alternatively, run `huggingface-cli login` in your terminal to save credentials in standard `~/.cache/huggingface/token`.

