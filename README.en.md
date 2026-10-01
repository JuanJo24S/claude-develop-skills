# claude-develop-skills

Skills and hooks that make your coding agent, **Claude Code** or **OpenCode**, follow an orderly Git workflow, produce Pull Requests that are easy to review, keep secrets out of the code and write clean code.

Author: **Juan Camacho ([JuanJo24S](https://github.com/JuanJo24S))** · License: [CC BY-NC-SA 4.0 with an additional permission](#license) · [Español](README.md)

> The skills are written in English. By default, they ask the agent to write commit descriptions and PR documents in Spanish; see [Customization](#customization) to change it.

## What's included

### Skills

| Skill | What it does |
|---|---|
| [`git-workflow`](skills/git-workflow/SKILL.md) | `<type>/<description>` branches in English, Conventional Commits, nothing straight to `main`, standard flow and a pre-push checklist. |
| [`pr-description`](skills/pr-description/SKILL.md) | When a branch is done: runs the tests, self-reviews, pushes and writes the PR document to `.pr/` from a fixed [template](skills/pr-description/template.md). If you accept, it opens the PR with `gh` and stops there: you do the merge. |
| [`secrets-management`](skills/secrets-management/SKILL.md) | Rules for `.env`, `.gitignore` and centralized configuration, and what to do when a secret leaks. |
| [`clean-code`](skills/clean-code/SKILL.md) | SOLID, readability, hexagonal architecture, a pattern catalog, testing and, when the project uses them, microservice principles. |

### Hooks

| File | What it does |
|---|---|
| [`hooks/git-guard.sh`](hooks/git-guard.sh) | Checks every command the agent is about to run and blocks the ones that break the rules (list below). |
| [`hooks/secret-scan.sh`](hooks/secret-scan.sh) | Looks for keys and credentials in pending changes. `git-guard` runs it before every commit. |
| [`hooks/git-guard.test.sh`](hooks/git-guard.test.sh) | Tests for `git-guard` using temporary repositories. |
| [`opencode/git-guard.js`](opencode/git-guard.js) | OpenCode plugin that applies `git-guard.sh` before every command. |

### What git-guard blocks

When it blocks something, the agent gets a "⛔ ACCIÓN BLOQUEADA" notice (in Spanish) with the reason, the purpose of the rule and what to do instead.

- Commits or pushes straight to `main` or `master`. The initial commit of an empty repository is allowed.
- `git push --force`. `--force-with-lease` is allowed.
- AI co-authorship or attribution in commits and PRs (`Co-Authored-By: Claude`, `Generated with Claude Code`...).
- `git add` of `.env` files. `.env.example` files are allowed.
- Commits whose changes contain likely keys or credentials.
- Branches that don't follow `<type>/<description>` in English kebab-case (e.g. `feat/user-login`).
- Merge, rebase or cherry-pick onto `main` locally, and `gh pr merge`: the reviewer merges.

## Requirements

- `bash`, `git` and [`jq`](https://jqlang.org/). Without `jq`, `git-guard` prints a warning and does not enforce the rules.
- `gh` is optional; `pr-description` uses it to create the PR when it is installed.

## Installing in Claude Code

### As a plugin (recommended)

Inside Claude Code:

```text
/plugin marketplace add JuanJo24S/claude-develop-skills
/plugin install develop-skills@claude-develop-skills
```

The skills become available as `/develop-skills:git-workflow`, `/develop-skills:pr-description`, and so on, and the agent uses them when they apply. The hook is active in every project where the plugin is enabled. To install it for one project only:

```bash
claude plugin install develop-skills@claude-develop-skills --scope project
```

### Manual copy into a project

```bash
git clone https://github.com/JuanJo24S/claude-develop-skills ~/claude-develop-skills
mkdir -p .claude/skills .claude/hooks
cp -r ~/claude-develop-skills/skills/* .claude/skills/
cp ~/claude-develop-skills/hooks/*.sh .claude/hooks/
```

Then register the hook in `.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "\"$CLAUDE_PROJECT_DIR\"/.claude/hooks/git-guard.sh" }
        ]
      }
    ]
  }
}
```

## Installing in OpenCode

OpenCode reads the same skill format. The hook is installed as an OpenCode plugin ([`opencode/git-guard.js`](opencode/git-guard.js)) that calls `git-guard.sh`. Tested with OpenCode 1.18.25.

### If you only use OpenCode

In a project:

```bash
git clone https://github.com/JuanJo24S/claude-develop-skills ~/claude-develop-skills
mkdir -p .opencode/skills .opencode/hooks .opencode/plugins
cp -r ~/claude-develop-skills/skills/* .opencode/skills/
cp ~/claude-develop-skills/hooks/*.sh .opencode/hooks/
cp ~/claude-develop-skills/opencode/git-guard.js .opencode/plugins/
```

For all your projects, use the same folders under `~/.config/opencode/` (`skills/`, `hooks/` and `plugins/`) instead of `.opencode/`.

### If you use Claude Code and OpenCode in the same project

OpenCode also reads `.claude/skills/`. Do the [manual Claude Code copy](#manual-copy-into-a-project) and add only the plugin:

```bash
mkdir -p .opencode/plugins
cp ~/claude-develop-skills/opencode/git-guard.js .opencode/plugins/
```

The plugin finds the scripts in `.claude/hooks/`. Don't also copy the skills into `.opencode/skills/`, or OpenCode will see them twice. OpenCode doesn't see skills installed as a Claude Code plugin, so use the manual copy to share them.

### Notes

- The plugin looks for `git-guard.sh` first in `../hooks/` relative to its own folder, then in the project's `.claude/hooks/`. If it can't find it, it blocks `git` and `gh` commands with a warning, so you don't end up unprotected without noticing.
- The file must sit directly inside `plugins/`, not in a subfolder.
- To check the installation: `opencode debug info` lists the loaded plugins and `opencode debug skill` lists the skills.

## Customization

- **Languages.** By default, commit descriptions and the PR document are in Spanish, and branch names are always in English. To change the language of commits and PRs, say so in the project's `CLAUDE.md` or `AGENTS.md`.
- **Scanner false positives.** If a line with clearly fake data (for example, in a test) looks like a secret, add a `secret-scan:allow` comment on that line. Never use it for real values.
- **Protected branches.** They are `main` and `master`. Change them in the `protected` variable in `hooks/git-guard.sh`.

## Tests

```bash
bash hooks/git-guard.test.sh
```

## Contributing

Contributions are welcome: bug reports, improvements to the skills and to `git-guard`, compatibility with other Claude Code or OpenCode versions, and documentation. Read the [contributing guide](CONTRIBUTING.md#contributing-english) before opening a PR. For new skills or large changes, open an [issue](https://github.com/JuanJo24S/claude-develop-skills/issues) first.

## License

© 2026 Juan Camacho (JuanJo24S). Everything in this repository is licensed under [CC BY-NC-SA 4.0](LICENSE) with an [additional permission for commercial use](PERMISO-ADICIONAL.md#additional-permission-for-commercial-use-english). The `LICENSE` file holds the official Spanish translation of the legal code; the original English text is at <https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode>.

| You may | You may not |
|---|---|
| Use it for free, including in paid work, client projects or inside a company. | Sell it, license it for a fee or charge for access to it. |
| Copy, modify and share it. | Include it in a paid product, course or bundle whose main value is this material. |
| Publish your adapted version, under this same license. | Remove the authorship notice. |

If you share this material or an adapted version, give credit like this:

> Based on [claude-develop-skills](https://github.com/JuanJo24S/claude-develop-skills) by Juan Camacho (JuanJo24S), licensed CC BY-NC-SA 4.0 with an additional permission for commercial use.

If you changed it, say so.
