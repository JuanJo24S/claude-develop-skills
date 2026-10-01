---
name: secrets-management
description: Rules for credentials, API keys, tokens, connection strings and environment variables. Use whenever code needs a secret or configurable value, when creating or touching .env files or configuration, before every commit, and when a leaked or hardcoded secret is detected.
license: CC-BY-NC-SA-4.0 with an additional permission (see LICENSE.md)
metadata:
  author: Juan Camacho (JuanJo24S)
  source: https://github.com/JuanJo24S/claude-develop-skills
---

# Secrets and environment variables

## Rules

1. **No hardcoded secrets, ever.** Passwords, API keys, tokens, private keys, connection strings with credentials, signing secrets, third-party client IDs/secrets: all come from environment variables.
2. **All configurable values live in `.env`**, not only secrets: URLs of other services, ports, timeouts, feature flags, external endpoints. One place to change them, no hunting through code.
3. **`.env` files are never committed.** Only templates are versioned: `.env.example` (keys with empty or dummy values + a comment per key).
4. **Code never reads the environment directly from arbitrary places.** Each application or service has one configuration module that is the only reader of environment variables.

## `.gitignore` (verify every time)

Before the first commit of any branch, and whenever you create a `.env*` file, confirm `.gitignore` contains at least:

```gitignore
.env
.env.*
!.env.example
!.env.sample
!.env.template
*.pem
*.key
*.p12
*.pfx
```

Check with `git check-ignore -v <path-to-.env>`. If a `.env` file is already tracked: `git rm --cached <file>`, commit, and treat its contents as leaked (see below).

## Centralized configuration

```
<app-or-service>/
├── .env.example                 # Every key the app needs, documented, no real values
└── <config module>/             # e.g. infrastructure/config/ in a hexagonal layout: the ONLY place that reads environment variables
```

The config module must:
- Load the environment once at startup.
- **Validate** that required variables exist and have the right type/format; fail fast with a clear error naming the missing key (never print its value).
- Expose a typed, immutable configuration object that the rest of the code receives via dependency injection.
- Group keys by concern (`db`, `auth`, `services`, `broker`...).

Naming: `UPPER_SNAKE_CASE`, prefixed by concern (`DB_HOST`, `DB_PASSWORD`, `AUTH_JWT_SECRET`, `ORDERS_SERVICE_URL`). Reuse the same key name across services when it means the same thing.

Whenever you add, rename or remove a variable: update `.env.example` in the same commit and report it in the PR (section "Variables de entorno y configuración").

If several services run together locally with Docker Compose, use `env_file:` in `docker-compose.yml` pointing to each service's `.env`. In production, values come from the platform's secret manager, never from files in the repo.

## Detection

- This kit ships a scanner, `secret-scan.sh`, in the `hooks/` folder two levels above this skill's folder (`../../hooks/secret-scan.sh`). It scans all pending changes and, when the **git-guard** hook is active, runs automatically before every `git commit` (the commit is blocked if it finds something). Run it manually on the project with `bash <this-skill-folder>/../../hooks/secret-scan.sh .`
- When touching existing code, also look for hardcoded values the scanner may miss (e.g. secrets in unusual variable names, base64 blobs, credentials in test fixtures or docker-compose files).
- Obvious false positives (clearly fake data in tests) can be marked with a `secret-scan:allow` comment on that line. Never use it for real values.

## When a hardcoded secret is found

1. Replace the literal with a read from the config module; add the key to `.env.example` (no value) and the real value to the local `.env`.
2. Tell the user which file and which kind of secret it was (never echo the value itself).
3. Then, depending on where it is:

| Where the secret is | Action |
|---|---|
| Only in the working tree / staged | Fix it before committing. Done. |
| In local commits **not yet pushed** | Remove it from history before pushing: `git commit --amend` if it is the last commit; otherwise `git reset --soft origin/<branch>` (or `origin/main` for a new branch) and recommit cleanly in atomic commits. Tell the user. |
| Already **pushed** to the remote | Consider it **compromised**: tell the user immediately that the key must be **rotated/revoked** at the provider (removing it from Git does not un-leak it). Remove it from the code in a new commit. Purging history (`git filter-repo`) requires a force push, so propose it and wait for the lead developer's explicit approval; never do it on your own. |

## Pre-commit checklist

- [ ] No literals for passwords, keys, tokens or credentialed URLs in the diff.
- [ ] `.env` files are ignored and not staged; `.env.example` is updated.
- [ ] New configuration is read through the config module.
- [ ] Logs and error messages never print secret values.
