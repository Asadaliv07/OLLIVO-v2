# OLLIVO v2 — Disaster Recovery & Restoration Guide

This guide describes how to completely restore the **OLLIVO** application and its local data in case of hardware failure, accidental deletion, corrupted dependencies, or broken build environments.

---

## 1. Fast Full Restoration from Standalone Archive

A bit-for-bit compressed archive of the entire project is preserved at:
`/Users/asadalishaikh/OLLIVO_v2_BACKUP.tar.gz` (Size: ~1.0 GB)

### Restoration Steps:
```bash
# 1. Navigate to your user home directory (or target folder)
cd /Users/asadalishaikh

# 2. Extract the archive
tar -xzf OLLIVO_v2_BACKUP.tar.gz

# 3. Verify directory contents
ls -la "/Users/asadalishaikh/OLLIVO v2"
```

The extracted project will immediately contain the complete source code, documentation, test suites, virtual environment, and database snapshots.

---

## 2. Restoring the SQLite User Database

If your live chat history, memories, or settings in the macOS desktop app ever become corrupted or lost:

### Backup Locations in OLLIVO v2:
- Primary snapshot: `/Users/asadalishaikh/OLLIVO v2/database/ollivo.db`
- Container backup: `/Users/asadalishaikh/OLLIVO v2/external_data/ollivo.db`
- Preferences plist: `/Users/asadalishaikh/OLLIVO v2/external_data/com.ollivo.ollivo.plist`

### Restoration Steps:
```bash
# 1. Quit Ollivo desktop app if currently running
killall "OLLIVO v1" 2>/dev/null || true

# 2. Ensure the sandbox documents directory exists
mkdir -p "$HOME/Library/Containers/com.ollivo.ollivo/Data/Documents"
mkdir -p "$HOME/Library/Containers/com.ollivo.ollivo/Data/Library/Preferences"

# 3. Restore the database file
cp "/Users/asadalishaikh/OLLIVO v2/database/ollivo.db" "$HOME/Library/Containers/com.ollivo.ollivo/Data/Documents/ollivo.db"

# 4. Restore the user preferences plist
cp "/Users/asadalishaikh/OLLIVO v2/external_data/com.ollivo.ollivo.plist" "$HOME/Library/Containers/com.ollivo.ollivo/Data/Library/Preferences/com.ollivo.ollivo.plist"

# 5. Verify database integrity
sqlite3 "$HOME/Library/Containers/com.ollivo.ollivo/Data/Documents/ollivo.db" "PRAGMA integrity_check;"
```

---

## 3. Rebuilding the Python AirLLM Virtual Environment from Scratch

If `airllm_service/.venv` is deleted or corrupted:

```bash
cd "/Users/asadalishaikh/OLLIVO v2/airllm_service"

# 1. Remove corrupted venv
rm -rf .venv

# 2. Create fresh virtual environment using Python 3.11
python3.11 -m venv .venv

# 3. Activate and upgrade pip
source .venv/bin/activate
pip install --upgrade pip

# 4. Install all locked dependencies
pip install -r requirements.txt

# 5. Verify with automated tests
PYTHONPATH="/Users/asadalishaikh/OLLIVO v2" pytest tests/
```

---

## 4. Rebuilding the Flutter Application & Native Assets

If the Flutter build directory or cache becomes corrupted:

```bash
cd "/Users/asadalishaikh/OLLIVO v2"

# 1. Clean previous build artifacts
flutter clean

# 2. Fetch dependencies
flutter pub get

# 3. Run static analysis
flutter analyze

# 4. Run automated test suite
flutter test

# 5. Compile release build
flutter build macos --release
```

---

## 5. Reinstalling from the Drag-and-Drop Disk Image

If the compiled application is deleted from `/Applications`:

```bash
# Open the pre-built installer DMG
open "/Users/asadalishaikh/OLLIVO v2/OLLIVO-v1.dmg"

# Drag OLLIVO v1 into the Applications folder
```

