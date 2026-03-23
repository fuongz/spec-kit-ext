## Step 1 — Read and validate configuration

Read the extension configuration for `sqlite-sync` from the project's `.specify/extensions.yml` file (or equivalent speckit config location). Look for the value at `extensions.sqlite-sync.shared_db_path`.

If `shared_db_path` is missing, empty, or not set, output exactly:

```
sqlite-sync: shared_db_path not configured. See README for setup.
```

Then stop. Do not proceed further.

---

## Step 2 — Verify sqlite3 is available

Run the following command to check that the `sqlite3` CLI is installed and in PATH:

```sh
sqlite3 --version
```

If this command fails (exits with a non-zero code or is not found), output exactly:

```
sqlite3 not found in PATH. Install sqlite3 and retry.
```

Then stop. Do not proceed further.

---

## Step 3 — Create schema in the shared file if it does not exist

Using the path from Step 1 as `$SHARED_DB`, execute the following SQL via the sqlite3 CLI to initialize the schema. Use `CREATE TABLE IF NOT EXISTS` so this is safe to run on an already-initialized database:

```sh
sqlite3 "$SHARED_DB" "
CREATE TABLE IF NOT EXISTS features (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    feature_number  TEXT    NOT NULL UNIQUE,
    short_name      TEXT    NOT NULL,
    branch_name     TEXT    NOT NULL,
    status          TEXT    NOT NULL DEFAULT 'draft',
    spec_file_path  TEXT,
    created_at      TEXT    NOT NULL,
    updated_at      TEXT    NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_features_branch ON features(branch_name);
CREATE INDEX IF NOT EXISTS idx_features_status ON features(status);
CREATE TABLE IF NOT EXISTS sync_log (
    id               INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp        TEXT    NOT NULL,
    direction        TEXT    NOT NULL,
    records_affected INTEGER NOT NULL DEFAULT 0,
    outcome          TEXT    NOT NULL,
    notes            TEXT
);
"
```

If the shared file's parent directory does not exist or is not writable, output exactly:

```
Cannot write to shared_db_path: <path>. Check permissions.
```

(replace `<path>` with the actual value of `$SHARED_DB`) and stop.

---

## Step 4 — Pull existing feature records from the shared file

Query the shared database for all existing feature records:

```sh
sqlite3 -separator " | " "$SHARED_DB" "SELECT feature_number, short_name, branch_name, status, updated_at FROM features ORDER BY feature_number;"
```

Capture the output as the current team state. Count the number of rows returned — this is `PULL_COUNT`.

If the database is new (no rows), `PULL_COUNT` is 0 and the team state is empty.

Display the pulled records to the user in a readable format. If `PULL_COUNT` > 0, print a header line such as:

```
Team features in shared database (PULL_COUNT records):
  001 | feature-name | branch-name | status | updated_at
  ...
```

If `PULL_COUNT` is 0, print:

```
Shared database is empty — no existing team features found.
```

---

## Step 5 — Scan local spec directories and push new features

Scan the local `specs/` directory (relative to the repository root, which can be determined by running `git rev-parse --show-toplevel` if git is available, otherwise use the current working directory). Look for subdirectories matching the pattern `NNN-*` where `NNN` is a zero-padded number (e.g., `001-feature-name`, `002-sqlite-shared-sync`).

For each matching local feature directory:

1. Parse `feature_number` as the leading digits (e.g., `"002"` from `"002-sqlite-shared-sync"`).
2. Parse `short_name` as everything after the first hyphen-separated number (e.g., `"sqlite-shared-sync"`).
3. Set `branch_name` to the full directory name (e.g., `"002-sqlite-shared-sync"`).
4. Set `spec_file_path` to `specs/<dir-name>/spec.md` (relative path from repo root).
5. Check whether a row with this `feature_number` already exists in the shared database:

   ```sh
   sqlite3 "$SHARED_DB" "SELECT COUNT(*) FROM features WHERE feature_number = 'NNN';"
   ```

6. If the row does **not** exist, insert it:

   ```sh
   TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
   sqlite3 "$SHARED_DB" "INSERT INTO features (feature_number, short_name, branch_name, status, spec_file_path, created_at, updated_at) VALUES ('NNN', 'short-name', 'branch-name', 'draft', 'specs/branch-name/spec.md', '$TIMESTAMP', '$TIMESTAMP');"
   ```

Count the number of rows successfully inserted — this is `PUSH_COUNT`.

If any `sqlite3` write command fails with a "database is locked" error, output exactly:

```
Shared database is locked. Retry in a moment.
```

Then stop without completing remaining inserts.

---

## Step 6 — Write sync_log entries

After completing Steps 4 and 5, append audit entries to the `sync_log` table:

```sh
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Pull log entry
sqlite3 "$SHARED_DB" "INSERT INTO sync_log (timestamp, direction, records_affected, outcome, notes) VALUES ('$TIMESTAMP', 'pull', $PULL_COUNT, 'success', 'init: pulled team state');"

# Push log entry (only if PUSH_COUNT > 0)
sqlite3 "$SHARED_DB" "INSERT INTO sync_log (timestamp, direction, records_affected, outcome, notes) VALUES ('$TIMESTAMP', 'push', $PUSH_COUNT, 'success', 'init: pushed local features to shared db');"
```

If writing the log entry fails due to a locked database, set outcome to `'error'` in the notes and report to the user but do not treat this as a fatal error.

---

## Step 7 — Print final summary

After all steps complete successfully, output the following summary line:

```
Synced: X pulled, Y pushed. No conflicts.
```

Where `X` is `PULL_COUNT` and `Y` is `PUSH_COUNT`.

If any feature row already existed in the shared database (detected in Step 5 as COUNT > 0 for that feature_number), note it as a conflict:

```
Synced: X pulled, Y pushed. Z already existed (skipped).
```

Where `Z` is the count of local features that were already present in the shared database and therefore skipped.

If the command was run outside a git repository and `git` is not in PATH, print an informational note:

```
Note: git not available — used current working directory as repo root.
```

This is not an error; proceed normally.
