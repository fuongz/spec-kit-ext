# sqlite-sync

A speckit extension that maintains a shared SQLite database of all team features. Every time someone runs a speckit command, the shared file is updated automatically. Anyone can pull the latest state at any time.

## What it does

- **`/speckit.sqlite-sync.init`** — Bootstrap: sync from a shared SQLite file, creating it if it doesn't exist. Pulls existing team features and pushes any local features not yet in the shared file.
- **`/speckit.sqlite-sync.sync`** — Manual sync: pull the latest team state at any time without running a speckit command.
- **Auto-update hooks** — After `/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, and `/speckit.implement`, the current feature's status is automatically pushed to the shared database.

## Prerequisites

- **speckit** ≥ 0.3.2
- **sqlite3** CLI in PATH — verify with `sqlite3 --version`
  - macOS: pre-installed
  - Ubuntu/Debian: `apt install sqlite3`
  - Windows: download from [sqlite.org](https://sqlite.org/download.html)
- A **shared file path** accessible to all team members (network drive, Dropbox/Google Drive folder, or git LFS path)

## Installation

### From this repository

```bash
cp -r extensions/sqlite-sync ~/.speckit/extensions/
```

### Via speckit (when published)

```bash
speckit extension install sqlite-sync
```

## Configuration

Add to your project's `.specify/extensions.yml`:

```yaml
extensions:
  sqlite-sync:
    # Required: path to the shared SQLite file accessible by all team members
    shared_db_path: /path/to/shared/speckit-team.db

    # Optional: set to false to disable auto-update hooks (manual sync only)
    auto_update: true

    # Optional: conflict resolution strategy (only last_write_wins supported in v0.1.0)
    conflict_strategy: last_write_wins
```

A full config template is available at `config/sqlite-sync.template.yml`.

## Usage

### First-time setup (run once per team member)

```
/speckit.sqlite-sync.init
```

This creates the database if it doesn't exist, pulls existing features, and pushes any local features. Output example:

```
Team features in shared database (3 records):
  001 | git-commit | 001-git-commit | done | 2026-03-22T10:00:00Z
  002 | sqlite-shared-sync | 002-sqlite-shared-sync | planning | 2026-03-23T09:00:00Z
  003 | another-feature | 003-another-feature | draft | 2026-03-23T11:00:00Z

Synced: 3 pulled, 0 pushed. No conflicts.
```

### Auto-update (happens automatically)

After running any speckit lifecycle command, the shared database updates automatically:

| Command | Status set in shared DB |
|---------|------------------------|
| `/speckit.specify` | `draft` |
| `/speckit.plan` | `planning` |
| `/speckit.tasks` | `tasks` |
| `/speckit.implement` | `implementing` |

### Manual sync (pull latest)

```
/speckit.sqlite-sync.sync
```

Run at any time to pull the latest state from the shared database. If nothing has changed since your last sync:

```
Already up to date.
```

## Querying the shared database

Use the `sqlite3` CLI to query feature status directly:

```bash
# List all features and statuses
sqlite3 /path/to/speckit-team.db \
  "SELECT feature_number, short_name, status, updated_at FROM features ORDER BY feature_number;"

# Show only in-progress features
sqlite3 /path/to/speckit-team.db \
  "SELECT branch_name, status FROM features WHERE status NOT IN ('draft', 'done');"

# View recent sync history
sqlite3 /path/to/speckit-team.db \
  "SELECT timestamp, direction, records_affected, outcome FROM sync_log ORDER BY timestamp DESC LIMIT 20;"
```

## Disabling auto-update

To turn off automatic hook updates and rely on manual sync only:

```yaml
extensions:
  sqlite-sync:
    shared_db_path: /path/to/speckit-team.db
    auto_update: false
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `sqlite-sync: shared_db_path not configured` | Add `shared_db_path` to `.specify/extensions.yml` |
| `sqlite3 not found in PATH` | Install sqlite3 (see Prerequisites above) |
| `Shared database is locked` | Another write is in progress; wait a moment and retry |
| `Cannot write to shared_db_path` | Verify the path's parent directory exists and you have write permissions |
| `shared database not found. Run /speckit.sqlite-sync.init first` | Run `/speckit.sqlite-sync.init` to bootstrap the shared database |
| No active feature detected | Run the command from a feature branch (named `NNN-*`) |

## Data model

The shared SQLite file contains two tables:

**`features`** — one row per speckit feature

| Column | Description |
|--------|-------------|
| `feature_number` | Zero-padded number, e.g. `"002"` |
| `short_name` | Slug from branch name |
| `branch_name` | Full branch name |
| `status` | `draft` / `planning` / `tasks` / `implementing` / `done` |
| `spec_file_path` | Relative path to spec.md |
| `created_at` / `updated_at` | ISO 8601 UTC timestamps |

**`sync_log`** — audit trail of all sync operations

| Column | Description |
|--------|-------------|
| `direction` | `push` or `pull` |
| `records_affected` | Number of rows written or read |
| `outcome` | `success`, `conflict`, or `error` |
| `notes` | Human-readable detail |

## Compatibility

- speckit ≥ 0.3.2
- macOS, Linux, Windows (wherever sqlite3 and speckit are installed)

## License

MIT
