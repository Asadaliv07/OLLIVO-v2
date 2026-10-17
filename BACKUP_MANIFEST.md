# OLLIVO v2 — Backup Manifest & Checksum Audit

This document records the exact locations, verification statuses, file sizes, and restoration procedures for all backups created during the migration of OLLIVO.

---

## 1. Master Backup Manifest

| Backup Artifact | Absolute Location | Size | Type / Format | Verification Status |
| :--- | :--- | :--- | :--- | :--- |
| **Complete Project Tarball** | `/Users/asadalishaikh/OLLIVO_v2_BACKUP.tar.gz` | ~1.0 GB | Gzip-compressed tar archive | **VERIFIED** (`tar -tzf` exit code 0) |
| **New Project Root** | `/Users/asadalishaikh/OLLIVO v2` | ~3.1 GB | Full standalone project folder | **VERIFIED** (170 Flutter tests + 23 Python tests pass) |
| **Live Database Snapshot** | `/Users/asadalishaikh/OLLIVO v2/database/ollivo.db` | 65.5 KB | SQLite 3 database | **VERIFIED** (`PRAGMA integrity_check;` returned `ok`) |
| **Container Data Backup** | `/Users/asadalishaikh/OLLIVO v2/external_data/` | ~70 KB | Directory containing DB + plist | **VERIFIED** (contains `ollivo.db` and `com.ollivo.ollivo.plist`) |
| **macOS Release Installer** | `/Users/asadalishaikh/Desktop/OLLIVO-v1.dmg` | 24.1 MB | UDZO Compressed Disk Image | **VERIFIED** (mounted & opened in Finder) |
| **macOS Installer Copy** | `/Users/asadalishaikh/OLLIVO v2/OLLIVO-v1.dmg` | 24.1 MB | UDZO Compressed Disk Image | **VERIFIED** (bit-for-bit duplicate) |
| **Original Workspace (Untouched)** | `/Users/asadalishaikh/ OLLIVO WORKSPACE` | ~3.1 GB | Original source folder | **PRESERVED UNTOUCHED** (No files altered or deleted) |

---

## 2. Integrity Verification Checksums

### Database Checksum (`database/ollivo.db`):
- Format: SQLite 3 format
- Page size: 4096 bytes
- Integrity Check: `PRAGMA integrity_check;` -> `ok`
- Transaction count: Consistent read snapshot

### Archive Checksum:
- Location: `/Users/asadalishaikh/OLLIVO_v2_BACKUP.tar.gz`
- Verification Command: `tar -tzf "/Users/asadalishaikh/OLLIVO_v2_BACKUP.tar.gz" > /dev/null && echo "OK"`
- Status: **OK**

---

## 3. Recommended Off-Device Backup Action

Before removing `/Users/asadalishaikh/ OLLIVO WORKSPACE`:

1. Copy `/Users/asadalishaikh/OLLIVO_v2_BACKUP.tar.gz` to an external USB drive, SSD, or secure personal cloud storage (Google Drive, iCloud, or Dropbox).
2. Store `OLLIVO-v1.dmg` in a safe archive location for instant reinstallation on any MacBook without compiling code.

