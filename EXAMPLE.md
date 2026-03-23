Run the following bash commands to understand the current git state:
- `git status`
- `git diff --cached --stat` and `git diff --cached` (staged changes)
- `git diff --stat` and `git diff` (unstaged changes)
- `git log --oneline -5` (recent commit style reference)

Then write a conventional commit message as plain text based on what you find.

Rules:
- Format: `type(scope?): short summary` — then a blank line — then a concise body (1–3 sentences)
- Types: `feat`, `fix`, `chore`, `refactor`, `docs`, `style`, `test`
- Summary: imperative mood, max 72 chars, no period
- Body: explain *what* and *why*, not *how*
- Output plain text only — no markdown fences, no commentary, no "here is your commit message"
- NEVER run `git commit` or `git push`
