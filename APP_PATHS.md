# OLLIVO v2 — Application Paths & Execution Reference

This document provides exact absolute paths and verified commands for running, developing, building, testing, and packaging **OLLIVO v2**.

---

## 1. Primary Absolute Paths

| Purpose | Exact Absolute Path |
| :--- | :--- |
| **Project Root Folder** | `/Users/asadalishaikh/OLLIVO v2` |
| **Flutter Application Entry Point** | `/Users/asadalishaikh/OLLIVO v2/lib/main.dart` |
| **Frontend UI Core / Shell** | `/Users/asadalishaikh/OLLIVO v2/lib/components/` & `/Users/asadalishaikh/OLLIVO v2/lib/controllers/` |
| **Backend Daemon Entry Point** | `/Users/asadalishaikh/OLLIVO v2/airllm_service/service.py` |
| **Backend API Route Definitions** | `/Users/asadalishaikh/OLLIVO v2/airllm_service/api.py` |
| **Python Virtual Environment** | `/Users/asadalishaikh/OLLIVO v2/airllm_service/.venv` |
| **Python Binary** | `/Users/asadalishaikh/OLLIVO v2/airllm_service/.venv/bin/python` |
| **Pytest Binary** | `/Users/asadalishaikh/OLLIVO v2/airllm_service/.venv/bin/pytest` |
| **Main Flutter Config** | `/Users/asadalishaikh/OLLIVO v2/pubspec.yaml` |
| **Flutter Lockfile** | `/Users/asadalishaikh/OLLIVO v2/pubspec.lock` |
| **AirLLM Requirements File** | `/Users/asadalishaikh/OLLIVO v2/airllm_service/requirements.txt` |
| **Environment Config Template** | `/Users/asadalishaikh/OLLIVO v2/.env.example` |
| **Docker Compose Config** | `/Users/asadalishaikh/OLLIVO v2/docker-compose.yml` |
| **Database Snapshot Location** | `/Users/asadalishaikh/OLLIVO v2/database/ollivo.db` |
| **Runtime SQLite Database** | `/Users/asadalishaikh/Library/Containers/com.ollivo.ollivo/Data/Documents/ollivo.db` |
| **Preserved External Data** | `/Users/asadalishaikh/OLLIVO v2/external_data/` |
| **Primary Brand Assets** | `/Users/asadalishaikh/OLLIVO v2/assets/` & `/Users/asadalishaikh/OLLIVO v2/OLLIVO LOGO.png` |
| **Packaged Release Application (.app)**| `/Users/asadalishaikh/OLLIVO v2/build/macos/Build/Products/Release/OLLIVO v1.app` |
| **Drag-and-Drop Installer (.dmg)** | `/Users/asadalishaikh/OLLIVO v2/OLLIVO-v1.dmg` |
| **Desktop Installer Copy** | `/Users/asadalishaikh/Desktop/OLLIVO-v1.dmg` |
| **Full Project Backup Archive** | `/Users/asadalishaikh/OLLIVO_v2_BACKUP.tar.gz` |
| **Primary Documentation** | `/Users/asadalishaikh/OLLIVO v2/README.md` |

---

## 2. Verified Command Reference

### A. Dependency Installation

**Flutter / Dart:**
```bash
cd "/Users/asadalishaikh/OLLIVO v2"
flutter pub get
```

**Python AirLLM Service (Already installed in `.venv`):**
```bash
cd "/Users/asadalishaikh/OLLIVO v2/airllm_service"
source .venv/bin/activate
pip install -r requirements.txt
```

---

### B. Starting the Application

**Option 1: Launch the Pre-compiled Native Application Directly:**
```bash
open "/Users/asadalishaikh/OLLIVO v2/build/macos/Build/Products/Release/OLLIVO v1.app"
```

**Option 2: Run in Flutter Debug / Hot-Reload Mode:**
```bash
cd "/Users/asadalishaikh/OLLIVO v2"
flutter run -d macos
```

**Option 3: Run the AirLLM Python Daemon Independently:**
```bash
cd "/Users/asadalishaikh/OLLIVO v2"
PYTHONPATH="/Users/asadalishaikh/OLLIVO v2" "/Users/asadalishaikh/OLLIVO v2/airllm_service/.venv/bin/uvicorn" airllm_service.api:app --host 127.0.0.1 --port 8008 --reload
```

---

### C. Running Automated Tests

**Run All Flutter Tests (170 tests):**
```bash
cd "/Users/asadalishaikh/OLLIVO v2"
flutter test
```

**Run Static Analysis:**
```bash
cd "/Users/asadalishaikh/OLLIVO v2"
flutter analyze
```

**Run Python AirLLM Tests (23 tests):**
```bash
cd "/Users/asadalishaikh/OLLIVO v2/airllm_service"
PYTHONPATH="/Users/asadalishaikh/OLLIVO v2" .venv/bin/pytest tests/
```

---

### D. Building & Packaging

**Build Release Application:**
```bash
cd "/Users/asadalishaikh/OLLIVO v2"
flutter build macos --release
```

**Build Drag-and-Drop Disk Image Installer (`.dmg`):**
```bash
rm -rf /tmp/OLLIVO_DMG_Staging
mkdir -p /tmp/OLLIVO_DMG_Staging
cp -R "/Users/asadalishaikh/OLLIVO v2/build/macos/Build/Products/Release/OLLIVO v1.app" "/tmp/OLLIVO_DMG_Staging/OLLIVO v1.app"
ln -s /Applications "/tmp/OLLIVO_DMG_Staging/Applications"
hdiutil create -volname "OLLIVO v1" -srcfolder "/tmp/OLLIVO_DMG_Staging" -ov -format UDZO "/Users/asadalishaikh/Desktop/OLLIVO-v1.dmg"
cp -f "/Users/asadalishaikh/Desktop/OLLIVO-v1.dmg" "/Users/asadalishaikh/OLLIVO v2/OLLIVO-v1.dmg"
rm -rf /tmp/OLLIVO_DMG_Staging
xattr -cr "/Users/asadalishaikh/Desktop/OLLIVO-v1.dmg"
```

