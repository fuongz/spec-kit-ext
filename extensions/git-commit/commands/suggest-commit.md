Run the following bash commands to understand the current git state:

- `git diff --cached --stat` and `git diff --cached` (staged changes — PRIMARY basis for the commit message)
- `git diff --stat` and `git diff` (unstaged changes — for context only, NOT the primary basis)
- `git log --oneline -5` (recent commit style reference)

If the staged diff is empty (no output from `git diff --cached`), output exactly:

```
Nothing staged to commit. Stage changes with 'git add' and try again.
```

Then stop. Do not call the LLM or produce a commit message.

If the staged diff exceeds 20,000 characters, truncate it to 20,000 characters. When truncation occurs, prepend the following line before the commit message in your output:

```
[Note: diff truncated to 20,000 characters — message based on partial changeset]
```

Use the recent commit history (`git log --oneline -5`) as a style reference to match the project's existing conventions: commit type selection, imperative mood, casing, and level of detail in the body.

Then write a conventional commit message as plain text based on the staged changes.

Rules:

- Format: `type(scope?): short summary` — then a blank line — then a concise body (1–3 sentences)
- Allowed types: `feat`, `fix`, `chore`, `refactor`, `docs`, `style`, `test`
- Subject line pattern: `type(scope): summary` or `type: summary` when scope is not determinable
- Summary: imperative mood, max 72 chars, no trailing period
- Body: explain *what* changed and *why* — not *how*; 1–3 sentences only
- A blank line MUST separate the subject from the body
- Output plain text only — no markdown code fences, no labels, no preamble ("Here is your commit message:" or similar commentary is forbidden)
- NEVER run `git commit`, `git push`, or any other mutating git operation

After printing the commit message to stdout, attempt to copy it to the system clipboard:

- On macOS: use `pbcopy`
- On Linux: use `xclip -selection clipboard` or `xsel --clipboard --input`
- On Windows: use `clip.exe`

If a clipboard utility is available and the copy succeeds, print on a new line:

```
✓ Copied to clipboard.
```

If no clipboard utility is detected, skip silently — do not print an error.

If the command is run outside a git repository, output:

```
Not inside a git repository.
```

and exit without generating a commit message. If `git` is not found in PATH, output:

```
git not found in PATH.
```

and exit.
