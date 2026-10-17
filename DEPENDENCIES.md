# OLLIVO v2 — Complete Dependencies & Runtime Manifest

This document records all software runtimes, developer tools, library dependencies, backend engines, and external dependencies required to run, build, test, and maintain **OLLIVO v2**.

---

## 1. System Requirements & Runtimes

| Component | Tested Version | Minimum Required | Role in Project |
| :--- | :--- | :--- | :--- |
| **Operating System** | macOS 15.0+ (Darwin 24.x arm64) | macOS 13.0+ | Native desktop host platform |
| **Architecture** | Apple Silicon (M1/M2/M3/M4) | arm64 or x86_64 | Hardware platform (Metal-accelerated) |
| **Flutter SDK** | Flutter 3.29.0 / Dart 3.7.0 | Flutter 3.19+ / Dart 3.3+ | Desktop UI and application framework |
| **Python** | Python 3.11.17 | Python 3.10 – 3.12 | AirLLM sequential inference daemon runtime |
| **Xcode** | Xcode 16.x / Command Line Tools | Xcode 15.0+ | Native macOS compilation & AppKit linking |
| **SQLite** | SQLite 3.5.2+ | SQLite 3.35+ | On-device structured data and RAG storage |

---

## 2. Flutter / Dart Package Dependencies

Specified in `pubspec.yaml` and resolved in `pubspec.lock`:

| Package Name | Constrained Version | Resolved Version | Description / Purpose |
| :--- | :--- | :--- | :--- |
| `cupertino_icons` | `^1.0.8` | `1.0.9` | iOS / macOS standard icon typography |
| `sqflite` | `^2.4.1` | `2.4.4+1` | SQLite database plugin for Flutter |
| `sqflite_common_ffi` | `^2.3.4` | `2.4.3` | FFI-based SQLite implementation for macOS desktop |
| `sqlite3_flutter_libs` | `^0.5.24` | `0.5.24` | Bundled native dynamic SQLite C libraries |
| `path` | `^1.9.0` | `1.9.0` | Cross-platform filesystem path manipulation |
| `path_provider` | `^2.1.2` | `2.1.2` | Native platform storage directory resolution |
| `http` | `^1.2.0` | `1.2.2` | HTTP client for backend streaming & REST APIs |
| `shared_preferences` | `^2.2.2` | `2.4.28` | Key-value persistent settings storage |
| `file_picker` | `^8.0.0` | `8.3.7` | Native macOS file open dialogs for document import |
| `flutter_test` | SDK dependency | SDK | Component & unit testing framework |

---

## 3. Python AirLLM Microservice Dependencies

Specified in `airllm_service/requirements.txt` and installed in `airllm_service/.venv`:

| Package | Installed Version | Role |
| :--- | :--- | :--- |
| `fastapi` | `0.115.0+` | Asynchronous REST and streaming inference server |
| `uvicorn` | `0.30.0+` | High-performance ASGI web server |
| `pydantic` | `2.9.0+` | Configuration validation and typed schema serialization |
| `torch` | `2.4.0+` | Deep learning tensor operations and Metal MPS support |
| `transformers` | `4.44.0+` | Hugging Face model architecture and tokenizers |
| `accelerate` | `0.34.0+` | Multi-device execution and memory placement |
| `airllm` | `2.10.0+` | Sequential disk-to-RAM layer-streaming inference engine |
| `httpx` | `0.27.0+` | Async HTTP client for test suites and health probing |
| `pytest` | `9.1.1` | Test framework for daemon unit and integration tests |
| `pytest-asyncio` | `1.4.0` | Asyncio test runner support |
| `mlx` / `mlx-lm` | Optional | Apple Silicon hardware-native MLX acceleration |

---

## 4. Local AI Backends & Companion Services

OLLIVO v2 supports four local inference backends:

1. **AirLLM Microservice (Bundled):**
   - Protocol: HTTP REST (Ollama-compatible + native API)
   - Default Port: `http://127.0.0.1:8008`
   - Location: `airllm_service/`
   - Execution: Managed automatically by OLLIVO or run manually via `source airllm_service/.venv/bin/activate && uvicorn airllm_service.api:app --port 8008`.
2. **Ollama (Optional External Service):**
   - Protocol: HTTP REST (`/api/generate`, `/api/chat`, `/api/tags`)
   - Default Port: `http://127.0.0.1:11434`
   - Install: `brew install ollama` or download from [ollama.com](https://ollama.com).
3. **LM Studio (Optional External Service):**
   - Protocol: OpenAI-compatible REST (`/v1/chat/completions`)
   - Default Port: `http://127.0.0.1:1234`
4. **LocalAI (Optional External Service):**
   - Protocol: OpenAI-compatible REST
   - Default Port: `http://127.0.0.1:8080`

---

## 5. External Assets & Sandbox Locations

- **Live Application SQLite Database:**
  - Runtime Location: `~/Library/Containers/com.ollivo.ollivo/Data/Documents/ollivo.db`
  - Backup Snapshot Location: `database/ollivo.db` and `external_data/ollivo.db`
- **Application Preferences Plist:**
  - Runtime Location: `~/Library/Containers/com.ollivo.ollivo/Data/Library/Preferences/com.ollivo.ollivo.plist`
  - Backup Snapshot Location: `external_data/com.ollivo.ollivo.plist`
- **Hugging Face / AirLLM Model Cache:**
  - Default Location: `~/.cache/ollivo/airllm/` or `~/.cache/huggingface/hub/`

