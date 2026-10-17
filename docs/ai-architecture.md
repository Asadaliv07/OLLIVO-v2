# Ollivo Modular AI Architecture Specification

> **Document Version:** 2.0.0  
> **Target Platform:** Native macOS Desktop (Flutter / Dart) + Supervised Python Microservice (`airllm_service`)  
> **Execution Environment:** Apple Silicon Metal (MPS / MLX), CoreML, Local Storage  
> **Architectural Paradigm:** 100% Local-First, Zero Cloud Data Leakage, Contract-Based Modularity  

---

## 1. System Architecture Overview

Ollivo separates user experience, process management, inference execution, and hardware acceleration into clean, decoupled layers.

```mermaid
graph TD
    subgraph UI & Presentation Layer (Flutter Desktop)
        ChatView["ChatWorkspace & MessageRenderer"]
        QuickAsk["QuickAskDialog (Global Modal)"]
        SettingsView["Settings & Engine Switch"]
        DocView["Documents & RAG View"]
        VoiceBar["Audio & Narration Controls"]
    end

    subgraph Core Application Controllers
        ChatCtrl["ChatController (Session State, Dispatch)"]
        ModelCtrl["ModelController (Catalog, Diagnostics)"]
    end

    subgraph Modular AI Services Layer (lib/services/)
        GuardrailsSvc["GuardrailsService (NeMo / Guardrails AI)"]
        MCPSvc["McpService (Model Context Protocol)"]
        VectorSvc["VectorStoreService (SQLite-vec, Chroma, Qdrant)"]
        DocParserSvc["DocumentParserService (Docling, Unstructured)"]
        AudioSvc["AudioService (Faster-Whisper, Kokoro, Piper)"]
        MemSvc["MemoryService (Mem0 Persistent Facts)"]
        AuditSvc["AuditService (Langfuse Tracing, Telemetry)"]
        ProcSvc["ProcessService (Subprocess Supervisor)"]
        SettingsSvc["SettingsService (Authoritative Routing & Config)"]
    end

    subgraph Inference Provider Abstraction (ProviderRegistry)
        OllamaProvider["OllamaBackendProvider (11434)"]
        AirLLMProvider["AirLLMBackendProvider (70B+ Layer-Streaming: 8765)"]
        LlamaCppProvider["LlamaCppBackendProvider (GGUF Server: 8080)"]
        LiteLLMProvider["LiteLLMBackendProvider (Universal Proxy: 4000)"]
        LocalAIProvider["LocalAIBackendProvider (8080)"]
    end

    subgraph Local Daemons & Hardware Acceleration
        OllamaDaemon["Ollama Daemon (Metal / CPU)"]
        AirLLMDaemon["airllm_service (FastAPI, PyTorch MPS, MLX)"]
        LlamaCppServer["llama-server / llama-swap (GGUF Metal)"]
        WhisperWorker["Whisper STT Metal Worker"]
        KokoroWorker["Kokoro / Piper TTS Synthesis Worker"]
        LocalDisk["Encrypted SSD Storage (~/.cache, ~/Library/Application Support)"]
    end

    ChatView --> ChatCtrl
    QuickAsk --> ChatCtrl
    ChatCtrl --> GuardrailsSvc
    GuardrailsSvc -->|Sanitized Prompt| ChatCtrl
    ChatCtrl --> MemSvc
    ChatCtrl --> DocParserSvc
    DocParserSvc --> VectorSvc
    ChatCtrl --> MCPSvc
    ChatCtrl --> SettingsSvc
    SettingsSvc -->|Authoritative Routing| ProviderRegistry
    ProviderRegistry --> OllamaProvider
    ProviderRegistry --> AirLLMProvider
    ProviderRegistry --> LlamaCppProvider
    ProviderRegistry --> LiteLLMProvider
    ProviderRegistry --> LocalAIProvider
    OllamaProvider --> OllamaDaemon
    AirLLMProvider --> AirLLMDaemon
    LlamaCppProvider --> LlamaCppServer
    AudioSvc --> WhisperWorker
    AudioSvc --> KokoroWorker
    AuditSvc --> LocalDisk
```

---

## 2. Logical Boundaries and Service Interfaces

### 2.1 Inference Providers (`lib/services/providers/backend_provider.dart`)
All LLM engines conform to the `InferenceBackendProvider` abstract interface:
```dart
abstract class InferenceBackendProvider {
  String get id;
  String get name;
  String get description;
  String get endpointUrl;
  bool get isLocalOnly;
  List<String> get supportedCategories;

  Future<bool> checkInstalled();
  Future<Map<String, dynamic>> checkHealth();
  Future<List<String>> listAvailableModels();
}
```
* **Supported Backends:**
  - `ollama`: Default general-purpose model server.
  - `airllm`: 70B+ sequential layer-streaming engine for low-RAM Macs.
  - `llamacpp`: High-speed GGUF inference via `llama-server`.
  - `litellm`: Universal proxy to arbitrary local or remote OpenAI-compatible gateways.
  - `localai`: Self-hosted multi-modal model engine.

### 2.2 Security & Guardrails (`lib/services/guardrails_service.dart`)
Inspired by **NVIDIA NeMo-Guardrails** and **Guardrails AI**:
* **Input Rails:**
  - Prompt injection and jailbreak pattern detection (e.g., "ignore previous instructions", roleplay bypasses).
  - Secret and PII masking (API keys, emails, credit card numbers, phone numbers).
  - Command injection prevention (blocking unauthorized terminal/shell attempts).
* **Output Rails:**
  - Code safety check (disallowing dangerous system calls like `rm -rf`, format disk).
  - Refusal to output unredacted personal identifiers.
  - Hallucination / ungrounded claims detection on RAG answers.

### 2.3 Model Context Protocol / MCP (`lib/services/mcp_service.dart`)
Implements Anthropic's **Model Context Protocol** specification:
* **Tool Discovery:** Polls registered stdio and HTTP/SSE MCP servers for available tools.
* **Schema Validation:** Strict JSON Schema validation for tool input arguments before invocation.
* **Human-in-the-Loop Approval:** Sensitive tools (file writing, shell execution, external HTTP requests) require explicit user consent via desktop modal.
* **Execution Sandbox:** Enforces timeouts, maximum output tokens, and execution sandboxing.

### 2.4 Vector Store Abstraction (`lib/services/vector_store_service.dart`)
Provides an extensible vector database abstraction with multiple pluggable drivers:
* **SQLite-vec:** Embedded, zero-overhead vector extension running inside SQLite (`ollivo.db`).
* **Qdrant:** High-speed external Rust vector database via HTTP REST (`http://127.0.0.1:6333`).
* **Chroma:** Popular AI-native embedding store via HTTP REST (`http://127.0.0.1:8000`).
* **In-Memory Faiss:** Transient high-speed vector index for session-only document querying.

### 2.5 Document Ingestion & Parsing (`lib/services/document_parser_service.dart`)
Inspired by **Docling** and **Unstructured**:
* Layout-aware extraction preserving headings, paragraphs, bullet points, and code blocks.
* Markdown table reconstruction from structured text.
* Overlapping chunking with metadata tracking (source filename, chunk index, byte offset, character count).
* Automatic citation generation (`[Document: sample.pdf (Chunk #2)]`).

### 2.6 Speech & Audio Engine (`lib/services/audio_service.dart`)
* **Speech-to-Text (STT):** Local **Faster-Whisper** transcription of microphone input (.wav, .m4a, .mp3).
* **Text-to-Speech (TTS):** High-speed local neural synthesis via **Kokoro-82M** (ultra-natural studio quality) or **Piper** (sub-50ms latency).
* **Audio Playback:** Native macOS AppKit audio player support with live playback progress.

### 2.7 Observability, Auditing, and Evaluation (`lib/services/audit_service.dart`)
* Structured JSON audit logging to local disk (`backups/audit.log`).
* OpenTelemetry trace context propagation (compatible with **Langfuse** and **Phoenix**).
* Evaluation metrics: Time to first token (TTFT), tokens per second (TPS), memory RSS, and RAG faithfulness scores.

---

## 3. Resilience, Concurrency, and Error Handling

1. **In-Flight Request Isolation:** Active generation queries snapshot their configuration (`activeHost`, `activeModel`, `activeBackend`) into local closure variables at dispatch. Toggling switches or changing settings mid-stream never corrupts an in-flight stream.
2. **Exponential Backoff & Circuit Breakers:** Transient connection errors retry up to 3 times with exponential backoff ($200\text{ms} \rightarrow 400\text{ms} \rightarrow 800\text{ms}$). Consecutive failures trigger a circuit breaker to avoid hanging the UI.
3. **Queue Overload Protection:** The local Python service enforces `max_queue_depth` through an `asyncio.Lock` queue. Requests exceeding the limit return HTTP 429 instead of crashing the GPU.
4. **Clean Process Lifecycle:** All background daemons (Ollama, AirLLM, Llama.cpp, Whisper) are monitored by `ProcessService`. Process terminations, crashes, or port conflicts are cleanly caught, reported in the UI, and logged.
