## Step 1 — Resolve output directory

Read the extension configuration for `teammate-sync` from the project's speckit config (`.specify/extensions.yml` or equivalent).

**Read the following config value**:
- `extensions.teammate-sync.shared_sync_folder` — path to the snapshot output directory (optional)

**Determine the output directory**:
- If `shared_sync_folder` is set and non-empty: use that path as `OUTPUT_DIR`.
  - Check that the path exists and is writable. If the path does not exist or is not writable, output exactly:
    ```
    teammate-sync: shared_sync_folder not found or not writable: {path}
    Run: mkdir -p {path}
    ```
    Then stop.
- If `shared_sync_folder` is not set: use `.specify/sync/` relative to the project root as `OUTPUT_DIR`. Create this directory if it does not exist.

**Read the optional `--output` argument** if provided. If present, it overrides `OUTPUT_DIR` entirely — use the provided path directly (create parent directories if needed).

---

## Step 2 — Load or create the local UUID index

Read the UUID index file at `.specify/sync/.index.yml`.

If the file does not exist or is empty, initialise an in-memory empty index:

```yaml
index_version: "1.0"
updated_at: ""
entries: []
```

The index maps each tracked file path to its assigned UUID, last export timestamp, and last known checksum. Each entry has:
- `path` — relative path from project root (e.g., `specs/001-feature/spec.md`)
- `id` — UUID v4 string (immutable once assigned)
- `last_exported_at` — ISO 8601 UTC timestamp of last export
- `last_known_checksum` — `sha256:{hex}` of content at last export

---

## Step 3 — Discover spec files

Recursively find all files under `specs/` matching these patterns:
- `specs/**/*.md`
- `specs/**/*.yml`
- `specs/**/*.yaml`

**Exclude** the following:
- Any path under `.specify/sync/`
- Any path matching `specs/**/checklists/**`
- Any path matching `specs/**/*.tmp`

If no files are found, output exactly:

```
Nothing to export: specs/ directory is empty or contains no matching files.
```

Then stop.

---

## Step 4 — Process each file

For each discovered file, in sorted path order:

1. **Look up UUID**: Check the index for an entry with matching `path`.
   - If found: use the existing `id`.
   - If not found: generate a new UUID v4 and add a new entry to the in-memory index.

2. **Read content**: Read the full UTF-8 text content of the file.

3. **Compute checksum**: Calculate SHA-256 of the content. Format as `sha256:{lowercase-hex}`.

4. **Record `modified_at`**: Attempt `git log -1 --format=%cI -- {path}` from the project root.
   - If git is available and the command returns a non-empty result: use that ISO 8601 timestamp.
   - Otherwise: use the file's last-modified time (mtime) in ISO 8601 UTC format.

---

## Step 5 — Determine author identity

Attempt to read:
- `git config user.name` → `AUTHOR_NAME`
- `git config user.email` → `AUTHOR_EMAIL`

If git is unavailable or the commands fail:
- Set `AUTHOR_NAME` to the system hostname.
- Omit `AUTHOR_EMAIL` from the snapshot entirely.

---

## Step 6 — Assemble the snapshot

Build the YAML snapshot structure in memory:

```yaml
schema_version: "1.0"
exported_at: "{current UTC ISO 8601 timestamp}"
author:
  name: "{AUTHOR_NAME}"
  email: "{AUTHOR_EMAIL}"   # omit this line if email is unavailable
  host: "{system hostname}"
records:
  - id: "{uuid}"
    path: "{relative path from project root}"
    modified_at: "{ISO 8601 UTC}"
    checksum: "sha256:{hex}"
    content: |
      {full file content}
  # ... one entry per discovered file
```

Ensure `content` values use YAML block scalar (`|`) so multiline content is preserved correctly.

---

## Step 7 — Write snapshot atomically

1. Generate the output filename: `{sanitized-author-name}-{YYYYMMDDTHHMMSSz}.sync.yml`
   - Sanitize author name: lowercase, replace spaces and special characters with hyphens, strip leading/trailing hyphens.
   - Timestamp: current UTC in format `YYYYMMDDTHHMMSSZ` (e.g., `20260324T103000Z`).

2. Write the snapshot YAML to a temp file: `{OUTPUT_DIR}/.tmp-{timestamp}.sync.yml`

3. On successful write: rename the temp file to the final filename.

4. On any write error:
   - Delete the temp file if it exists.
   - Output the OS error message.
   - Stop. **Do not update the UUID index.**

---

## Step 8 — Update the UUID index

For each record written to the snapshot:
- Update (or create) the index entry: set `last_exported_at` to the current UTC timestamp and `last_known_checksum` to the computed checksum.

Set `updated_at` on the index root to the current UTC timestamp.

Write the updated index back to `.specify/sync/.index.yml`.

---

## Step 9 — Print outcome

Output exactly:

```
Exported {N} records to: {output_path}
```

Where `N` is the total number of records included in the snapshot and `output_path` is the full path of the written snapshot file.
