# OLLIVO — FINAL IMPLEMENTATION MASTER PLAN
## Controlled Phase-by-Phase Desktop Engineering Plan

---

### Executive Summary

**Ollivo** is a 100% local-first, private macOS AI desktop application built with Flutter & Dart, integrating directly with local Ollama instances (`http://127.0.0.1:11434`), SQLite FFI, and macOS platform features.

This document establishes the official engineering plan following the Controlled Implementation guidelines. Each phase must be independently developed, rigorously tested, verified against the macOS runtime, and approved before the next phase commences.

---

### Phase Roadmap Overview & Feature IDs

| Phase | Title | Primary Focus | Feature IDs | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Phase 1** | **Foundation, Safety & Resilience** | Ollama daemon recovery, chat auto-scroll pin/unpin, safe backup/restore, native macOS menu bar, keyboard navigation. | `MOD-002`, `CORE-008`, `SET-002`, `MAC-003`, `UI-004` | **COMPLETED & VERIFIED** |
| **Phase 3** | **Desktop Power & Model Management** | Multi-model pulling/deletion, system resource monitor, global quick-prompt shortcut, window polish. | `MAC-001`, `MAC-002`, `MAC-004`, `MOD-001`, `MOD-003`, `MOD-005` | **COMPLETED & VERIFIED** |
| **Phase 4** | **Local RAG, Documents & Task Automation** | PDF/MD drag-and-drop parsing, semantic chunking, keyword + vector search, AI task creation. | `DOC-001`, `DOC-002`, `DOC-003`, `TSK-001`, `TSK-002`, `TSK-003` | **COMPLETED & VERIFIED** |
| **Phase 5** | **Long-Term Memory & Data Management** | Vector similarity memory search, semantic deduplication, persona presets library, prompt templates, database vacuum. | `MEM-001`, `MEM-002`, `MEM-003`, `PRM-001`, `PRM-002`, `SET-003` | **COMPLETED & VERIFIED** |
| **Phase 6** | **Privacy Hardening, Polish & Release** | Audit logs, offline badge verification, air-gapped security seal, keyboard cheat sheet, build verification. | `SEC-001`, `SEC-002`, `UI-001`, `UI-002` | **COMPLETED & VERIFIED** |

---

### Precise Scope of Phase 1: Foundation, Safety & Resilience

Phase 1 establishes the rock-solid desktop foundation that guarantees stability, data safety, and authentic macOS desktop ergonomics before new functionality is introduced.

#### 1. MOD-002 — One-Click Ollama Daemon Launcher & Health Recovery
- **Component**: `lib/services/process_service.dart`, integrated with `lib/services/ai_service.dart` and `lib/controllers/model_controller.dart`.
- **Requirements**:
  - Differentiate clearly between:
    1. *Daemon offline / port unreachable* (HTTP Connection Refused).
    2. *Host configuration invalid* (Malformed URI / non-local port).
    3. *Daemon running but model missing* (HTTP 404 Model Not Found).
    4. *Inference / generation timeout* (HTTP 500 / Socket timeout).
  - Check whether `127.0.0.1:11434` or custom port is responding prior to attempting process execution.
  - If unreachable, discover system `ollama` executable (`/usr/local/bin/ollama`, `/opt/homebrew/bin/ollama`, or user `$PATH`).
  - Launch `ollama serve` via argument-safe `Process.start` without shell interpolation.
  - Polling with exponential backoff (up to 5s) to confirm health before declaring online.
  - Guard against duplicate spawn loops if process is already running or launching.
  - Actionable fallback if executable is not installed (direct link to install Ollama with instructions).

#### 2. CORE-008 — Chat Auto-Scroll Pin / Unpin & Floating Return Button
- **Component**: `lib/views/chat/chat_view.dart`.
- **Requirements**:
  - Automatically follow streaming tokens when the user is within 40px of bottom extent (`isPinnedToBottom == true`).
  - If user scrolls up (>40px from bottom extent) while AI is streaming or idle, immediately unpin auto-scroll so user can read without being jerked down.
  - Display a floating "Scroll to bottom ↓" button with smooth fade/slide animation when unpinned.
  - Clicking "Scroll to bottom ↓" smoothly scrolls to bottom and re-pins auto-scrolling.
  - Safe disposal of listeners; prevent calling `jumpTo`/`animateTo` on unattached or disposed scroll controllers.

#### 3. SET-002 — Safe Backup & Restore Service
- **Component**: `lib/services/backup_service.dart` and `lib/views/settings/settings_view.dart`.
- **Requirements**:
  - Define complete Ollivo dataset:
    - Tables: `conversations`, `messages`, `memories`, `documents`, `tasks`.
    - Key preferences: Active model, theme, temperature, custom storage directories.
  - Create consistent snapshot:
    - Query active SQLite tables into structured JSON with metadata manifest (schema version, record counts, timestamp, app version).
    - Package into a compressed archive (`.ollivobackup` gzip format) with SHA-256 integrity checksum.
  - Atomic restoration with backup protection:
    - Inspect and validate archive format, manifest, and checksum *before* touching live data.
    - Create a temporary pre-restore snapshot of current database.
    - If restoration succeeds, commit transaction.
    - If restoration fails at any point, rollback cleanly to previous snapshot without data loss.
  - Clear user confirmation dialog explicitly listing what will be restored.
  - No false claims of encryption: Documented transparently as authenticated gzip JSON archive.

#### 4. MAC-003 — Native macOS Application Menus & Essential Shortcuts
- **Component**: `lib/main.dart` (`PlatformMenuBar`).
- **Requirements**:
  - Standard macOS menu tree:
    - **Ollivo** (About, Settings `⌘,`, Hide `⌘H`, Hide Others `⌥⌘H`, Quit `⌘Q`).
    - **File** (New Chat `⌘N`, Backup Data, Restore Data, Close Window `⌘W`).
    - **Edit** (Undo `⌘Z`, Redo `⇧⌘Z`, Cut `⌘X`, Copy `⌘C`, Paste `⌘V`, Select All `⌘A`).
    - **View** (Toggle Sidebar `⌘\`, View Chat `⌘1`, View Memories `⌘2`, View Documents `⌘3`, View Tasks `⌘4`, View Models `⌘5`, View Settings `⌘6`).
    - **Window** (Minimize `⌘M`, Zoom).
    - **Help** (Ollivo Documentation, Report Issue).
  - All menu actions wire directly to actual controller actions (e.g., `New Chat` invokes `chatController.createNewConversation()`, `Settings` selects settings tab).

#### 5. UI-004 — Reliable Keyboard Navigation & Desktop Focus Ergonomics
- **Component**: `lib/main.dart`, `lib/views/chat/chat_view.dart`, `lib/components/ollivo_components.dart`.
- **Requirements**:
  - Chat input behavior:
    - `Enter`: Submit prompt (when text is present and not generating).
    - `Shift + Enter`: Insert newline.
  - Global navigation shortcuts:
    - `⌘1` through `⌘6` switch navigation tabs.
    - `⌘\` toggles sidebar visibility.
  - Focus indicators:
    - Visible focus border (`OllivoTheme.oliveEmerald` with 2px width) on interactive controls during keyboard navigation.
  - Dialog dismiss:
    - `Escape` closes active dialogs without submitting.

---

### Technical Dependencies & Justification

| Dependency | Proposed Version | Justification |
| :--- | :--- | :--- |
| `dart:io` | Standard Library | Argument-safe process spawning (`Process.start`, `Process.run`), GZip compression (`GZipCodec`), file manipulation. Zero external risk. |
| `dart:convert` | Standard Library | JSON encoding, decoding, UTF-8 transcoding. Zero external risk. |
| `crypto` (or `dart:io` sha) | Standard Library / Builtin | Calculate SHA-256 checksums for backup integrity. |
| `flutter/services.dart` | SDK | `PlatformMenuBar`, `PlatformMenuItem`, `LogicalKeyboardKey`, `Shortcuts`, `Actions`. Official native macOS Flutter integration. |

**No third-party packages need to be added to `pubspec.yaml` for Phase 1.**

---

### Database Migration Requirements

- Phase 1 maintains full backward compatibility with the existing SQLite schema (v1).
- Existing tables (`conversations`, `messages`, `memories`, `documents`, `tasks`) remain unchanged.
- No schema upgrades are required for Phase 1 features.

---

### macOS-Native Integration Requirements

1. **Sandboxing & Entitlements**:
   - `com.apple.security.network.client` is enabled (verified in `BUG-01`).
   - If launching `ollama` CLI as a child process from inside the app sandbox encounters sandbox barriers, the process service gracefully falls back to displaying clear, one-click terminal commands and clipboard helpers.
2. **Native Menu Bar**:
   - Utilizes `PlatformMenuBar` which macOS renders in the system menu bar at the top of the physical display, not inside the Flutter window canvas.
3. **Window Resizing & Geometry**:
   - Maintains desktop window min size of 960x600 with clean flex behavior and no render overflow.

---

### Testing & Acceptance Criteria

1. **Static Analysis**: `flutter analyze` must return 0 errors, 0 warnings.
2. **Automated Tests**:
   - Daemon recovery unit & process tests (`test/process_service_test.dart`).
   - Backup & restore validation and rollback tests (`test/backup_service_test.dart`).
   - Chat auto-scroll pin/unpin widget test (`test/chat_view_test.dart`).
   - Full regression suite (`test/backend_test.dart`, `test/ai_workflow_test.dart`, `test/new_features_test.dart`, `test/widget_test.dart`) must pass 100%.
3. **macOS Build Validation**:
   - `flutter build macos` must succeed with exit code 0.
4. **Runtime Acceptance**:
   - One-click launch / recovery attempts connection and updates UI banner.
   - User scrolling up during generation does not snap back to bottom.
   - Floating scroll-to-bottom button smoothly scrolls to bottom.
   - Backup produces valid `.ollivobackup` file; restore cleanly repopulates data.
   - macOS Menu Bar displays native menus and keyboard shortcuts respond instantly.

---

### Risk Management & Rollback Strategy

| Identified Risk | Likelihood | Impact | Mitigation / Rollback |
| :--- | :--- | :--- | :--- |
| macOS sandbox blocks `Process.start("ollama")` | Medium | Low | Detect exit error code / permission fault; display one-click copyable terminal command fallback (`ollama serve`). App never crashes. |
| User restores corrupted or incompatible backup | Low | High | Pre-restore validation checks JSON schema and SHA-256; current database is snapshotted before restore and restored if any error occurs. |
| Rapid token streaming causes scroll jitter | Low | Medium | Throttle scroll offset checks; use `jumpTo` only when pinned and let Physics handle user gesture interruptions. |

---

### Implementation Progress Tracking

- [x] **Phase 1: Foundation, Stability & macOS Desktop Essentials** (Completed & Verified)
- [x] **Phase 2: Conversation Polish & Visual Excellence** (Completed & Verified)
- [x] **Phase 3: Model Management & Desktop Power Tools** (Completed & Verified)
- [x] **Phase 4: Local RAG, Documents & Task Automation** (Completed & Verified — 47/47 Tests Passing)
  - `DOC-001`: Vector embeddings + dense Cosine similarity hybrid retrieval
  - `DOC-002`: Native PDF text extraction (FlateDecode/zlib) & sliding-window chunking
  - `DOC-003`: Interactive Source Citation cards & excerpt inspector modal in chat
  - `TSK-001`: Natural language action item parser with priority detection & 1-click batch create
  - `TSK-002`: Desktop due-date calendar scheduling with dynamic relative labels & overdue badges
  - `TSK-003`: 3-state task lifecycle (`todo` -> `in_progress` -> `completed`), status filters, & Ask Ollivo planner
- [x] **Phase 5: Knowledge, Prompts & Power Features** (Completed & Verified — 53/53 Tests Passing)
  - `MEM-001`: Explicit fact memory center with category taxonomy & filtering
  - `MEM-002`: Inline memory editing, correction, and deletion modals
  - `MEM-003`: Automatic deduplication & conflict resolution on memory save
  - `PRM-001`: Pre-built persona presets library (Architect, Writer, Brainstormer, Minimalist, Balanced)
  - `PRM-002`: Custom prompt template manager with dynamic slot variables & interpolation
  - `SET-003`: Database storage inspector & VACUUM maintenance tool
- [x] **Phase 6: Privacy Hardening, Polish & Desktop Release** (Completed & Verified — 58/58 Tests Passing, macOS Binary Built)
  - `SEC-001`: Local Privacy & Security Audit Log engine with JSON/CSV export and zero telemetry verification
  - `SEC-002`: Offline Mode & Air-Gapped Privacy Seal certificate modal and status pill
  - `UI-001`: Keyboard Shortcuts Cheat Sheet modal with live search filtering (`⌘/`)
  - `UI-002`: Settings View Audit Log inspection & maintenance card in Advanced tab
  - `MAC-BUILD`: Verified macOS desktop debug binary compilation (`ollivo.app`)

