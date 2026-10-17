# OLLIVO v2 — 100% Local-First macOS Desktop AI Workspace

OLLIVO v2 is a native macOS desktop AI assistant engineered for total data privacy, on-device intelligence, multi-backend local inference, and sequential layer-streaming of massive 70B+ parameter models on Apple Silicon.

This project is a completely self-contained, independent, and verified workspace migrated from OLLIVO v1.

---

## 🚀 Quick Execution Guide

### Option 1: Launch the Pre-compiled Release App Immediately
You do not need to compile anything to use OLLIVO. The native release application is already compiled and ready:
```bash
open "/Users/asadalishaikh/OLLIVO v2/build/macos/Build/Products/Release/OLLIVO v1.app"
```
Or install it permanently to your MacBook Applications folder using the included drag-and-drop installer:
```bash
open "/Users/asadalishaikh/OLLIVO v2/OLLIVO-v1.dmg"
```

### Option 2: Run in Development / Flutter Mode
```bash
cd "/Users/asadalishaikh/OLLIVO v2"
flutter pub get
flutter run -d macos
```

### Option 3: Run the AirLLM 70B+ Microservice Independently
The Python 3.11 virtual environment is fully pre-configured:
```bash
cd "/Users/asadalishaikh/OLLIVO v2"
PYTHONPATH="/Users/asadalishaikh/OLLIVO v2" airllm_service/.venv/bin/uvicorn airllm_service.api:app --host 127.0.0.1 --port 8008 --reload
```

---

## 🧪 Automated Testing & Verification

All automated tests have been executed and verified in this directory:

```bash
# Run Flutter automated test suite (170 tests passing)
flutter test

# Run Flutter static analysis (0 issues found)
flutter analyze

# Run Python AirLLM microservice test suite (23 tests passing)
cd airllm_service
PYTHONPATH="/Users/asadalishaikh/OLLIVO v2" .venv/bin/pytest tests/
```

---

## 📚 Essential Project Documentation

For complete reference on every aspect of this project, consult the dedicated documentation files:

| Document | Description |
| :--- | :--- |
| **[APP_PATHS.md](APP_PATHS.md)** | Exact absolute file paths, entry points, and verified execution commands |
| **[PROJECT_INVENTORY.md](PROJECT_INVENTORY.md)** | Exhaustive inventory of all folders, source modules, and configurations |
| **[DEPENDENCIES.md](DEPENDENCIES.md)** | System requirements, package manifests, and local backend services |
| **[MIGRATION_REPORT.md](MIGRATION_REPORT.md)** | Complete report on files preserved, path adjustments, and verification |
| **[CLEANUP_REPORT.md](CLEANUP_REPORT.md)** | Guidance on what can be safely removed before deleting the old workspace |
| **[RECOVERY_GUIDE.md](RECOVERY_GUIDE.md)** | Step-by-step restoration procedures for databases, venvs, and full backups |
| **[ENVIRONMENT_SETUP.md](ENVIRONMENT_SETUP.md)** | Configuration settings, `.env` templates, and secret handling |
| **[VERIFICATION_REPORT.md](VERIFICATION_REPORT.md)** | Evidence-based audit log of test results, builds, and integrity checks |
| **[BACKUP_MANIFEST.md](BACKUP_MANIFEST.md)** | Master list of all project backups, disk images, and tarball archives |

---

## 🔒 Data Sovereignty & SQLite Database

OLLIVO stores all chat conversations, messages, personal memories, and document embeddings locally on your SSD using SQLite. A verified snapshot of your active chat database is preserved at:
- `database/ollivo.db`
- `external_data/ollivo.db`

---

## 📦 Full Standalone Backup Archive

A 1.0 GB compressed tarball archive containing this entire project and its dependencies is saved at:
`/Users/asadalishaikh/OLLIVO_v2_BACKUP.tar.gz`

---

## License

Proprietary and Confidential. Copyright © 2026 OLLIVO. All rights reserved.
