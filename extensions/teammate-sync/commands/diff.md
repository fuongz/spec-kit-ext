## Step 1 — Resolve snapshot path

Read the extension configuration for `teammate-sync` from the project's speckit config.

**Read the following config value**:
- `extensions.teammate-sync.shared_sync_folder` — default snapshot directory (optional)

**Determine `SHARED_DIR`**:
- If `shared_sync_folder` is set and non-empty: use that path.
- Otherwise: use `.specify/sync/` relative to the project root.

**Determine `SNAPSHOT_PATH`**:
- If a `<snapshot-path>` argument was provided on the command line: use it directly.
- Otherwise: scan `SHARED_DIR` for all files matching `*.sync.yml`.
  - Sort them lexicographically descending and select the last entry (most recent by timestamp in filename).
  - If no `.sync.yml` files are found, output exactly:
    ```
    teammate-sync: no snapshot found in {SHARED_DIR}
    Run /speckit.teammate-sync.export on a teammate's machine first.
    ```
    Then stop.
  - If auto-detected, note the selected filename for use in Step 5 output.

---

## Step 2 — Parse and validate the snapshot

Read and parse `SNAPSHOT_PATH` as YAML.

Apply the same validation as the import command:

1. `schema_version` present; major version must be `1`. If higher, output:
   ```
   teammate-sync: snapshot schema version "{schema_version}" is not supported by this extension (supports "1.x").
   ```
   Then stop.

2. `exported_at` present and non-empty.

3. `records` present and is a list.

4. Each record has non-empty `id`, `path`, and `content`.

On any validation failure (checks 2–4):
```
teammate-sync: invalid snapshot file — {specific issue}.
```
Then stop. **No local state changed.**

---

## Step 3 — Load the local UUID index

Read the UUID index file at `.specify/sync/.index.yml`.

If the file does not exist or is empty, use an empty in-memory index (`entries: []`).

Build a lookup map: `id → index entry` for fast access.

Also count total local spec files by scanning `specs/` with the same discovery rules used by the export command (exclude `.specify/sync/` and `specs/**/checklists/**`).

---

## Step 4 — Classify each snapshot record

For each record in the snapshot, apply the same classification logic as the import command:

| Symbol | Category | Condition |
|--------|----------|-----------|
| `+` | **New** | `record.id` not in index AND local file does not exist |
| `~` | **Teammate change** | `record.id` in index AND local checksum matches `last_known_checksum` (local unchanged) AND `record.checksum` differs |
| `!` | **Conflict** | `record.id` in index AND local checksum differs from `last_known_checksum` AND `record.checksum` also differs |
| `=` | **Unchanged** | `record.checksum` equals `last_known_checksum` in index |

Compute counts for each category.

---

## Step 5 — Print diff output

**⚠️ CRITICAL: Do not write any files, do not modify the UUID index, do not modify any local state.**

If differences exist (any `+`, `~`, or `!` records):

Print the header:

```
Snapshot: {snapshot filename} (by {snapshot.author.name}, exported {snapshot.exported_at})
Comparing against: {total local file count} local records
```

Print the changes section — list all `+`, `~`, and `!` records first (sorted by path), then up to 3 `=` records, then collapse the rest:

```
Changes:
  + specs/003-teammate-sync/spec.md        [new from teammate]
  + specs/003-teammate-sync/plan.md        [new from teammate]
  ~ specs/001-git-commit/tasks.md          [modified by teammate]
  ! specs/002-sqlite-shared-sync/spec.md   [CONFLICT — both modified]
  = specs/001-git-commit/spec.md           [unchanged]
  = specs/001-git-commit/plan.md           [unchanged]
  = specs/001-git-commit/research.md       [unchanged]
  ({N} more unchanged)
```

If there are 3 or fewer unchanged records, list them all without the collapse line.

Print the summary line:

```
Summary: {new} new  |  {updated} updated  |  {conflicts} conflicts  |  {unchanged} unchanged
Run /speckit.teammate-sync.import to apply changes.
```

**If no differences exist** (all records are `=`):

```
Snapshot: {snapshot filename} (by {snapshot.author.name}, exported {snapshot.exported_at})
Already up to date. No differences found.
```
