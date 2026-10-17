# OLLIVO v2 — Pre-Cleanup Audit & Classification Report

**Purpose:** This document evaluates every major folder and file in both the original project and `OLLIVO v2` to guide you in safely deciding what can eventually be cleaned up on your MacBook.

> [!IMPORTANT]
> **NO FILES HAVE BEEN DELETED.** All items listed below remain completely intact in both `/Users/asadalishaikh/ OLLIVO WORKSPACE` and `/Users/asadalishaikh/OLLIVO v2`. Review this guide before manually deleting the old directory.

---

## 1. Classification Categories

- **KEEP:** Required for the application to function, compile, or be maintained.
- **KEEP FOR RECOVERY:** Valuable for disaster recovery, historical audits, or rollback.
- **REGENERATABLE:** Can be deleted if disk space is needed, because it can be recreated using standard commands.
- **REVIEW FIRST:** Contains user-created notes or scratch scripts; review personal importance before removing.
- **EXTERNAL DEPENDENCY:** Located outside the project directory; managed by macOS or other applications.
- **SENSITIVE:** Contains private data, user chats, or preferences; handle securely.

---

## 2. Comprehensive Candidate Inventory

| Path | Purpose | Classification | Risk Assessment & Consequence of Removal |
| :--- | :--- | :--- | :--- |
| `lib/` | Core Flutter source code | **KEEP** | **CRITICAL:** Removing this destroys the desktop app frontend and logic. |
| `airllm_service/*.py` | Backend Python microservice source code | **KEEP** | **CRITICAL:** Removing this destroys the local AirLLM 70B+ inference daemon. |
| `macos/` | macOS native AppKit host and Xcode settings | **KEEP** | **CRITICAL:** Removing this prevents building macOS applications. |
| `assets/` | High-res logos and icon assets | **KEEP** | Removing this breaks app icons and UI branding. |
| `pubspec.yaml` & `pubspec.lock` | Dart dependency manifests | **KEEP** | **CRITICAL:** Required to resolve Flutter dependencies. |
| `airllm_service/requirements.txt`| Python dependency manifest | **KEEP** | **CRITICAL:** Required to install or rebuild AirLLM Python packages. |
| `database/ollivo.db` | User conversation & memory database | **SENSITIVE / KEEP** | Contains real local chats and memories. Backup copy preserved in `OLLIVO v2`. |
| `external_data/` | Sandbox container snapshots | **KEEP FOR RECOVERY** | Contains verified backup of user chats and app preferences plist. |
| `docs/` | Architecture & implementation specs | **KEEP FOR RECOVERY** | Essential for developer onboarding, maintenance, and audit reference. |
| `test/` | Automated test suites (170 tests) | **KEEP** | Required for regression testing and code validation. |
| `build/` (~1.6 GB) | Compiled native macOS binaries | **REGENERATABLE** | Low risk. Can be regenerated anytime via `flutter build macos --release`. |
| `.dart_tool/` (~400 MB) | Flutter package compilation caches | **REGENERATABLE** | Low risk. Can be regenerated anytime via `flutter pub get`. |
| `airllm_service/.venv/` (~1.1 GB)| Python virtual environment | **REGENERATABLE** | Medium risk. Can be regenerated via `python3.11 -m venv .venv && pip install -r requirements.txt`, but takes 5-10 minutes to download wheels. |
| `OLLIVO-v1.dmg` (~24 MB) | Release drag-and-drop installer | **KEEP FOR RECOVERY** | Pre-built installer ready to share or reinstall on any Mac. |
| `Ollivo.dmg` (~24 MB) | Legacy installer disk image | **KEEP FOR RECOVERY** | Previous release installer. Safe to delete if only v1 is desired. |
| `scratch/` | Developer test scripts | **REVIEW FIRST** | Contains temporary smoke test scripts. Non-critical to the main application. |
| `~/Library/Containers/com.ollivo.ollivo` | macOS live app sandbox | **EXTERNAL DEPENDENCY / SENSITIVE** | Managed by macOS AppKit sandbox. Contains your active runtime chat database. |
| `~/.cache/ollivo/airllm` | AirLLM model weight cache | **EXTERNAL DEPENDENCY / REGENERATABLE** | Stores downloaded model weights from Hugging Face. Can be redownloaded. |
| `/Users/asadalishaikh/OLLIVO_v2_BACKUP.tar.gz` | Complete 1.0 GB compressed archive | **KEEP FOR RECOVERY** | Standalone backup. Store on external drive or cloud storage before removing old workspace. |

---

## 3. Recommended Old Workspace Deletion Procedure

Once you have verified that `OLLIVO v2` runs and fulfills all your needs, you can remove `/Users/asadalishaikh/ OLLIVO WORKSPACE` using these recommended steps:

1. **Verify Backup:** Confirm `/Users/asadalishaikh/OLLIVO_v2_BACKUP.tar.gz` exists and is ~1.0 GB.
2. **Close Running Instances:** Quit Ollivo v1 from your dock or menu bar.
3. **Move to Trash (Safe Recovery Window):** Instead of immediate permanent deletion (`rm -rf`), move `/Users/asadalishaikh/ OLLIVO WORKSPACE` to macOS Trash so you have a 30-day grace period to restore if ever desired.
4. **Permanent Removal:** After confirming your satisfaction with `OLLIVO v2`, empty your Trash.

