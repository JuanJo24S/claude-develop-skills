// git-guard para OpenCode: antes de cada comando de la herramienta bash, aplica hooks/git-guard.sh.
// © 2026 Juan Camacho (JuanJo24S). CC BY-NC-SA 4.0 con permiso adicional: ver LICENSE y PERMISO-ADICIONAL.md.
// https://github.com/JuanJo24S/claude-develop-skills
//
// Va en .opencode/plugins/ (o ~/.config/opencode/plugins/), con los scripts en la carpeta hooks/ de al lado.
// Si no están ahí, los busca en .claude/hooks/ del proyecto (instalación compartida con Claude Code).
// OpenCode exige que todo lo que exporta un plugin sea una función: no exportar constantes.

import { spawnSync } from "node:child_process"
import { existsSync } from "node:fs"
import path from "node:path"
import { fileURLToPath } from "node:url"

const pluginDir = path.dirname(fileURLToPath(import.meta.url))

function findScript(projectRoot) {
  return [
    path.join(pluginDir, "..", "hooks", "git-guard.sh"),
    path.join(projectRoot, ".claude", "hooks", "git-guard.sh"),
  ].find((candidate) => existsSync(candidate))
}

export const GitGuard = async ({ directory, worktree }) => {
  const script = findScript(worktree || directory)

  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return
      const command = output.args?.command
      if (!command) return

      if (!script) {
        if (/(git|gh)\s/.test(command)) {
          throw new Error(
            "git-guard: no encuentro git-guard.sh en ../hooks/ junto al plugin ni en .claude/hooks/ del proyecto; " +
              "los comandos git quedan bloqueados hasta instalarlo.",
          )
        }
        return
      }

      const cwd = path.resolve(directory, output.args.workdir ?? ".")
      const result = spawnSync("bash", [script], {
        input: JSON.stringify({ tool_input: { command }, cwd }),
        encoding: "utf8",
      })
      if (result.status === 2) throw new Error(result.stderr.trim())
      if (result.status !== 0) console.warn(`git-guard: ${(result.stderr || String(result.error ?? "")).trim()}`)
    },
  }
}
