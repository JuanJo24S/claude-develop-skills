---
name: pr-description
description: Runs tests and a self-review of the branch, generates the Pull Request Markdown document for the lead developer to validate and, if the user accepts, opens the PR with gh and stops there. Use when the user signals the branch work is finished ("listo", "terminamos", "es todo", "push final", "prepara el PR", "done", "prepare the PR").
license: CC-BY-NC-SA-4.0 with an additional permission (see LICENSE.md)
metadata:
  author: Juan Camacho (JuanJo24S)
  source: https://github.com/JuanJo24S/claude-develop-skills
---

# Pull Request document

Goal: the lead developer understands **in under 2 minutes** what changed, why, what the risks are and how to validate it, and receives code that has already been self-reviewed. The output document is written in **Spanish** unless the project's `CLAUDE.md` or `AGENTS.md` sets another language. No mentions of or attribution to AI assistants.

**Always** use [template.md](template.md) from this folder. Do not invent a different structure.

## Steps

### 1. Sync state
```bash
git branch --show-current                  # must not be main/master
git status --short                         # commit pending work first (git-workflow)
git fetch origin
```

### 2. Tests
- Run the test suite of every affected module or service.
- If tests fail: fix them before continuing. Only if the user explicitly decides to go ahead anyway, continue and record it as an alert.
- Check that new or changed behavior has tests; record any gap as an alert.

### 3. Self-review
Review the full branch diff (`git diff origin/main...HEAD`) as if you were the lead developer:
- If a code-review skill or command is available (e.g. `/code-review` in Claude Code), run it on the branch diff. Otherwise review manually.
- Check against: correctness bugs, **clean-code** checklist, **secrets-management** checklist (also run the kit's scanner on the project: `bash <this-skill-folder>/../../hooks/secret-scan.sh .`), change scope (**git-workflow** → Change scope), leftover debug logs, commented-out code, unjustified TODOs.
- **Fix** what you find, folding each fix into the commit that introduced the problem, so the PR never contains "fix" commits for errors created in the same branch:
  ```bash
  git commit --fixup=<commit-that-introduced-it>
  git rebase --autosquash origin/main
  ```
  The branch is yours and not merged, so after rewriting it push with `git push --force-with-lease` (never `--force`) and tell the user in one line. If the branch is shared with other developers, add a normal fix commit instead.
- Verify the content is unchanged apart from the fixes, then rerun tests.
- Anything you could not or should not fix (needs a decision, out of scope) goes to the PR alerts. Never hide findings.

### 4. Final push
```bash
git push
git log origin/<branch>..HEAD --oneline    # must be empty
```

### 5. Gather information against `main`
```bash
git log origin/main..HEAD --pretty=format:'%h %s'
git diff origin/main...HEAD --stat
git diff origin/main...HEAD
git diff origin/main...HEAD --numstat -- . ':(exclude)*.lock' ':(exclude)*package-lock.json' \
  | awk '{a+=$1; d+=$2} END {print a+d}'          # size, for the ~400-line guideline
```
Read the actual diff; don't rely only on commit messages. Identify:
- Functional changes per module or service.
- **Renames** of variables, functions, classes, files, columns, tables, layers, endpoints or environment variables (look for equivalent removed/added line pairs, and `git diff --find-renames --name-status` for files).
- Contracts/APIs, migrations, environment variables, dependencies, configuration and infrastructure.
- Risks: breaking changes, security, performance.

### 6. Fill the template
Read [template.md](template.md), copy it and fill it in:
- Remove entirely any `(opcional)` section that does not apply, and all `<!-- -->` comments.
- In **Cambios de nombres**, one `Antes | Después` row per rename, grouped by category when there is more than one.
- Set **Impacto** to Alto when there are breaking changes, migrations or security changes.
- In **🔎 Alertas de revisión**, list the soft alerts collected (see below). Remove the section if there are none.

### 7. Deliver

**The PR document is ALWAYS delivered as a file, never pasted in the chat.** The user copies it from the file into GitHub, so the Markdown must arrive intact.

1. Write it with the file-writing tool to `.pr/<branch-with-dashes>.md` (e.g. `feat/user-login` → `.pr/feat-user-login.md`). If a file for that branch already exists, update it instead of creating a new one. If `.pr/` is not git-ignored yet, add it to `.gitignore` and mention it in the summary.
2. Verify the file exists (`ls .pr/`).
3. In the chat, give **only**:
   - the clickable path to the file;
   - a 2–3 line summary (size, self-review result, points the reviewer must validate);
   - a reminder that `.pr/` is hidden in some file explorers (starts with a dot) and appears greyed out in the editor because it is git-ignored;
   - the link to open the PR on GitHub: `https://github.com/<owner>/<repo>/pull/new/<branch>`.
4. Never reproduce the document's content in the chat, not even partially.

### 8. Open the PR with `gh` (only if the user accepts)

If `gh` is installed and authenticated (`gh auth status`), ask the user in one short question whether to open the PR now. Skip the question only if the user already asked for it in this request (e.g. "sube el PR", "abre el PR").

- **The user accepts:**
  1. Make sure the branch is on the remote (`git push -u origin <branch>` if it is not there yet). Run `git push` and `gh pr create` as **separate commands**: one command that mentions both `push` and `main` is blocked by **git-guard** as a push to main.
  2. Create the PR with the document as its body and its `#` heading as the title:
     ```bash
     gh pr create --base main --head <branch> --title "<title>" --body-file .pr/<file>.md
     ```
  3. Check it: `gh pr view <number> --json url,mergeable,mergeStateStatus`.
  4. **Stop there.** Give the user the PR URL, say whether GitHub reports it as mergeable, and remind them that the merge is theirs. Never run `gh pr merge`, approve the PR or push more changes to it unless the user asks for a specific change.
- **The user declines, or `gh` is not available:** stop after step 7; the user opens the PR from the link.

If the remote repository is empty (no `main` on GitHub yet), do not push the branch: the first branch pushed to an empty repository becomes its default branch. Ask the user to create `main` first, for example with GitHub's «Add a README» button, and continue once it exists. Don't suggest GitHub's "push an existing repository" commands: their `git branch -M main` renames the current work branch to `main`.

## Review alerts (soft, informative)

These alerts are **not blockers and not errors**; they just tell the reviewer where to look a bit closer. Write them in a neutral, calm tone: no alarm words ("crítico", "peligro", "grave"), no uppercase. Use `ℹ️`.

| Alert | When |
|---|---|
| PR size | > ~400 changed lines (excluding lock files / generated code) |
| Scope | Files changed that are not directly related to the task |
| Tests | Behavior left without tests, or tests pushed failing by user decision |
| Self-review | Findings that were not fixed (needs a decision, out of scope) |

Example wording:
- `ℹ️ Tamaño: ~620 líneas cambiadas (referencia: 400). Se debe principalmente a <motivo>.`
- `ℹ️ Alcance: se modificó \`shared/logger.ts\`, que no forma parte directa de la tarea, para <motivo>.`

"Puntos de atención" is different: it is for real technical risks (breaking changes, security, performance).

## Quality criteria

- Prioritize what the reviewer **must know** over what is obvious from the diff.
- Be concrete: "Agrega `POST /auth/refresh` que emite un nuevo access token" beats "mejoras en autenticación".
- Only tick checklist items you actually verified; leave the rest unticked.
