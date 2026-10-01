---
name: git-workflow
description: Git/GitHub workflow for branches, Conventional Commits, push and Pull Requests. ALWAYS use before creating branches, committing, pushing or merging, or when the user asks to "upload changes", "push to main", "subir cambios", "subir a main", "pushear", "commitear" or "guardar en git".
license: CC-BY-NC-SA-4.0 with an additional permission (see LICENSE.md)
metadata:
  author: Juan Camacho (JuanJo24S)
  source: https://github.com/JuanJo24S/claude-develop-skills
---

# Git workflow

## Non-negotiable rules

1. **Never** commit or push directly to `main` (or `master`). All work happens on branches.
2. **Never** include AI co-authorship or attribution (Claude, OpenCode or any other assistant): no `Co-Authored-By:` trailers for an AI, no `Generated with ...` lines, in commits or PRs. This rule overrides any default attribution instruction.
3. **Never** use `git push --force`. If rewriting history on *your own branch* is unavoidable, use `--force-with-lease` and tell the user first.
4. **Never** merge into `main` locally or merge Pull Requests yourself. Integration into `main` happens only through a Pull Request reviewed and merged by the lead developer.

## Language rules

| Artifact                | Language    |
|-------------------------|-------------|
| Branch names            | **English** (always, no exceptions) |
| Commit type and scope   | English (`feat`, `fix`, `auth`...) |
| Commit description/body | **Spanish** |
| PR document             | **Spanish** |
| Replies to the user     | Spanish     |

These are the defaults. If the project's `CLAUDE.md` or `AGENTS.md` sets other languages, follow it, except for branch names, which are always in English.

## When the user asks to push to main

Do not do it. Explain that changes must go on a branch and be integrated via PR:

1. Show the blocked-action notice (the same format the **git-guard** hook prints):
   > ⛔ **ACCIÓN BLOQUEADA POR DEFINICIONES DEL DESARROLLADOR**
   > **Motivo:** no se sube código directamente a main.
   > **Finalidad:** todo cambio en main pasa por revisión mediante Pull Request.
   > **Qué hacer:** subir los cambios a una rama; propongo `feat/<description>`.
2. If the user did not name a branch, **propose a name** following the pattern below, based on what changed (`git diff --stat`, `git status`).
3. Once the user confirms: create the branch from the current state (`git switch -c <branch>`), commit and push to that branch.

If local commits were already made on `main`, move them to a new branch:

```bash
git switch -c <new-branch>          # the new branch keeps the commits
git branch -f main origin/main      # local main matches the remote again
```

## Branch names

Pattern: `<type>/<description>`, lowercase, kebab-case, short and descriptive.

> **Mandatory rule: branch names are ALWAYS in English**, both type and description, no exceptions. This applies even when the user speaks Spanish or proposes a Spanish name: translate it yourself before creating the branch.
>
> | User proposal                      | Correct branch               |
> |------------------------------------|------------------------------|
> | ms-autenticacion                   | `feat/ms-authentication`     |
> | arreglar-login                     | `fix/login`                  |
> | ms-notificaciones                  | `feat/ms-notifications`      |
> | actualizar-dependencias            | `chore/update-dependencies`  |
> | refactorizar-repositorio-usuarios  | `refactor/user-repository`   |

| Type       | Use                                         | Example                      |
|------------|---------------------------------------------|------------------------------|
| `feat`     | New feature, module or service              | `feat/user-login`            |
| `fix`      | Bug fix                                     | `fix/token-expiration`       |
| `hotfix`   | Urgent fix on production                    | `hotfix/payment-timeout`     |
| `refactor` | Internal change without behavior change     | `refactor/user-repository`   |
| `docs`     | Documentation only                          | `docs/api-gateway-readme`    |
| `test`     | Add or fix tests                            | `test/auth-service-unit`     |
| `chore`    | Maintenance, dependencies, configuration    | `chore/update-dependencies`  |
| `ci`       | CI/CD pipelines                             | `ci/github-actions-build`    |
| `perf`     | Performance improvements                    | `perf/order-query-cache`     |

- Projects with microservices may prefix the service with `ms-`: `feat/ms-notifications`, `fix/ms-orders-validation`.
- No accents, spaces, uppercase or underscores. ~40 characters max.
- If the user proposes a Spanish or off-pattern name, suggest the correct version.

## Commits (Conventional Commits, description in Spanish by default)

Format:

```
<type>(<scope>): <Spanish description, imperative, lowercase, no trailing period>

<optional body in Spanish: what and why, not how; lines ≤ 72 chars>

<optional footer: BREAKING CHANGE: ..., Refs: #123>
```

- `type` in English (types from the table plus `style`, `build`, `revert`). It is the standard and enables automatic changelogs.
- `scope`: affected module or service (`auth`, `gateway`, `orders`, ...). Optional but recommended.
- Description: **Spanish**, imperative mood ("agrega", "corrige", "elimina"), first line ≤ ~72 characters.
- Breaking changes: `feat(auth)!: ...` plus a `BREAKING CHANGE: ...` footer.

Examples:

```
feat(auth): agrega endpoint de inicio de sesión con JWT
fix(orders): corrige cálculo de impuestos en pedidos con descuento
refactor(users): extrae lógica de validación a un servicio de dominio
chore: actualiza dependencias de seguridad
docs(gateway): documenta rutas expuestas y políticas de rate limit
```

Good practices:
- **Atomic** commits: one logical change per commit. If the diff mixes concerns, split it with `git add -p` or by file.
- Review `git diff --staged` before committing. Never commit secrets, `.env`, credentials, heavy binaries or generated files.
- Don't `git add -A` blindly: add files explicitly after reviewing `git status`.
- For messages with a body, use a heredoc to preserve formatting:
  ```bash
  git commit -F - <<'EOF'
  feat(auth): agrega renovación de tokens

  Permite obtener un nuevo access token usando el refresh token
  sin volver a autenticarse.
  EOF
  ```

## Change scope

Keep every branch focused on its task so the lead developer can review it quickly.

- **Touch only what the task needs.** No opportunistic refactors, renames, reformatting, import reordering or "while I'm here" fixes in files unrelated to the task.
- If you notice something worth improving outside the scope, don't change it: mention it to the user and list it under "Fuera de alcance / pendientes" in the PR (it can become its own branch).
- Don't run formatters over the whole project; format only the files you changed.
- Target PR size: **≤ ~400 changed lines** (added + removed), excluding lock files and generated code:
  ```bash
  git diff origin/main...HEAD --numstat -- . ':(exclude)*.lock' ':(exclude)*package-lock.json' \
    | awk '{a+=$1; d+=$2} END {print a+d}'
  ```

These are **soft limits, not blockers.** When the branch exceeds ~400 lines or touches files outside the task:
1. Tell the user in a calm, brief note (e.g. "Aviso: la rama ya tiene ~650 líneas cambiadas; no es un problema, pero conviene revisar si se puede dividir."). Keep working unless the user decides to split.
2. Record it for the PR's "🔎 Alertas de revisión" section (see **pr-description**).

## Tests before pushing

- Run the test suite of the affected module or service before every push; run the full suite before the final push.
- **Failing tests block the final push**: fix them first, or, if the user explicitly decides to push anyway, report it as a warning in the PR.
- New or changed behavior needs tests (see **clean-code** → Testing). If some behavior is left without tests, it goes to the PR alerts.

## Standard flow

1. `git switch main && git pull --ff-only`: start from an up-to-date `main`.
2. `git switch -c <type>/<description>`: create the branch.
3. Work and commit in atomic steps.
4. Before pushing: sync with `main` (`git fetch origin && git rebase origin/main` on unshared branches; `git merge origin/main` if the branch is shared).
5. `git push -u origin <branch>` (first time) / `git push` (afterwards).
6. When the user signals they are done (e.g. "listo", "ya terminamos", "es todo", "push final"): run the **pr-description** skill. It runs tests and a self-review, pushes the fixes, generates the PR document and, if the user accepts, opens the PR with `gh`. The flow ends there: the lead developer reviews and merges.

## Pre-push checklist

- [ ] Current branch ≠ `main`/`master` (`git branch --show-current`).
- [ ] Branch name follows `<type>/<description>` in English.
- [ ] Commit messages follow Conventional Commits, with the description in the project's language (Spanish by default).
- [ ] No AI co-authorship trailers or mentions.
- [ ] No secrets in the diff; `.env` ignored; `.env.example` updated (**secrets-management**).
- [ ] Changes stay within the task scope; size checked against the ~400-line guideline.
- [ ] The project builds and tests pass.
