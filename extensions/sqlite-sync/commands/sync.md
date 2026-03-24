## Step 1 — Read configuration and determine execution context

Read the extension configuration for `sqlite-sync` from the project's `.specify/extensions.yml` file (or equivalent speckit config location).

**Read the following config values**:
- `extensions.sqlite-sync.shared_db_path` — path to the shared SQLite file (required)
- `extensions.sqlite-sync.auto_update` — boolean, defaults to `true` if not set

**If `shared_db_path` is missing or empty**, output exactly:

```
sqlite-sync: shared_db_path not configured. See README for setup.
```

Then stop.

**If `auto_update` is `false`**, output exactly:

```
sqlite-sync: auto_update is disabled. Skipping.
```

Then stop.

**Read the optional `--direction` argument** if provided on the command line. Accepted values: `push`, `pull`, `both`. Default: `both`.

**Determine the caller context** — whether this command is being invoked by a speckit hook or manually:
- If invoked by a hook, the calling event name is available (e.g., `after_specify`, `after_plan`, `after_tasks`, `after_implement`).
- If invoked manually (no hook context), treat as manual invocation.

---

## Step 2 — Push path: detect current feature and determine status to write

This step applies when direction is `push` or `both`.

**Detect the current feature branch**:

```sh
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
```

If git is not available or the command fails, set `BRANCH` to empty string.

**Check if the branch matches the feature branch pattern** (`NNN-*` where NNN is digits):
- If `BRANCH` is empty or does not match the pattern (no leading digits followed by a hyphen), this is a non-feature branch. Skip the push step entirely and proceed to Step 4 (pull). Print:

  ```
  No active feature detected on current branch. Pulling team state only.
  ```

**If the branch matches the feature pattern**:
- Parse `feature_number` as the leading digit sequence (e.g., `"002"` from `"002-sqlite-shared-sync"`).
- Parse `short_name` as everything after the first hyphen (e.g., `"sqlite-shared-sync"`).

**Determine the status to write** based on the caller context:

| Hook event | Status to write |
|------------|----------------|
| `after_specify` | `draft` |
| `after_plan` | `planning` |
| `after_tasks` | `tasks` |
| `after_implement` | `implementing` |
| Manual invocation (no hook) | Do NOT update status — skip push; proceed to pull only |

If this is a manual invocation with no `--direction push` argument explicitly set, skip the status-write step to avoid overwriting the current status with stale data. Proceed directly to Step 4 (pull).

---

## Step 3 — Push path: upsert the feature row in the shared database

This step only executes when:
- Direction is `push` or `both`, AND
- A valid feature branch was detected in Step 2, AND
- The caller context is a hook event (not manual invocation).

Run the following commands using `$SHARED_DB` (the value of `shared_db_path`):

```sh
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Upsert the feature row (INSERT OR REPLACE ensures idempotency)
sqlite3 "$SHARED_DB" "INSERT OR REPLACE INTO features (feature_number, short_name, branch_name, status, spec_file_path, created_at, updated_at)
VALUES (
  '$FEATURE_NUMBER',
  '$SHORT_NAME',
  '$BRANCH',
  '$STATUS',
  'specs/$BRANCH/spec.md',
  COALESCE((SELECT created_at FROM features WHERE feature_number = '$FEATURE_NUMBER'), '$TIMESTAMP'),
  '$TIMESTAMP'
);"
```

After the upsert, append a `sync_log` entry:

```sh
sqlite3 "$SHARED_DB" "INSERT INTO sync_log (timestamp, direction, records_affected, outcome, notes) VALUES ('$TIMESTAMP', 'push', 1, 'success', 'hook: $HOOK_EVENT set status=$STATUS for $BRANCH');"
```

If `sqlite3` returns a "database is locked" error, output:

```
Shared database is locked. Retry in a moment.
```

Then stop. Set `PUSH_OUTCOME` to `error`.

Set `PUSH_OUTCOME` to `success` and `PUSH_COUNT` to `1`.

---

## Step 3b — Push current feature's spec file content

This step runs immediately after Step 3, under the same preconditions (valid feature branch, hook event context).

**Check that `spec_contents` table exists**. If it does not (v0.1.0 database), print:

```
sqlite-sync: spec_contents table not found. Run /speckit.sqlite-sync.init to upgrade the schema.
```

Then continue to Step 4 — do not abort.

**Determine `FEATURE_DIR`** = `specs/$BRANCH/` relative to repo root.

**Discover spec files** under `FEATURE_DIR`: all files matching `**/*.md`, `**/*.yml`, `**/*.yaml`, excluding paths under `**/checklists/**` and files ending in `.tmp`.

**Derive `FILE_TYPE`** for each file using this mapping:
- `spec.md` → `spec`
- `plan.md` → `plan`
- `tasks.md` → `tasks`
- `data-model.md` → `data-model`
- `research.md` → `research`
- `quickstart.md` → `quickstart`
- files under `contracts/` with `.md` extension → `contract`
- anything else → `other`

**For each discovered file**, upsert its content into `spec_contents`:

```sh
FILE_MODIFIED_AT=$(date -u -r "$FILE_PATH" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ")
ESCAPED_CONTENT=$(sed "s/'/''/g" "$FILE_PATH")
sqlite3 "$SHARED_DB" "INSERT OR REPLACE INTO spec_contents (feature_number, file_type, file_path, content, file_modified_at, synced_at, is_deleted) VALUES ('$FEATURE_NUMBER', '$FILE_TYPE', '$FILE_PATH', '$ESCAPED_CONTENT', '$FILE_MODIFIED_AT', '$TIMESTAMP', 0);"
```

**Soft-delete files** that were previously in `spec_contents` for this feature but no longer exist locally:

```sh
sqlite3 "$SHARED_DB" "UPDATE spec_contents SET is_deleted = 1, synced_at = '$TIMESTAMP' WHERE feature_number = '$FEATURE_NUMBER' AND file_path NOT IN ($(echo "$ACTIVE_FILE_PATHS" | sed "s/.*/'&'/" | paste -sd,));"
```

Set `CONTENT_PUSH_COUNT` = number of records upserted. If `FEATURE_DIR` does not exist or contains no matching files, `CONTENT_PUSH_COUNT = 0` — no error.

**Update the `sync_log` notes** for the Step 3 push entry to include the content count:

```
hook: $HOOK_EVENT set status=$STATUS for $BRANCH; $CONTENT_PUSH_COUNT content records pushed
```

---

## Step 4 — Pull path: fetch newer records from the shared database

This step applies when direction is `pull` or `both`.

Query the shared database for all feature records that are newer than what the local view last recorded. For simplicity, fetch all records and display them as the current team state:

```sh
sqlite3 -separator " | " "$SHARED_DB" "SELECT feature_number, short_name, branch_name, status, updated_at FROM features ORDER BY feature_number;"
```

Compare the result against the feature pushed in Step 3 (if any). Count records where `updated_at` differs from the locally-known value as `PULL_COUNT`.

If the shared database does not yet exist (first run before init), output:

```
sqlite-sync: shared database not found. Run /speckit.sqlite-sync.init first.
```

Then stop.

Append a `sync_log` entry for the pull:

```sh
sqlite3 "$SHARED_DB" "INSERT INTO sync_log (timestamp, direction, records_affected, outcome, notes) VALUES ('$TIMESTAMP', 'pull', $PULL_COUNT, 'success', 'sync: pulled team state');"
```

---

## Step 5 — Print outcome

After Steps 3, 3b, and 4 complete, print the result:

**If records were updated** (PUSH_COUNT + PULL_COUNT + CONTENT_PUSH_COUNT > 0):

```
Synced: X records updated. {CONTENT_PUSH_COUNT} content records pushed.
```

Where `X` is the total of PUSH_COUNT + PULL_COUNT.

**If nothing changed** (PUSH_COUNT = 0, PULL_COUNT = 0, and CONTENT_PUSH_COUNT = 0):

```
Already up to date.
```

**If only the pull ran** (manual invocation, no push):

Print the current team feature list in a readable format:

```
Team features (N total):
  NNN | short-name | status | updated_at
  ...
Already up to date.
```

Or if records were newer than local state:

```
Team features (N total):
  NNN | short-name | status | updated_at
  ...
Synced: X records updated.
```
