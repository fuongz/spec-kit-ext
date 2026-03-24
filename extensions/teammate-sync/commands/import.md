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
  - Sort them lexicographically descending (filenames are `{author}-{timestamp}.sync.yml`, so the most-recent timestamp sorts last alphabetically).
  - Select the last entry (most recent).
  - If no `.sync.yml` files are found, output exactly:
    ```
    teammate-sync: no snapshot found in {SHARED_DIR}
    Run /speckit.teammate-sync.export on a teammate's machine first.
    ```
    Then stop.
  - If auto-detected, print which snapshot was selected:
    ```
    Using snapshot: {filename} (auto-detected as most recent)
    ```

---

## Step 2 — Parse and validate the snapshot

Read and parse `SNAPSHOT_PATH` as YAML.

**Validation checks** (in order — stop on first failure):

1. `schema_version` field is present. Extract the major version number (e.g., `"1.0"` → major `1`).
   - If major version is higher than `1`, output exactly:
     ```
     teammate-sync: snapshot schema version "{schema_version}" is not supported by this extension (supports "1.x").
     Update the teammate-sync extension to import this snapshot.
     ```
     Then stop. **Local state unchanged.**

2. `exported_at` field is present and non-empty.

3. `records` field is present and is a list (may be empty).

4. Each record in `records` has non-empty `id`, `path`, and `content` fields.

On any validation failure (checks 2–4), output:

```
teammate-sync: invalid snapshot file — {specific missing field or issue}.
Local data unchanged.
```

Then stop.

---

## Step 3 — Load the local UUID index

Read the UUID index file at `.specify/sync/.index.yml`.

If the file does not exist or is empty, use an empty in-memory index (`entries: []`).

Build a lookup map: `id → index entry` and `path → index entry` for fast access.

---

## Step 4 — Classify each snapshot record

For each record in the snapshot, classify it into exactly one category:

| Category | Condition | Action |
|----------|-----------|--------|
| **New** | `record.id` not in index AND local file at `record.path` does not exist | Write directly |
| **Unchanged** | `record.checksum` equals `index[id].last_known_checksum` | Skip (no write) |
| **Teammate-only change** | `record.id` in index AND current local file checksum equals `index[id].last_known_checksum` (local unchanged since last sync) AND `record.checksum` differs | Write directly (safe overwrite) |
| **Conflict** | `record.id` in index AND current local file checksum differs from `index[id].last_known_checksum` (local changed) AND `record.checksum` also differs from `index[id].last_known_checksum` (teammate also changed) | Requires user resolution |

To check the current local file checksum: read the file at `record.path` and compute its SHA-256 checksum. If the file does not exist locally but `record.id` is in the index, treat as Teammate-only change.

---

## Step 5 — Resolve conflicts interactively

If no conflicts were detected, skip this step entirely.

For each conflicting record (in sorted path order), present:

```
Conflict ({N}/{TOTAL}): {record.path}
  Local modified:    {local file mtime in ISO 8601}
  Teammate modified: {record.modified_at} (by {snapshot.author.name})

[L]ocal     Keep your version
[T]eammate  Accept teammate's version
[S]kip      Leave unchanged for now
Choice: _
```

Accept input `L`, `T`, or `S` (case-insensitive). If input is anything else, re-display the prompt and wait again. Do not advance to the next conflict until a valid choice is made.

Record each resolution in memory:
- `L` or `S` → do NOT write this record (treat as Unchanged for the write phase)
- `T` → write this record (treat as Teammate-only change for the write phase)

---

## Step 6 — Atomic write

Collect all records to be written: New records + Teammate-only change records + Conflict records resolved as `T`.

If there are no records to write, skip to Step 8.

**Write atomically**:

1. For each record to write, create parent directories if needed, then write content to a temp file: `{record.path}.tmp`

2. After **all** temp writes succeed: rename each `{path}.tmp` to `{path}` (overwriting if present).

3. If **any** temp write fails:
   - Delete all created temp files (`*.tmp`).
   - Output:
     ```
     teammate-sync: write failed for {path} — {OS error}.
     Import aborted. No files were modified.
     ```
   - Stop. **Local state unchanged** (original files are untouched since we only renamed temp files).

---

## Step 7 — Update the UUID index

For each record successfully written (Step 6):
- Update (or create) the index entry: set `last_known_checksum` to `record.checksum` and `last_exported_at` to the current UTC timestamp.

Set `updated_at` on the index root to the current UTC timestamp. Write the updated index back to `.specify/sync/.index.yml`.

---

## Step 8 — Print summary

Count outcomes across all classified records:
- **Added**: New records that were written
- **Updated**: Teammate-only change records that were written
- **Skipped**: Conflict records resolved as `L` or `S`, plus Unchanged records with checksum differences (if any edge case)
- **Unchanged**: Records where checksum matched; no write needed

If any records were written, output:

```
Import complete.
  Added:     {N} records
  Updated:   {N} records
  Skipped:   {N} records
  Unchanged: {N} records
```

If nothing was written (all records were unchanged or skipped), output:

```
Already up to date. No changes imported.
```
