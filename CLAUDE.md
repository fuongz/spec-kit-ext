# spec-kit-ext Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-03-24

## Active Technologies
- YAML 1.2 + Markdown (speckit extension format; no compiled code) + `sqlite3` CLI ≥ 3.0 (required), `git` ≥ 2.0 (optional, for repo-root detection) (002-sqlite-shared-sync)
- SQLite file — schema defined in this plan; shared via any team-accessible path (network drive, cloud folder, git LFS) (002-sqlite-shared-sync)
- YAML 1.2 + Markdown (speckit extension format; no compiled code) + speckit runtime `>=0.3.2`; `git >=2.0` (optional, author identity only) (003-teammate-sync)
- YAML snapshot files at configurable path; default `.specify/sync/` (gitignored) (003-teammate-sync)
- YAML 1.2 + Markdown (speckit extension format) + SQLite via `sqlite3` CLI ≥ 3.0 + speckit runtime `>=0.3.2`, `sqlite3` CLI ≥ 3.0 (already required), `git >=2.0` (optional, repo root detection) (004-sqlite-sync-full-specs)
- Shared SQLite file — existing `features` + `sync_log` tables unchanged; new `spec_contents` table added (004-sqlite-sync-full-specs)

- YAML 1.2 + Markdown (speckit extension format; no compiled code) + speckit runtime `>=0.3.2`, git `>=2.0`, LLM API (configurable; defaults to Claude), system clipboard utility (`pbcopy` / `xclip` / `clip` — optional) (001-git-commit-extension)

## Project Structure

```text
src/
tests/
```

## Commands

# Add commands for YAML 1.2 + Markdown (speckit extension format; no compiled code)

## Code Style

YAML 1.2 + Markdown (speckit extension format; no compiled code): Follow standard conventions

## Recent Changes
- 004-sqlite-sync-full-specs: Added YAML 1.2 + Markdown (speckit extension format) + SQLite via `sqlite3` CLI ≥ 3.0 + speckit runtime `>=0.3.2`, `sqlite3` CLI ≥ 3.0 (already required), `git >=2.0` (optional, repo root detection)
- 003-teammate-sync: Added YAML 1.2 + Markdown (speckit extension format; no compiled code) + speckit runtime `>=0.3.2`; `git >=2.0` (optional, author identity only)
- 002-sqlite-shared-sync: Added YAML 1.2 + Markdown (speckit extension format; no compiled code) + `sqlite3` CLI ≥ 3.0 (required), `git` ≥ 2.0 (optional, for repo-root detection)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
