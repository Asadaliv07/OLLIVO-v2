# Ollivo — Master Feature & Improvement Inventory

## Executive Overview
This document serves as the canonical master inventory of all planned, recommended, and prospective capabilities for **Ollivo**, the 100% local-first private AI assistant built specifically for macOS desktop.

---

## Classification Schema

- **Level 1 (Major)**: Foundational architectures, new core workflows, major native integrations.
- **Level 2 (Standard)**: Enhancements to existing views, deeper capabilities, improved controllers.
- **Level 3 (Small & Micro)**: Polish details, interaction affordances, edge-case UI safeguards, micro-animations.

**Priority Definitions**:
- **P0 (Essential)**: Critical reliability, data safety, core usability bottlenecks.
- **P1 (High Value)**: Capabilities that drastically improve utility, power, and desktop productivity.
- **P2 (Useful)**: High-quality secondary enhancements.
- **P3 (Optional)**: Experimental or niche features.

**Effort Scale**: `XS` (< 2 hours), `S` (half-day), `M` (1-2 days), `L` (3-5 days), `XL` (1+ week).

---

## Category A: Core AI Experience

| ID | Feature Name | Level | State | Priority | Effort | Risk | Dependencies |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **CORE-001** | **Rich Markdown & Code Syntax Highlighting** | Major | Incomplete | P0 | M | Low | None |
| **CORE-002** | **Unified Conversation Search & Filter** | Standard | Missing | P1 | S | Low | SQLite FTS5 |
| **CORE-003** | **Conversation Branching & Message Editing** | Major | Missing | P2 | L | Med | Database schema |
| **CORE-004** | **Prompt Token Counter & Speed (tok/s) Telemetry** | Standard | Missing | P1 | S | Low | Ollama metadata |
| **CORE-005** | **Multi-Conversation Tagging & Folder Organization**| Standard | Missing | P2 | M | Low | Database schema |
| **CORE-006** | **Chat Export (Markdown, PDF, JSON)** | Standard | Missing | P1 | S | Low | File system |
| **CORE-007** | **Interactive Follow-up Prompt Suggestions** | Small | Missing | P2 | XS | Low | ChatController |
| **CORE-008** | **Auto-Scroll Pin / Unpin on User Upward Scroll** | Small | Verified Defect | P0 | XS | Low | ScrollController |
| **CORE-009** | **Copy Code Block with Language Pill & Feedback** | Micro | Missing | P0 | XS | Low | Markdown widget |
| **CORE-010** | **Prompt Input Auto-Expand & Max-Height Scroll** | Micro | Incomplete | P1 | XS | Low | TextField |

### Detailed Specifications

#### CORE-001: Rich Markdown & Code Syntax Highlighting
- **Current State**: Plain text message bubbles without syntax-highlighted fenced code blocks or table rendering.
- **Recommendation**: Integrate `flutter_markdown` with a custom syntax highlighter matching the Onyx/Emerald theme. Code blocks must feature language badges (e.g., `dart`, `python`, `sql`), line numbers, and a dedicated 1-click copy button.
- **User Benefit**: Enables developers and knowledge workers to read, copy, and utilize code and tables seamlessly.
- **Acceptance Criteria**: Formatted code blocks render in dark monospace container with syntax coloring and working copy button.

#### CORE-002: Unified Conversation Search & Filter
- **Current State**: Chat history is only viewed by switching conversations in the sidebar. Searching message content is impossible.
- **Recommendation**: Implement SQLite FTS5 virtual table for `messages` and an in-chat search bar (`⌘+F`) highlighting matching keywords with Next/Previous navigation.
- **User Benefit**: Users can instantly locate specific past answers, code snippets, or decisions.
- **Acceptance Criteria**: `⌘+F` opens search overlay; matches are highlighted and scroll into view.

#### CORE-004: Prompt Token Counter & Speed (tok/s) Telemetry
- **Current State**: Users have no visibility into token count, generation speed, or time to first token.
- **Recommendation**: Parse Ollama `/api/generate` response metrics (`eval_count`, `eval_duration`, `prompt_eval_duration`) and display subtle latency pills below assistant messages (e.g., `24.5 tok/s • 342 tokens • 1.4s`).
- **User Benefit**: Complete performance transparency when running local models on Apple Silicon.
- **Acceptance Criteria**: Assistant message footer renders token speed and count once generation concludes.

---

## Category B: Model Library & Local AI Management

| ID | Feature Name | Level | State | Priority | Effort | Risk | Dependencies |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **MOD-001** | **VRAM & Unified Memory Estimation Badge** | Standard | Missing | P1 | S | Low | Hardware query |
| **MOD-002** | **One-Click Ollama Daemon Launcher / Restarter** | Standard | Incomplete | P0 | M | Med | Process runner |
| **MOD-003** | **Custom Model Pull (Any Ollama / HF GGUF Tag)** | Standard | Missing | P1 | S | Low | AIService |
| **MOD-004** | **Model Parameters & Modelfile Inspector** | Standard | Missing | P2 | M | Low | Ollama `/api/show` |
| **MOD-005** | **Active Model Quick-Switcher in Top Bar** | Small | Incomplete | P1 | XS | Low | Top bar widget |
| **MOD-006** | **Storage Footprint Breakdown Bar** | Small | Missing | P2 | S | Low | SettingsService |
| **MOD-007** | **In-Flight Download Pause & Resume Feedback** | Small | Incomplete | P1 | S | Low | ModelController |
| **MOD-008** | **Model Benchmark & Speed Test Utility** | Standard | Missing | P3 | M | Low | AIService |

### Detailed Specifications

#### MOD-001: VRAM & Unified Memory Estimation Badge
- **Current State**: Model cards display static disk size (e.g., `4.7 GB`), but no guidance on Apple Silicon Unified Memory requirements (e.g., 8GB vs 16GB vs 36GB Mac).
- **Recommendation**: Add dynamic compatibility pills on recommended model cards: `Comfortable on 8GB RAM`, `Requires 16GB+ RAM`, or `May swap on 8GB RAM`.
- **User Benefit**: Prevents users from downloading models that will freeze or slow down their Mac.
- **Acceptance Criteria**: Model cards indicate memory headroom based on model parameter count and quantization.

#### MOD-002: One-Click Ollama Daemon Launcher / Restarter
- **Current State**: If Ollama is offline, the app prompts the user to open Terminal and type `ollama serve`.
- **Recommendation**: Provide a prominent "Start Local Ollama Engine" button that spawns `ollama serve` directly from the app via background process execution.
- **User Benefit**: Zero-friction experience for non-technical users who don't want to use Terminal.
- **Acceptance Criteria**: Clicking "Start Ollama" launches the service in background and transitions status pill to Connected within 3 seconds.

---

## Category C: Memory & Personalization

| ID | Feature Name | Level | State | Priority | Effort | Risk | Dependencies |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **MEM-001** | **Memory Categorization & Tag Filter** | Standard | Incomplete | P1 | S | Low | Database schema |
| **MEM-002** | **Inline Memory Editing & Correction Modal** | Standard | Incomplete | P1 | S | Low | UI Dialog |
| **MEM-003** | **Semantic Deduplication on Memory Save** | Standard | Missing | P1 | M | Med | Embedding/TF-IDF |
| **MEM-004** | **Memory Pinning & System Prompt Exclusion** | Small | Missing | P2 | XS | Low | MemoryService |
| **MEM-005** | **Memory Export / Import (JSON / CSV)** | Standard | Missing | P2 | S | Low | File picker |
| **MEM-006** | **"Why does Ollivo know this?" Source Inspector** | Small | Missing | P2 | S | Low | Conversation link |
| **MEM-007** | **Auto-Purge / Time-To-Live (TTL) for Temporary Facts**| Small | Missing | P3 | M | Low | Database service |

### Detailed Specifications

#### MEM-002: Inline Memory Editing & Correction Modal
- **Current State**: Users can delete memories or create new ones manually, but cannot edit existing saved facts if Ollivo extracted an imprecise statement.
- **Recommendation**: Add an "Edit Fact" action button on memory cards that opens an editor dialog with Category dropdown and Fact input field.
- **User Benefit**: Users maintain complete editorial control over what Ollivo remembers about their preferences.
- **Acceptance Criteria**: Editing a memory persists changes to SQLite and updates the Memory Center list immediately.

---

## Category D: Tasks & Productivity

| ID | Feature Name | Level | State | Priority | Effort | Risk | Dependencies |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TSK-001** | **Natural Language Chat-to-Task Parser** | Major | Missing | P1 | M | Low | Prompt heuristics |
| **TSK-002** | **Due Date Native Calendar Picker** | Standard | Incomplete | P1 | XS | Low | Flutter DatePicker |
| **TSK-003** | **macOS Notification Reminders for Due Tasks** | Standard | Missing | P2 | M | Med | macOS local_notifier |
| **TSK-004** | **Subtasks / Checklist Inside Tasks** | Standard | Missing | P2 | M | Low | Database schema |
| **TSK-005** | **Kanban Board vs List View Toggle** | Standard | Missing | P2 | M | Low | UI Layout |
| **TSK-006** | **One-Click Task Context Insertion in Chat** | Small | Missing | P1 | XS | Low | ChatController |
| **TSK-007** | **Batch Task Actions (Mark Completed, Delete Selected)**| Small | Missing | P2 | S | Low | TaskService |

### Detailed Specifications

#### TSK-001: Natural Language Chat-to-Task Parser
- **Current State**: Tasks are strictly managed manually in the Task Workspace view.
- **Recommendation**: Add a quick action button on assistant messages containing action items: "Add to Tasks". The app parses the bullet points into pending tasks with 1 click.
- **User Benefit**: Bridges the gap between AI ideation and execution.
- **Acceptance Criteria**: Clicking "Add to Tasks" creates corresponding `TaskItem` records in SQLite.

---

## Category E: Documents & Knowledge (Local RAG)

| ID | Feature Name | Level | State | Priority | Effort | Risk | Dependencies |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **DOC-001** | **Local Vector Embeddings via Ollama `/api/embeddings`** | Major | Incomplete | P1 | L | Med | Ollama Embeddings |
| **DOC-002** | **Native PDF & DOCX Text Extraction** | Major | Incomplete | P1 | M | Low | Dart PDF parser |
| **DOC-003** | **Interactive Source Citations in Chat Responses** | Standard | Missing | P1 | S | Low | Chat UI |
| **DOC-004** | **Document Chunk Visualizer & Inspector** | Standard | Missing | P2 | S | Low | UI Component |
| **DOC-005** | **Document Collections / Folders** | Standard | Missing | P2 | M | Low | Database schema |
| **DOC-006** | **Drag-and-Drop File Import Zone** | Standard | Incomplete | P1 | S | Low | `desktop_drop` |
| **DOC-007** | **Progress Bar for Multi-Page Document Ingestion** | Small | Missing | P1 | XS | Low | DocumentService |

### Detailed Specifications

#### DOC-001: Local Vector Embeddings via Ollama
- **Current State**: `DocumentService` uses a lightweight TF-IDF keyword overlap engine.
- **Recommendation**: Complement keyword search with true dense vector embeddings generated locally using Ollama's embedding models (`nomic-embed-text` or `all-minilm`), storing vectors in SQLite for hybrid dense/sparse retrieval.
- **User Benefit**: Semantic search handles synonyms and conceptual matches that exact keyword overlap misses.
- **Acceptance Criteria**: RAG queries retrieve documents based on semantic meaning even without exact keyword matches.

---

## Category F: Settings & Configuration

| ID | Feature Name | Level | State | Priority | Effort | Risk | Dependencies |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **SET-001** | **Custom System Instructions / Persona Editor** | Standard | Missing | P1 | S | Low | SettingsService |
| **SET-002** | **Complete Backup & Restore to Encrypted ZIP Archive** | Major | Missing | P1 | M | Low | Archive package |
| **SET-003** | **Database Size Inspector & Vacuum Utility** | Small | Missing | P2 | XS | Low | DatabaseService |
| **SET-004** | **Auto-Launch at macOS Login Toggle** | Small | Missing | P2 | S | Low | macOS runner |
| **SET-005** | **Ollama Port & Custom Remote Host Switcher** | Standard | Incomplete | P1 | XS | Low | AIService |
| **SET-006** | **Model Context Window (num_ctx) Slider** | Standard | Missing | P1 | XS | Low | AIService |

---

## Category G: macOS-Native Capabilities

| ID | Feature Name | Level | State | Priority | Effort | Risk | Dependencies |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **MAC-001** | **Global Spotlight-Style Quick Ask (`⌘+Shift+Space`)** | Major | Missing | P1 | L | Med | macOS runner |
| **MAC-002** | **Menu Bar Extra (Tray Icon with Mini Popover)** | Standard | Missing | P2 | M | Med | tray_manager |
| **MAC-003** | **Native macOS Application Menu Bar (`File`, `Edit`, etc.)**| Standard | Incomplete | P0 | S | Low | Flutter MenuBar |
| **MAC-004** | **Window Position & Dimension Restoration Across Launches**| Small | Missing | P1 | S | Low | `window_manager` |
| **MAC-005** | **Native File Drag-and-Drop Anywhere in Window** | Small | Incomplete | P1 | S | Low | `desktop_drop` |
| **MAC-006** | **Dock Badge for In-Flight Model Downloads** | Small | Missing | P2 | XS | Low | macOS runner |

---

## Category H: UI/UX, Typography & Visual Polish

| ID | Feature Name | Level | State | Priority | Effort | Risk | Dependencies |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **UI-001** | **Fluid Multi-Pane Collapsible Sidebar** | Standard | Incomplete | P1 | S | Low | main.dart |
| **UI-002** | **Smooth Token Streaming Fade-In Micro-Animation** | Small | Missing | P2 | S | Low | ChatView |
| **UI-003** | **Custom Monospace Font for Code Blocks (JetBrains Mono)**| Small | Missing | P1 | XS | Low | Typography |
| **UI-004** | **Keyboard-First Navigation (`Tab`, `Escape`, `Enter`)** | Standard | Incomplete | P0 | S | Low | FocusNode |
| **UI-005** | **Empty State Illustrations & Guided Action Prompts** | Small | Incomplete | P1 | S | Low | Components |
| **UI-006** | **Context Menu on Messages (Copy, Share, Branch, Delete)**| Small | Missing | P1 | S | Low | ContextMenu |

---

## What Ollivo Should NOT Build (Anti-Features)

To maintain privacy, speed, and architectural elegance, the following capabilities are **explicitly out of scope**:

1. **Cloud Sync / Telemetry / Third-Party Analytics**: Violates Ollivo's 100% offline, privacy-first brand promise.
2. **Proprietary Closed-Source Cloud API Connectors (OpenAI / Anthropic)**: Ollivo is built to celebrate local open weights running on local silicon, not to be another web wrapper API client.
3. **Complex Enterprise Multi-User RBAC**: Ollivo is a personal desktop power tool for single Mac users.
4. **Heavyweight Vector Database Microservices (Milvus / Qdrant Docker containers)**: Local SQLite with FTS5 or embedded sqlite-vss is orders of magnitude lighter, faster, and self-contained.
5. **Web Browser Extensions / Mobile Companion Apps**: Ollivo is strictly a native macOS desktop application.
