# Ollivo — Screen-by-Screen Improvement Plan

## Architecture Overview
Ollivo's macOS desktop user interface is structured around a unified macOS three-pane desktop shell:
1. **Collapsible Navigation & History Sidebar**
2. **Top Header Bar with macOS Traffic Lights & Status Telemetry**
3. **Primary Content Workspace** (displaying one of the 6 active views: `Chat`, `Model Library`, `Memory Center`, `Tasks`, `Documents`, or `Settings`).

This document provides a concrete, file-by-file audit and upgrade plan for every screen in the application.

---

## 1. App Shell & Navigation (`lib/main.dart`)

### What Should Remain
- Dark Onyx glassmorphism theme (`#0F172A` / `#020617`) with emerald accenting (`#10B981`).
- Clean split layout with sidebar on the left and primary content on the right.
- Reactive state connection using `AnimatedBuilder` and Flutter services (`SettingsService`, `AIService`, `DatabaseService`).

### What Should Change
- **Collapsible Sidebar (`UI-001`)**: Allow collapsing the sidebar into a slim icon-only rail (72px) with a toggle button or keyboard shortcut (`⌘+\`).
- **Traffic Light Window Margin (`MACU-01`)**: Top bar currently needs guaranteed 78px left inset to avoid collision with native macOS window traffic lights (Close/Minimize/Zoom) on non-fullscreen launches.
- **Top Bar Model Switcher (`MOD-005`)**: Turn the top bar's active model indicator into a direct dropdown popup menu so users can switch active models without opening Settings or Model Library.

### What Should Be Added
- **Global macOS Menu Bar (`MAC-003`)**: Implement `PlatformMenuBar` providing native system menus:
  - `Ollivo`: About Ollivo, Settings (`⌘,`), Hide (`⌘H`), Quit (`⌘Q`).
  - `File`: New Conversation (`⌘N`), Import Document (`⌘O`), Export Chat (`⌘E`).
  - `Edit`: Undo (`⌘Z`), Cut (`⌘X`), Copy (`⌘C`), Paste (`⌘V`), Select All (`⌘A`).
  - `View`: Toggle Sidebar (`⌘\`), Zoom In (`⌘+`), Zoom Out (`⌘-`).
  - `Window`: Minimize (`⌘M`), Zoom, Bring All to Front.
- **Window State Restoration (`MAC-004`)**: Save and restore window dimensions and position between launches via `window_manager`.

### What Should Be Removed or Simplified
- Remove redundant status text when Ollama is running normally to keep the header minimal and distraction-free.

### Missing Interactions & Micro Details
- Active conversation item in the sidebar should show a hover delete/rename icon on mouseover (`CTX-02`).
- Sidebar conversation titles should truncate gracefully with tooltips on overflow (`TOOL-04`).

### Verification & Testing Suite
- **Widget Test**: Verify sidebar collapse/expand preserves state and adjusts layout constraints without overflow.
- **Menu Bar Test**: Test that `PlatformMenuBar` shortcuts (`⌘N`, `⌘,`) correctly trigger corresponding controller actions.

---

## 2. Chat View (`lib/views/chat/chat_view.dart`)

### What Should Remain
- Streaming response rendering with incremental token appending.
- Clean conversation layout with distinct user and assistant bubble styling.
- Stop button for interrupting active generation.
- Bottom prompt bar with multiline text field and send button.

### What Should Change
- **Markdown & Code Rendering (`CORE-001`, `UI-003`)**: Replace plain `Text` widgets with rich Markdown rendering featuring syntax-colored code blocks, inline code badges, tables, and blockquotes.
- **Input Field Ergonomics (`INP-01`, `CORE-010`)**: Upgrade the prompt box to smoothly auto-expand from 1 to 6 lines, locking to scrollable text beyond 6 lines.
- **Auto-Scroll Behavior (`CORE-008`, `SCRL-01`)**: Auto-scroll must immediately unpin when the user manually scrolls up by more than 40px during active streaming, and re-pin when clicking the floating "Scroll to bottom" button.

### What Should Be Added
- **In-Chat Quick Find (`CORE-002`, `SHORT-03`)**: Add a `⌘+F` floating search bar with match counter (`3 of 12`) and Previous/Next buttons.
- **Token Generation Telemetry (`CORE-004`)**: Display speed and token metrics below completed assistant messages (e.g., `28.4 tok/s • 412 tokens • 1.2s TTFT`).
- **1-Click Code Block Copy (`CORE-009`, `CLIP-02`)**: Add a copy button to every fenced code block with a 2-second checkmark feedback.
- **Chat Context Attachments (`INP-04`)**: Render removable pill badges for documents or tasks attached to the current prompt.
- **Chat-to-Task Quick Action (`TSK-001`)**: Add an "Add to Tasks" button on assistant messages containing action checklists.

### What Should Be Removed or Simplified
- Remove the full-screen blocking warning when Ollama is disconnected; replace with a clean in-chat status banner with a 1-click "Launch Ollama" button (`MOD-002`).

### Missing Interactions & Micro Details
- Up-Arrow key in an empty prompt field retrieves the last submitted message for editing (`SHORT-05`).
- Message right-click context menu: Copy Text, Copy Raw Markdown, Create Task, Add to Memories, Delete (`CTX-01`).
- Pulsing three-dot animation while waiting for the first token (`HOV-04`).

### Verification & Testing Suite
- **Test**: Multiline Markdown code block renders with correct syntax highlighting and copy button.
- **Test**: User upward scroll unpins auto-scroll; clicking button scrolls to bottom and re-pins.
- **Test**: Streaming interruption flushes accumulated tokens to SQLite without message loss.

---

## 3. Model Library View (`lib/views/models/model_library_view.dart`)

### What Should Remain
- Recommended model cards (`llama3.2`, `deepseek-r1:8b`, `qwen2.5:7b`, `mistral:7b`, `phi3:mini`).
- Installed models tab with active model indicator and delete capability.
- In-flight download progress bar with percentage readout.

### What Should Change
- **RAM Compatibility Guidance (`MOD-001`)**: Add dynamic memory badges to model cards (`Comfortable on 8GB RAM`, `Requires 16GB+ RAM`, `Apple Silicon 24GB+ Recommended`) based on parameter size and quantization.
- **Ollama Process Control (`MOD-002`)**: Add an integrated "Start Local Ollama Daemon" button when the service is detected as offline.

### What Should Be Added
- **Custom Model Tag Pull Field (`MOD-003`)**: Provide a text field allowing users to pull any arbitrary model tag from Ollama library or Hugging Face GGUFs (e.g., `smollm2:1.7b`, `codellama:13b`).
- **Modelfile Inspector (`MOD-004`)**: Add a "View Model Details" modal that calls Ollama `/api/show` to inspect context length, template format, license, and parameter count.
- **Disk Footprint Visualization (`MOD-006`)**: Display a segmented bar showing total disk space used by Ollivo models compared to free Mac storage.

### What Should Be Removed or Simplified
- Simplify card layouts to reduce vertical height and fit more models on laptop screens without excessive scrolling.

### Missing Interactions & Micro Details
- Confirmation modal before deleting an installed model to prevent accidental multi-gigabyte re-downloads (`FDBK-02`).
- Download cancellation button with cleanup of temporary blobs (`FDBK-04`).

### Verification & Testing Suite
- **Test**: Model download triggers progress updates and updates installed list on completion.
- **Test**: Deleting an installed model invokes `/api/delete` and immediately removes it from local UI.

---

## 4. Memory Center View (`lib/views/memories/memory_center_view.dart`)

### What Should Remain
- Search field for filtering memories by keyword.
- Memory count badge and category badges (`preference`, `workflow`, `fact`, `system`).
- Manual "Add Memory" modal.
- Individual memory delete buttons.

### What Should Change
- **Inline Memory Editing (`MEM-002`)**: Add an edit pencil button on each card allowing users to modify the text or category directly in an inline modal.
- **Category Filter Pills (`MEM-001`)**: Add horizontal filter chips (`All`, `Preferences`, `Workflows`, `Facts`) above the list for instant category toggling.

### What Should Be Added
- **Semantic Deduplication (`MEM-003`)**: Prevent saving redundant or conflicting memories when Ollivo extracts facts from conversations.
- **Memory Pinning (`MEM-004`)**: Allow pinning key facts that are guaranteed to be injected into the system prompt regardless of token budget.
- **Export & Import (`MEM-005`)**: Add JSON export and import for transferring memories across machines or backing up personal profiles.

### What Should Be Removed or Simplified
- Remove redundant duplicate timestamp displays on cards; show relative time (`Updated 2 days ago`).

### Missing Interactions & Micro Details
- Context menu on right-click: Edit, Copy Fact, Pin, Delete (`CTX-03`).
- Empty state with example facts: *"e.g., 'I prefer concise answers with Flutter code examples'"* (`UI-005`).

### Verification & Testing Suite
- **Test**: Editing a memory persists to SQLite and updates the list reactively.
- **Test**: Category filter chips filter list accurately in real time.

---

## 5. Tasks & Productivity View (`lib/views/tasks/tasks_view.dart`)

### What Should Remain
- Task list with checkbox completion toggles.
- Priority indicators (High, Medium, Low).
- Due date displays.
- New task modal.

### What Should Change
- **Native Calendar Date Picker (`TSK-002`)**: Replace basic date text entry with Flutter's desktop calendar picker.
- **Task-to-Chat Quick Insertion (`TSK-006`)**: Add an "Ask Ollivo about this task" action button that opens Chat with the task details pre-populated in the context bar.

### What Should Be Added
- **Natural Language Chat-to-Task Parser (`TSK-001`)**: Allow pasting or sending bulleted text to auto-generate multiple structured tasks.
- **macOS Due Date Notifications (`TSK-003`)**: Integrate `local_notifier` to send native macOS notification alerts when a task reaches its due date.
- **Subtasks & Checklists (`TSK-004`)**: Allow nesting smaller checklist items within a parent task.
- **Kanban / Status Column Toggle (`TSK-005`)**: Toggle between standard List view and a 3-column Kanban board (`To Do`, `In Progress`, `Done`).

### What Should Be Removed or Simplified
- Consolidate task sorting and priority dropdowns into a single clean filter bar.

### Missing Interactions & Micro Details
- Drag-and-drop task reordering within lists.
- Striking through completed tasks with a subtle opacity fade.

### Verification & Testing Suite
- **Test**: Toggling task completion updates SQLite status and triggers UI animation.
- **Test**: Filtering by priority and status displays the correct subset of items.

---

## 6. Documents & Knowledge View (`lib/views/documents/documents_view.dart`)

### What Should Remain
- Ingested document list showing title, file type, chunk count, and ingestion date.
- File picker button for adding text files.
- Document search bar.
- Individual document delete buttons.

### What Should Change
- **Drag-and-Drop Ingestion Zone (`DOC-006`, `INP-03`)**: Implement `desktop_drop` so users can drag PDFs, Word docs, and text files directly into the window from Finder.
- **Native PDF & DOCX Extraction (`DOC-002`)**: Upgrade parser from plain text to true PDF (`syncfusion_flutter_pdf` or `pdfx`) and markdown extraction.
- **Local Dense Embeddings (`DOC-001`)**: Upgrade `DocumentService` to use Ollama's local embedding models (`nomic-embed-text`) for hybrid dense/sparse semantic retrieval.

### What Should Be Added
- **Chunk Inspector Modal (`DOC-004`)**: Allow users to click a document and inspect the segmented text chunks and vector embeddings.
- **Document Collections & Tags (`DOC-005`)**: Group documents into named folders (e.g., `Engineering Specs`, `Client Notes`, `Research Papers`).
- **Interactive Chat Citations (`DOC-003`)**: When RAG references a document in Chat, display clickable citation badges that highlight the referenced source chunk.

### What Should Be Removed or Simplified
- Remove redundant technical database ID columns from user-facing document tables.

### Missing Interactions & Micro Details
- Context menu: View Chunks, Re-Index, Reveal in Finder (`DOC-004`, `MACU-04`).
- Progress indicator during multi-page document chunking (`DOC-007`).

### Verification & Testing Suite
- **Test**: Drag-and-drop of `.pdf` extracts text, generates chunks, and saves to SQLite.
- **Test**: Semantic search query matches chunks based on conceptual similarity.

---

## 7. Settings View (`lib/views/settings/settings_view.dart`)

### What Should Remain
- Ollama connection host configuration (`http://127.0.0.1:11434`).
- Default model selection dropdown.
- Temperature and top_p sampling sliders.
- Theme mode selector (Dark, Light, System).
- Diagnostics card and Ollama health probe.

### What Should Change
- **Custom System Instructions Persona Editor (`SET-001`)**: Add a dedicated textarea for custom system prompts (e.g., *"You are a senior macOS engineer who writes concise, idiomatic code"*).
- **Context Window Length (`num_ctx`) Slider (`SET-006`)**: Allow configuring Ollama's context window (e.g., 2048, 4096, 8192, 16384, 32768 tokens) to optimize RAM usage.

### What Should Be Added
- **Full Database Backup & Restore (`SET-002`)**: Add "Export All Data (ZIP)" and "Restore from Backup" buttons to backup SQLite databases, documents, and settings.
- **Database Size Inspector & Vacuum (`SET-003`)**: Display SQLite database file size in MB with a 1-click "Optimize Database (VACUUM)" button.
- **Launch at macOS Login (`SET-004`)**: Toggle to register Ollivo as a macOS Login Item via LaunchAgent or native runner script.
- **Reveal Database in Finder (`MACU-04`)**: Button to open the Application Support database folder directly in macOS Finder.

### What Should Be Removed or Simplified
- Streamline redundant raw debug output; move technical logs into a dedicated collapsible "Diagnostics & Logs" disclosure group.

### Missing Interactions & Micro Details
- Unsaved changes indicator and warning if navigating away with modified settings (`FDBK-01`).
- Port validation on custom Ollama host input (`http://127.0.0.1:[port]`).

### Verification & Testing Suite
- **Test**: Modifying temperature and persona persists to `SettingsService` and propagates to `AIService` prompt calls.
- **Test**: Database export generates valid ZIP; restore successfully repopulates all tables.
