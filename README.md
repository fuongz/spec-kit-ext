# spec-kit-ext

A collection of community extensions for [spec-kit](https://github.com/github/spec-kit).

## Extensions

| Extension | Version | Description |
|---|---|---|
| [git-commit](extensions/git-commit/) | 0.1.1 | Generates conventional commit messages from staged git changes using an LLM |
| [sqlite-sync](extensions/sqlite-sync/) | 0.2.0 | Maintains a shared SQLite database of all team features; stores full spec file content on every sync; auto-updates via optional hooks |
| [teammate-sync](extensions/teammate-sync/) | 0.1.0 | Sync specs with teammates using portable YAML snapshots — no server required; supports export, import with conflict resolution, and diff preview |

## Setup

Extensions are installed using the `specify` CLI. Since this repository is not part of the official spec-kit catalog, you have two options: register this repo's catalog URL so `specify extension add` can find extensions by name, or install directly from a local clone.

**Prerequisite**: spec-kit 0.1.0+ installed (`specify version` to check).

---

### Option A — Register the catalog (recommended)

This lets you install extensions by name and receive updates via `specify extension update`.

**Step 1** — Add the catalog to your project:

```bash
specify extension catalog add \
  --name "spec-kit-ext" \
  --install-allowed \
  https://raw.githubusercontent.com/fuongz/spec-kit-ext/main/extensions/catalog.json
```

This creates or updates `.specify/extension-catalogs.yml` in your project.

**Step 2** — Install the extensions you want:

```bash
specify extension add git-commit
specify extension add sqlite-sync
specify extension add teammate-sync
```

**Step 3** — Configure extensions that require it (see [Per-extension configuration](#per-extension-configuration) below).

---

### Option B — Install from a local clone

Use this for development, air-gapped environments, or to try extensions before they are published.

**Step 1** — Clone this repository:

```bash
git clone https://github.com/fuongz/spec-kit-ext.git
```

**Step 2** — Install extensions using `--dev`:

```bash
specify extension add --dev ./spec-kit-ext/extensions/git-commit
specify extension add --dev ./spec-kit-ext/extensions/sqlite-sync
specify extension add --dev ./spec-kit-ext/extensions/teammate-sync
```

**Step 3** — Configure extensions that require it (see below).

---

### New project quickstart

Setting up a brand-new spec-kit project with these extensions:

```bash
# 1. Create and enter your project
mkdir my-project && cd my-project

# 2. Register the catalog
specify extension catalog add \
  --name "spec-kit-ext" \
  --install-allowed \
  https://raw.githubusercontent.com/fuongz/spec-kit-ext/main/extensions/catalog.json

# 3. Install extensions
specify extension add git-commit
specify extension add sqlite-sync
specify extension add teammate-sync

# 4. Configure sqlite-sync
#    Edit .specify/extensions/sqlite-sync/sqlite-sync-config.yml:
#    shared_db_path: /path/to/shared/speckit-team.db

# 5. Bootstrap the shared database (run once per team member)
#    Open Claude Code and run: /speckit.sqlite-sync.init
```

---

### Existing project quickstart

Adding these extensions to a project already using spec-kit:

```bash
# 1. Register the catalog (skip if already done)
specify extension catalog add \
  --name "spec-kit-ext" \
  --install-allowed \
  https://raw.githubusercontent.com/fuongz/spec-kit-ext/main/extensions/catalog.json

# 2. Install the extensions you need
specify extension add sqlite-sync    # team feature tracking with full spec content
specify extension add git-commit     # commit message generation
specify extension add teammate-sync  # YAML snapshot sync between teammates

# 3. Configure sqlite-sync
#    Copy the config template and fill in your shared path:
cp .specify/extensions/sqlite-sync/sqlite-sync-config.template.yml \
   .specify/extensions/sqlite-sync/sqlite-sync-config.yml
#    Then edit sqlite-sync-config.yml and set shared_db_path

# 4. Bootstrap the shared database (run once per team member)
#    Open Claude Code and run: /speckit.sqlite-sync.init
```

---

### Per-extension configuration

After installation, extension config files live in `.specify/extensions/{name}/`.

**`git-commit`** — no configuration required. Works out of the box.

**`teammate-sync`** — no configuration required. Works out of the box. Optionally set `shared_sync_folder` to a shared directory (Dropbox, network drive, etc.) so teammates can pick up snapshots automatically:

```yaml
extensions:
  teammate-sync:
    shared_sync_folder: /path/to/shared/sync-folder
    auto_export: false
```

**`sqlite-sync`** — requires `shared_db_path`:

```bash
# Copy the template
cp .specify/extensions/sqlite-sync/sqlite-sync-config.template.yml \
   .specify/extensions/sqlite-sync/sqlite-sync-config.yml
```

Edit `sqlite-sync-config.yml`:

```yaml
shared_db_path: /path/to/your/team/speckit-shared.db
auto_update: true
conflict_strategy: last_write_wins
```

The full annotated template is also at [`extensions/sqlite-sync/config/sqlite-sync.template.yml`](extensions/sqlite-sync/config/sqlite-sync.template.yml).

---

### Managing installed extensions

```bash
# List installed extensions
specify extension list

# Check for updates
specify extension update

# Disable without removing
specify extension disable sqlite-sync

# Remove
specify extension remove sqlite-sync
```

---

### What to commit to git

```gitignore
# Add to .gitignore
.specify/extensions/.cache/
.specify/extensions/.backup/
.specify/extensions/*/*.local.yml
.specify/extensions/.registry
```

**Commit**: `.specify/extension-catalogs.yml`, `.specify/extensions.yml`, and `*-config.yml` files (without secrets).
**Do not commit**: `.local.yml` overrides, cache, backup, and registry files.

---

### Per-extension reference

| Extension | Required config | Config template | Full docs |
|-----------|----------------|-----------------|-----------|
| `git-commit` | None | — | [README](extensions/git-commit/README.md) |
| `sqlite-sync` | `shared_db_path` | [sqlite-sync.template.yml](extensions/sqlite-sync/config/sqlite-sync.template.yml) | [README](extensions/sqlite-sync/README.md) |
| `teammate-sync` | None | [teammate-sync.template.yml](extensions/teammate-sync/config/teammate-sync.template.yml) | [README](extensions/teammate-sync/README.md) |

## Contributing

1. Fork this repo
2. Create your extension under `extensions/<your-extension-name>/`
3. Add an `extension.yml` manifest (see [extensions/git-commit/extension.yml](extensions/git-commit/extension.yml) for reference)
4. Add your extension entry to [extensions/catalog.json](extensions/catalog.json)
5. Open a pull request

## License

MIT
