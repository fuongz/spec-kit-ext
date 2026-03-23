# git-commit

A speckit extension that generates conventional commit messages from staged git changes using an LLM.

## What it does

Run `speckit.git-commit.suggest-commit` (or `git suggest-commit`) after staging your changes. The extension:

1. Inspects your staged diff, unstaged changes (for context), and recent commit history
2. Sends them to an LLM to generate a conventional commit message
3. Prints the message as plain text to your terminal
4. Copies it to your clipboard (if a clipboard utility is available)

It also registers an **optional** `after_implement` hook — so the suggestion appears automatically after every `/speckit.implement` session, with no extra step needed.

## Requirements

| Requirement | Notes |
|---|---|
| speckit `>=0.3.2` | Runtime for the command |
| git `>=2.0` | Must be available in PATH |
| LLM credential | Configured in speckit's LLM settings |
| `pbcopy` / `xclip` / `xsel` | Optional — clipboard copy only |

## Installation

1. Copy this extension into your project's `extensions/` directory:

   ```
   extensions/git-commit/
   ├── extension.yml
   ├── commands/
   │   └── suggest-commit.md
   └── README.md
   ```

2. Register the extension with speckit (see your speckit version's install docs).

3. Verify:

   ```
   speckit extensions list
   # git-commit v0.1.0
   ```

## Usage

### Manual invocation

Stage your changes, then run:

```
speckit.git-commit.suggest-commit
```

**Example output:**

```
feat(auth): add JWT token refresh on expiry

Extend the authentication flow to automatically refresh expired JWT tokens
before the user is redirected to login. This eliminates the session drop
reported in user feedback.

✓ Copied to clipboard.
```

### Auto-trigger after `/speckit.implement`

With the `after_implement` hook enabled, the commit message suggestion appears automatically after each implement session — no extra step needed.

To disable, set the hook to `enabled: false` in your speckit config.

## Edge cases

**Nothing staged:**
```
Nothing staged to commit. Stage changes with 'git add' and try again.
```

**Very large diff** (>20,000 characters):
```
[Note: diff truncated to 20,000 characters — message based on partial changeset]

chore: reorganize module structure across multiple packages
...
```

**No clipboard utility:** Message is printed to stdout only — no confirmation line appears.

**Initial commit (no history):** Generates a message using standard conventional commit conventions as the style baseline.

**Not in a git repository:**
```
Not inside a git repository.
```

## What it will never do

- Execute `git commit`, `git push`, or any mutating git operation
- Modify your working tree or index
- Output markdown code fences, labels, or preamble text
- Create or delete any files
- Require internet access beyond the LLM API call

## Version history

| Version | Changes |
|---|---|
| 0.1.0 | Initial release — suggest-commit command + after_implement hook |
