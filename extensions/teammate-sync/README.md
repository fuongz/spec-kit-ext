# teammate-sync

Sync your speckit project state with teammates using portable YAML snapshots — no server, no daemon, no real-time connection required.

Export your `specs/` directory into a single file, share it via any method, and teammates can import it with interactive conflict resolution.

---

## Install

```bash
specify extension add teammate-sync
```

---

## Commands

| Command | Description |
|---------|-------------|
| `/speckit.teammate-sync.export` | Export `specs/` to a YAML snapshot file |
| `/speckit.teammate-sync.import [path]` | Import a teammate's snapshot |
| `/speckit.teammate-sync.diff [path]` | Preview changes before importing |

---

## Zero-Config Usage

No setup needed. Snapshots go to `.specify/sync/` by default.

```
# 1. Export your state
/speckit.teammate-sync.export
# → .specify/sync/alice-20260324T103000Z.sync.yml

# 2. Send the file to your teammate (Slack, email, AirDrop, etc.)

# 3. Preview their snapshot before importing
/speckit.teammate-sync.diff /path/to/bob-20260324T113000Z.sync.yml

# 4. Import their snapshot
/speckit.teammate-sync.import /path/to/bob-20260324T113000Z.sync.yml
```

---

## Shared Folder Setup

For teams using Dropbox, Google Drive, a network drive, or any synced folder — configure once and drop all file path arguments.

**1. Copy the config template:**

```bash
cp .specify/extensions/teammate-sync/teammate-sync.template.yml \
   .specify/extensions/teammate-sync/teammate-sync-config.yml
```

**2. Edit the config:**

```yaml
extensions:
  teammate-sync:
    shared_sync_folder: /Users/shared/team-speckit-sync  # ← your shared path
    auto_export: false
```

**3. Export — writes to shared folder automatically:**

```
/speckit.teammate-sync.export
```

**4. Teammate imports — picks up the most recent snapshot automatically:**

```
/speckit.teammate-sync.import
```

---

## Handling Conflicts

When both you and a teammate have modified the same file, the import pauses:

```
Conflict (1/2): specs/002-feature/spec.md
  Local modified:    2026-03-24T09:00:00Z
  Teammate modified: 2026-03-24T10:30:00Z (by Alice)

[L]ocal     Keep your version
[T]eammate  Accept Alice's version
[S]kip      Leave unchanged for now
Choice: _
```

Enter `L`, `T`, or `S` for each conflict. The import completes only after all conflicts are resolved. If aborted mid-way, no files are changed (atomic write protection).

---

## Auto-Export After Implementation

Set `auto_export: true` in your config to automatically export a snapshot after every `/speckit.implement` session. Teammates can then import your latest state without waiting for a manual export.

---

## Requirements

- speckit `>=0.3.2`
- `git >=2.0` (optional — used for author identity; falls back to system hostname)

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `shared_sync_folder not found or not writable` | `mkdir -p /your/shared/path` |
| `no snapshot found in .specify/sync/` | Export first, or pass the snapshot path explicitly |
| `schema version not supported` | `specify extension update teammate-sync` |
| Import aborted, no files changed | Safe — retry the import; local state is intact |
| Snapshot file is very large | Normal for projects with many files; YAML is human-readable so you can inspect it |

---

## How It Works

- **Snapshots** are YAML files containing the full content of every file in `specs/`, plus metadata (schema version, export timestamp, author).
- **Record identity** uses stable UUIDs stored in `.specify/sync/.index.yml` (gitignored, local-only). UUIDs never change even if files are renamed or moved.
- **Conflict detection** compares checksums: if both you and a teammate changed the same file since the last sync, it's a conflict.
- **Atomic imports** use a write-then-rename pattern — a crash or interruption during import leaves all local files unchanged.

---

## License

MIT
