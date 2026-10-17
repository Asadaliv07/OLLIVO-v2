# Ollivo Project Development Guidelines & Coding Rules

> **Applies to:** All Antigravity AI coding agents working on the Ollivo workspace.  
> **Location:** `.agents/rules/ollivo.md`  

---

## 1. Approved Architecture & Tech Stack

* **Framework:** Flutter (Dart 3.13.5+ / Flutter 3.47.7+) for Web, Android, iOS, and macOS.
* **Database & Storage:** Local SQLite (`sqflite`/`sqlite3`) with `sqlite-vec` for 384-dimensional vector embeddings stored in device sandbox.
* **AI Engine:** Local Ollama service (`http://127.0.0.1:11434`) running `qwen2.5-coder:1.5b` or `llama3.2:3b`.
* **Privacy Baseline:** 100% Local-First execution. Zero outbound network requests to external public cloud LLMs or analytics servers.

---

## 2. Code Inspection & Verification Requirements (Mandatory)

1. **Inspect Before Mutating:** ALWAYS inspect existing code files (`view_file`, `grep_search`) before creating, modifying, or deleting code.
2. **Empirical Verification:** NEVER declare a task done without running verification commands (`flutter analyze` and `flutter test`). Report exact test output to the user.
3. **No Unrelated Refactoring:** Do NOT perform unsolicited refactoring, rename established components, or add unapproved features outside the current task scope.

---

## 3. Directory & Code Structure

Organize all application logic under `lib/` as follows:
* `lib/core/`: Constants, environment config (`constants.dart`), and local logging (`logger.dart`).
* `lib/models/`: Immutably structured data models with `fromJson`/`toJson` and SQLite mappers (`chat_message.dart`, `memory_item.dart`, `document_item.dart`, `task_item.dart`).
* `lib/services/`: Isolated business logic services (`ai_service.dart`, `database_service.dart`, `memory_service.dart`, `document_service.dart`, `task_service.dart`).
* `lib/views/`: Screen views organized by domain (`chat/`, `memories/`, `documents/`, `tasks/`, `settings/`).
* `lib/theme.dart`: Design tokens matching brand palette (`#121212` Onyx, `#6B9E78` Emerald).
* `lib/main.dart`: App entry point and tabbed navigation shell.

---

## 4. Coding & Type Safety Conventions

* **Null Safety:** Maintain strict Dart Sound Null Safety (`sdk: ^3.13.5`).
* **Static Analysis:** Zero `flutter analyze` errors or warnings allowed.
* **Design Token Conformance:** Use brand colors (`#121212` Onyx background, `#6B9E78` Emerald primary, `#FFFFFF` text) from `lib/theme.dart`. Never hardcode generic hex colors in view widgets.

---

## 5. Security & Privacy Rules

* **Local Sandbox Isolation:** All data files (`ollivo.db`, `.log`, `.txt`) must remain inside the operating system's application sandbox.
* **Secret Protection:** Never commit API keys, tokens, or credentials. Ensure `.env` files are listed in `.gitignore`.
* **Sensitive Data Filtering:** Sanitize prompt text with regex to prevent password or private key storage into vector memory.

---

## 6. Database & Migration Rules

* **Version Control:** Manage SQLite schema versions via `DatabaseService` (`version: 1`).
* **Non-Destructive Migrations:** Database schema upgrades must use `ALTER TABLE` or guarded `CREATE TABLE IF NOT EXISTS`. Never drop existing user tables in production schema updates.

---

## 7. Accessibility & UI Requirements (WCAG 2.1 AA)

* **Contrast:** Ensure text maintains at least `4.5:1` contrast ratio against dark Onyx (`#121212`) backgrounds.
* **Touch Targets:** Minimum `48x48dp` for mobile touch targets and `36x36px` for desktop click targets.
* **Semantics:** Wrap icon-only buttons with `Semantics(label: ...)` or `Tooltip`.

---

## 8. Testing & Documentation Standards

* **Automated Testing:** Maintain unit tests in `test/` for all models, services, and core utility logic. Run `flutter test` after code changes.
* **Docstrings:** Document all public service methods and models using Dart standard docstrings (`///`).
* **Documentation Maintenance:** Keep `docs/` files (`PRODUCT_BRIEF.md`, `MVP_SCOPE.md`, `UI_UX_SPEC.md`, `ARCHITECTURE.md`) in sync when updating system behavior.
