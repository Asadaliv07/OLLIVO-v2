# Ollivo Technology Stack Evaluation & Approved Desktop Architecture

> **Document Version:** 2.0.0  
> **Status:** Approved Strategy & Technical Architecture  
> **Target Platform:** macOS Desktop Application ONLY  
> **Core Constraint:** 100% Local-First AI, $0 Infrastructure Cost, Native macOS Desktop UX  

---

## 1. Executive Summary & Technology Decision

Following an empirical inspection of the workspace code, passing tests, and macOS desktop product goals, the approved technology stack for **Ollivo** is:

* **Approved Application Framework:** **Flutter (Dart) Native macOS Desktop Target**
* **Preserved Codebase Assets:** Retains 100% of the existing written code (`lib/` - 10 source files, 2,346 lines) and automated test suite (`test/` - 14/14 tests passing).
* **Excluded Targets:** Web, PWA, Android, and iOS targets are excluded from the active product roadmap without altering global developer environment configurations.

---

## 2. Evaluation & Retrospective Comparison Matrix

| Evaluation Criteria | Flutter macOS Desktop (Approved) | Native SwiftUI & Swift | Tauri 2 + React |
| :--- | :--- | :--- | :--- |
| **Code & Test Reuse** | ✅ **100% Code & Test Retention.** All 2,346 lines of Dart code and 14 passing tests preserved immediately. | ❌ **0% Code Reuse.** Requires complete rewrite of 2,346 lines into Swift and XCTest. | ⚠️ **Partial Reuse.** Requires writing Rust-to-JS bridges and web wrappers. |
| **Local-First Privacy** | ✅ **Native Local Sandbox.** Runs 100% on-device inside macOS sandbox (`ollivo.db`). | ✅ **Native Local Sandbox.** Native Apple sandbox. | ⚠️ **Web Window Isolation.** Web sandbox inside WebView. |
| **Operating Cost** | ✅ **$0.00 / Month.** Zero server hosting or API fees. | ✅ **$0.00 / Month.** Zero server hosting or API fees. | ✅ **$0.00 / Month.** Zero server hosting. |
| **Local AI Integration** | ✅ **Direct Ollama REST streaming.** Verified connector to `127.0.0.1:11434`. | ✅ Direct URLSession REST calls. | ⚠️ Complex Rust backend IPC bridge. |
| **Vector Database** | ✅ **SQLite + `sqlite-vec`.** Embedded C-FFI vector search inside SQLite database. | ✅ SQLite / GRDB embedded vector search. | ⚠️ Embedded SQLite / Vector plugin. |
| **macOS Desktop Capabilities** | ✅ Native window controls, AppKit menus, custom hotkeys, Finder drag-and-drop. | ✅ 100% Native AppKit/SwiftUI controls. | ⚠️ WebView scrollbars & web rendering. |

---

## 3. Core Component Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                 OLLIVO MACOS APPLICATION LAYER                  │
│              Flutter Desktop (Dart) - macOS Target              │
└──────┬──────────────────────┬──────────────────────┬────────────┘
       │                      │                      │
       ▼                      ▼                      ▼
┌──────────────┐      ┌──────────────┐      ┌─────────────────┐
│ Local Ollama │      │ Local SQLite │      │ macOS Sandbox   │
│ LLM Engine   │      │ Database     │      │ File Storage    │
│ (127.0.0.1)  │      │ (sqlite-vec) │      │ (App Support)   │
└──────────────┘      └──────────────┘      └─────────────────┘
```

### 3.1 Client Framework & Presentation
* **Framework:** Flutter 3.47+ for macOS desktop ARM64 / x86_64.
* **Language:** Dart 3.7+ with sound null safety.
* **Rendering Engine:** Native macOS desktop hardware-accelerated canvas (Impeller / Metal).
* **Styling Tokens:** Custom Onyx (`#121212`) dark background, Emerald (`#6B9E78`) primary accent, custom card and status components.

### 3.2 Backend, Database, and Vector Memory
* **Local Database:** Embedded SQLite (`sqflite` / `sqlite3`) writing to `~/Library/Application Support/com.ollivo.app/ollivo.db`.
* **Vector Search Engine:** `sqlite-vec` C-FFI native extension providing embedded cosine similarity search over personal memories and indexed files.
* **Memory Management:** `Mem0` pattern (automatic fact extraction and vector indexing).

### 3.3 AI Model Integration
* **Local AI Runtime:** Ollama daemon running on `127.0.0.1:11434` with Apple Silicon Metal acceleration.
* **Models Supported:** `qwen2.5-coder:1.5b`, `llama3.2:3b`.
* **Protocol:** HTTP REST streaming (`ndjson`) emitting tokens word-by-word.

---

## 4. Developer Build Prerequisites

Building native macOS `.app` bundles requires pointing the active developer directory to full Xcode:

```bash
# Developer environment configuration command (Executed manually by developer):
sudo xcode-select -switch /Applications/Xcode.app
```

---

## 5. Technology Stack Summary Table

| Category | Approved Technology |
| :--- | :--- |
| **Target Platform** | macOS Desktop ONLY (macOS 12.0+) |
| **Application Framework** | Flutter Desktop (Dart) |
| **Local Database** | SQLite (`sqflite` / `sqlite3`) |
| **Vector Extension** | `sqlite-vec` (v0.1.9) |
| **AI LLM Daemon** | Ollama (`127.0.0.1:11434`) |
| **Testing Framework** | `flutter_test` (14/14 tests passing) |
| **Operating Cost** | **$0.00 / Month** |

---

## 6. Document Status & Approval

* **Author:** Lead Systems Architect
* **Status:** Approved Strategy & Technical Architecture (Flutter macOS Desktop)
