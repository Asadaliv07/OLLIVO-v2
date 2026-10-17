# Ollivo AI Integration & Operational Guide

## 1. Executive Overview

This guide provides end-to-end instructions for configuring, operating, and troubleshooting Ollivo's local AI infrastructure. Ollivo is an entirely on-device, 100% private AI desktop workspace running on macOS with Apple Silicon (Metal / MPS) hardware acceleration.

All integrations are strictly modular, allowing each component to operate independently, fail gracefully without disrupting the Flutter desktop application, and maintain absolute local privacy ($0 cloud API costs, zero data leakage).

---

## 2. Integrated Components & Operational Profiles

| Subsystem | Primary Implementation | Fallback / Alternative | Port / Socket |
|---|---|---|---|
| **Inference Engines** | Llama.cpp (GGUF Metal), AirLLM (Layer-Streaming) | Ollama, LocalAI, LiteLLM Proxy | `:8765`, `:11434`, `:8080`, `:4000` |
| **Safety & Guardrails** | NeMo / Guardrails AI Hybrid (`GuardrailsService`) | Relaxed Developer Profile | Local in-process |
| **Vector Database** | SQLite-vec (`VectorStoreService`) | Qdrant REST, Chroma, Faiss In-Memory | `:6333` (Qdrant), `:8000` (Chroma) |
| **Tool Orchestration** | Anthropic MCP Standard (`McpService`) | Built-in native tools | Stdio / Loopback HTTP |
| **Speech & Voice** | Faster-Whisper (STT), Kokoro-82M / Piper (TTS) | macOS Speech Synthesis | Local in-process / `:8765` |
| **Document Parsing** | Docling / Unstructured Engine (`DocumentParserService`) | Plaintext / regex extraction | Local in-process |
| **Evaluation & Tracing** | Internal Trace Telemetry (`AIEvaluationService`) | Langfuse Local Container | `:3000` (Optional) |

---

## 3. Environment Configuration (`.env.example`)

A sanitized configuration template is provided at `.env.example`.

```env
# ==============================================================================
# OLLIVO LOCAL AI DESKTOP CONFIGURATION
# ==============================================================================

# Inference Service (AirLLM / Python Backend)
AIRLLM_HOST=127.0.0.1
AIRLLM_PORT=8765
AIRLLM_DEVICE=mps                         # 'auto', 'mps', 'cpu', or 'cuda:0'
AIRLLM_COMPRESSION=4bit                    # '4bit', '8bit', or None
AIRLLM_DEFAULT_MODEL=meta-llama/Meta-Llama-3-8B-Instruct
AIRLLM_MAX_QUEUE_DEPTH=100
AIRLLM_TIMEOUT_SECONDS=180

# Multi-Backend Inference Providers
OLLAMA_BASE_URL=http://127.0.0.1:11434
LOCALAI_BASE_URL=http://127.0.0.1:8080
LLAMACPP_BASE_URL=http://127.0.0.1:8080
LITELLM_PROXY_URL=http://127.0.0.1:4000

# Vector Database Configuration
VECTOR_STORE_BACKEND=sqliteVec            # 'sqliteVec', 'qdrant', 'chroma', 'inMemoryFaiss'
QDRANT_URL=http://127.0.0.1:6333
CHROMA_URL=http://127.0.0.1:8000

# Safety Guardrails Policy
GUARDRAILS_POLICY=standard                # 'standard', 'strict', or 'relaxed'
GUARDRAILS_BLOCK_INJECTION=true
GUARDRAILS_REDACT_PII=true
GUARDRAILS_BLOCK_DESTRUCTIVE=true

# Speech & Multimodal Services
STT_ENGINE=fasterWhisper                  # 'fasterWhisper', 'openaiWhisper', 'systemNative'
TTS_ENGINE=kokoro82m                     # 'kokoro82m', 'piper', 'systemNative'

# MCP Tool Sandbox
MCP_ALLOW_LOCAL_TOOLS=true
MCP_REQUIRE_HUMAN_APPROVAL_FOR_SENSITIVE=true
```

---

## 4. Quickstart & Service Launch

### 4.1. Starting the Python Local Inference Service
```bash
# Navigate to workspace root
cd "/Users/asadalishaikh/ OLLIVO WORKSPACE"

# Activate the dedicated virtual environment
source airllm_service/.venv/bin/activate

# Launch the service with Uvicorn
python -m uvicorn airllm_service.api:app --host 127.0.0.1 --port 8765 --log-level info
```

### 4.2. Running the Desktop Application
```bash
# Verify Dart/Flutter static analysis
dart analyze lib/ test/

# Run the macOS desktop app
flutter run -d macos
```

---

## 5. API Usage Examples

### 5.1. Text Generation with Guardrails & Model Streaming
```dart
// Dart snippet within Ollivo
final guardrails = GuardrailsService();
final inspection = guardrails.inspectPrompt(userInput);

if (!inspection.isAllowed) {
  print('Blocked by Guardrails: ${inspection.violations.first.message}');
  return;
}

final aiService = AIService();
final stream = aiService.streamChat(
  prompt: inspection.sanitizedText,
  model: 'qwen2.5-coder:1.5b',
);

await for (final token in stream) {
  stdout.write(token);
}
```

### 5.2. Vector Storage & Nearest Neighbor Retrieval
```dart
final vectorStore = VectorStoreService();
vectorStore.configure(backend: VectorStoreBackend.sqliteVec);

// Upsert Document Chunks
await vectorStore.upsert('project_docs', [
  VectorDocument(
    id: 'chunk_001',
    vector: [0.12, 0.45, -0.22, ...],
    text: 'Apple Silicon Metal Performance Shaders accelerate tensor operations.',
    metadata: {'source': 'metal_guide.pdf'},
  ),
]);

// Semantic Search
final results = await vectorStore.search('project_docs', queryVector, topK: 3);
for (final match in results) {
  print('Score: ${match.score} | Content: ${match.text}');
}
```

### 5.3. Model Context Protocol (MCP) Tool Execution
```dart
final mcpService = McpService();

// Prompt user for confirmation on sensitive tools
mcpService.onApprovalRequested = (toolName, arguments) async {
  return await showConfirmationDialog(
    title: 'Approve Tool Execution',
    message: 'AI wants to run $toolName with arguments: $arguments',
  );
};

// Execute tool safely
final result = await mcpService.executeTool('write_local_file', {
  'filename': 'summary.md',
  'content': '# Meeting Summary\nApproved local notes.',
});

if (result.success) {
  print('Tool Output: ${result.output}');
} else {
  print('Tool Error: ${result.error}');
}
```

---

## 6. Failure Recovery & Troubleshooting

### Q1: The Python inference daemon fails to start or crashes with `Insufficient disk space`.
- **Cause**: AirLLM requires at least 10 GB of free SSD space to write and swap quantized layer shards to `~/.cache/ollivo/airllm/shards`.
- **Resolution**: Check disk space with `df -h`. Clean stale layer shards:
  ```bash
  rm -rf ~/.cache/ollivo/airllm/shards/*
  ```

### Q2: Requests return `HTTP 429 Too Many Requests`.
- **Cause**: High concurrency burst exceeded `AIRLLM_MAX_QUEUE_DEPTH` (default 100).
- **Resolution**: This is an intentional backpressure mechanism to prevent host Out-Of-Memory (OOM) crashes. Ollivo's client handles this with exponential backoff and automatic retry.

### Q3: Guardrail rejects input stating `Detected prompt injection`.
- **Cause**: The input matched known jailbreak patterns (`DAN mode`, `developer mode`, `bypass guardrails`, system token delimiters).
- **Resolution**: For developers testing model boundaries, switch policy in Settings to `Relaxed`:
  ```dart
  GuardrailsService().updatePolicy(GuardrailsPolicy.relaxed);
  ```

### Q4: An external vector store (Qdrant/Chroma) is unreachable.
- **Cause**: The Docker container or local service is not running.
- **Resolution**: Ollivo automatically falls back to in-process `sqliteVec` and in-memory cosine search, preserving full app functionality without downtime.
