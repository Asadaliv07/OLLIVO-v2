# OLLIVO v2 — Complete Project Inventory

This document provides a comprehensive inventory of all folders, files, configuration systems, services, data stores, and external resources preserved within the **OLLIVO v2** standalone project.

**Project Root:** `/Users/asadalishaikh/OLLIVO v2`  
**Total Items Preserved:** 34,056 items  
**Disk Footprint:** ~3.1 GB  
**Preservation Date:** 2026-10-17  

---

## 1. Top-Level Directory Structure

| Directory / File | Type | Disk Size | Purpose & Contents |
| :--- | :--- | :--- | :--- |
| `lib/` | Directory | ~1.2 MB | Flutter application source code (UI, state, services, providers, models) |
| `airllm_service/` | Directory | ~1.1 GB | Python FastAPI microservice for AirLLM 70B+ layer-streaming + `.venv` |
| `macos/` | Directory | ~492 KB | macOS native AppKit host, Xcode project, build settings, entitlements |
| `android/` | Directory | ~348 KB | Android native wrapper, Gradle configuration, AndroidManifest |
| `ios/` | Directory | ~248 KB | iOS native runner project and assets |
| `web/` | Directory | ~64 KB | Web runner, HTML shell, and web manifests |
| `assets/` | Directory | ~1.0 MB | High-resolution application branding, logos, icons |
| `database/` | Directory | ~65 KB | Local SQLite database (`ollivo.db`) snapshot and future DB storage |
| `external_data/` | Directory | ~70 KB | External macOS sandbox container backup (live DB, plist, app support) |
| `docs/` | Directory | ~416 KB | Complete architectural, audit, roadmap, and design documentation (36 files) |
| `test/` | Directory | ~252 KB | Flutter automated test suite (32 test files, 170 passing tests) |
| `tests/` | Directory | ~16 KB | End-to-end integration and load-testing test scripts |
| `build/` | Directory | ~1.6 GB | Compiled macOS native binaries, `.app` bundles, frameworks, and build caches |
| `scratch/` | Directory | ~32 KB | Validation and diagnostic helper scripts |
| `backups/` | Directory | 0 B | Local workspace backup directory (used by backup routines) |
| `documents/` | Directory | 0 B | Local document ingestion folder for RAG pipelines |
| `embeddings/` | Directory | 0 B | Local embedding vectors cache folder |
| `pubspec.yaml` | Manifest | 570 B | Flutter/Dart dependency specification |
| `pubspec.lock` | Lockfile | ~20 KB | Locked dependency versions for Dart/Flutter |
| `analysis_options.yaml` | Config | ~1.5 KB | Dart static analysis and lint rules |
| `.env.example` | Template | ~1.6 KB | Environment configuration template for all backends |
| `docker-compose.yml` | Config | ~1.5 KB | Optional containerization for AirLLM, Ollama, and ChromaDB |
| `OLLIVO LOGO.png` | Asset | ~1.0 MB | Master high-resolution brand asset |
| `OLLIVO-v1.dmg` | Installer | ~24 MB | Release candidate drag-and-drop installer disk image |
| `Ollivo.dmg` | Installer | ~24 MB | Previous version disk image |
| `README.md` | Doc | ~3 KB | Quick-start and architectural overview |

---

## 2. Source Code Architecture (`lib/`)

- `lib/main.dart` — Application entry point, window lifecycle, root navigation, theme switching, About dialog.
- `lib/core/` — Constants, typography, colors, animations, accessibility tokens, responsive layout helpers.
- `lib/components/` — Reusable desktop widgets (glassmorphism cards, model selector dialog, Quick Ask, shortcut sheets, prompts).
- `lib/controllers/` — Controller logic (`chat_controller.dart`, `model_controller.dart`).
- `lib/models/` — Data models (`model_configuration.dart`, `model_catalog_item.dart`, `prompt_template.dart`, `rag_pipeline_recommendation.dart`).
- `lib/providers/` — Multi-backend abstraction (`inference_backend_provider.dart`, `ollama_backend_provider.dart`, `airllm_backend_provider.dart`, `lmstudio_backend_provider.dart`, `localai_backend_provider.dart`, `provider_registry.dart`).
- `lib/services/` — Core desktop services:
  - `ai_service.dart`: Chat inference, streaming coordinator, backend router.
  - `airllm_client.dart`: High-performance HTTP client for local AirLLM service with health probing and cancel token.
  - `database_service.dart`: SQLite local persistence (`ollivo.db`) for chats, memories, documents, tasks.
  - `settings_service.dart`: User configuration and preference persistence.
  - `process_service.dart`: Local daemon supervisor (starts, stops, restarts, and monitors AirLLM).
  - `rag_service.dart` & `document_service.dart`: Document ingestion, chunking, and semantic search.
  - `memory_service.dart`: Mem0-style long-term context memory.
  - `mcp_client_service.dart`: Model Context Protocol tool execution.
  - `task_service.dart`: On-device task tracking.

---

## 3. Python AirLLM Microservice (`airllm_service/`)

- `api.py` — FastAPI service exposing Ollama-compatible `/api/generate`, `/api/tags`, `/api/version` and native `/api/ai/*`.
- `config.py` — Pydantic configuration loader for port (8008), host, quantization, model cache, and device.
- `model_manager.py` — AirLLM model loading, sequential layer streaming, prompt execution, and GPU/Metal memory management.
- `service.py` — Uvicorn service bootstrap and lifecycle manager.
- `requirements.txt` — Python dependencies (FastAPI, Uvicorn, torch, transformers, airllm, pydantic, accelerate, mlx).
- `Dockerfile` — Containerized build configuration for container environments.
- `.venv/` — Fully preserved and self-contained Python 3.11 virtual environment with all installed packages.
- `tests/` — Complete unit and integration test suite (23 tests).

---

## 4. Preserved Persistent Data & Backups

1. **Active Live SQLite Database**:
   - Location: `database/ollivo.db` and `external_data/ollivo.db`
   - Verified row counts: Conversations (1), Messages (4), Memories (1), Tasks (0), Documents (0), ModelConfigurations (0).
   - Integrity: Verified with `PRAGMA integrity_check;` (Status: OK).
2. **Application Preferences**:
   - Location: `external_data/com.ollivo.ollivo.plist`
3. **Full Project Backup Archive**:
   - Location: `/Users/asadalishaikh/OLLIVO_v2_BACKUP.tar.gz` (1.0 GB compressed tarball containing bit-for-bit archive).

