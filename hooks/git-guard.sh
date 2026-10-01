#!/usr/bin/env bash
# git-guard: bloquea operaciones git que rompen el flujo de trabajo (ramas, PR y secretos).
# © 2026 Juan Camacho (JuanJo24S). CC BY-NC-SA 4.0 con permiso adicional: ver LICENSE y PERMISO-ADICIONAL.md.
# https://github.com/JuanJo24S/claude-develop-skills
#
# Entrada (stdin): {"tool_input": {"command": "..."}, "cwd": "..."}, el formato de PreToolUse de Claude Code.
# En OpenCode lo llama opencode/git-guard.js con la misma entrada.
# Exit 2 = bloquear el comando y devolver el aviso (stderr) al agente.

set -euo pipefail
export LC_ALL=C  # [a-z] no debe aceptar letras acentuadas ni ñ

if ! command -v jq >/dev/null 2>&1; then
  echo "git-guard: falta jq; las reglas no se aplican hasta instalarlo." >&2
  exit 1
fi

input="$(cat)"
cmd="$(jq -r '.tool_input.command // empty' <<<"$input")"
cwd="$(jq -r '.cwd // empty' <<<"$input")"

[[ -z "$cmd" ]] && exit 0
[[ "$cmd" =~ (git|gh)[[:space:]] ]] || exit 0

# block <motivo> <finalidad> <qué hacer>
block() {
  cat >&2 <<EOF
⛔ ACCIÓN BLOQUEADA POR DEFINICIONES DEL DESARROLLADOR
• Motivo: $1
• Finalidad: $2
• Qué hacer: $3
(Muestra este aviso al usuario tal cual, en un bloque de cita, sin añadir explicaciones largas.)
EOF
  exit 2
}

current_branch() {
  git -C "${cwd:-.}" branch --show-current 2>/dev/null || true
}

has_commits() {
  git -C "${cwd:-.}" rev-parse --verify HEAD >/dev/null 2>&1
}

protected='^(main|master)$'
branch="$(current_branch)"
is_commit=false
grep -qE '(^|[;&|[:space:]])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+commit' <<<"$cmd" && is_commit=true

# 1. Coautoría / atribución de IA en commits o PRs
if grep -qiE 'co-authored-by:.*(claude|anthropic|opencode|openai|chatgpt|copilot|gemini)|generated (with|by) \[?(claude|opencode)|noreply@anthropic\.com|opencode-agent\[bot\]' <<<"$cmd"; then
  block "el commit/PR incluye coautoría o atribución de IA." \
        "el historial refleja solo a los autores del equipo." \
        "quitar la línea de coautoría y repetir."
fi

# 2. Push
if grep -qE '(^|[;&|[:space:]])git([[:space:]]+-[^[:space:]]+)*[[:space:]]+push' <<<"$cmd"; then
  if grep -qE '(^|[[:space:]])(--force|-f)([[:space:]]|$)' <<<"$cmd"; then
    block "push --force puede borrar trabajo ajeno en el remoto." \
          "proteger el historial compartido." \
          "usar --force-with-lease, solo en tu rama y con aprobación."
  fi
  if grep -qE 'push.*([[:space:]]|:)(main|master)([[:space:];&|]|$)' <<<"$cmd" || [[ "$branch" =~ $protected ]]; then
    block "no se sube código directamente a main." \
          "todo cambio en main pasa por revisión mediante Pull Request." \
          "crear una rama <tipo>/<descripcion> (ej. feat/user-login) y subirla ahí."
  fi
fi

# 3. Commit directo en main (se permite solo el commit inicial de un repo vacío)
if $is_commit && [[ "$branch" =~ $protected ]] && has_commits; then
  block "no se hacen commits en main." \
        "main solo recibe cambios revisados por Pull Request." \
        "crear una rama <tipo>/<descripcion> y commitear en ella."
fi

# 4. Secretos: nunca versionar .env ni commitear claves hardcodeadas
if grep -qE 'git[[:space:]]+add([[:space:]]+[^;&|]*)?[[:space:]](\./)?([^[:space:];&|]*/)?\.env(\.[A-Za-z0-9_-]+)?([[:space:];&|]|$)' <<<"$cmd" \
   && ! grep -qE '\.env\.(example|sample|template)' <<<"$cmd"; then
  block "los archivos .env no se suben al repositorio." \
        "evitar la filtración de claves y credenciales." \
        "dejar .env en .gitignore y documentar las variables en .env.example."
fi
if $is_commit && ! scan="$("$(dirname "$0")/secret-scan.sh" "${cwd:-.}")"; then
  files="$(grep -E '^  - ' <<<"$scan" | sed -E 's/^  - ([^:]+):.*/\1/' | sort -u | paste -sd ',' - | sed 's/,/, /g')"
  block "posibles claves o credenciales en: ${files}." \
        "evitar que se filtren secretos en el historial." \
        "mover los valores a .env y leerlos desde el módulo de configuración."
fi

# 5. Nombre de rama: <tipo>/<descripcion> en inglés, kebab-case, sin acentos ni ñ
branch_re='^(feat|fix|hotfix|refactor|docs|test|chore|ci|perf|style|build|revert)/[a-z0-9]+(-[a-z0-9]+)*$'
new_branch="$(grep -oE 'git[[:space:]]+(switch[[:space:]]+(-c|-C|--create)|checkout[[:space:]]+(-b|-B)|branch)[[:space:]]+[^[:space:];&|]+' <<<"$cmd" \
  | awk '{print $NF}' | head -n1 || true)"
if [[ -n "$new_branch" && "$new_branch" != -* && ! "$new_branch" =~ $protected && ! "$new_branch" =~ $branch_re ]]; then
  block "la rama '$new_branch' no sigue el patrón <tipo>/<descripcion> en inglés." \
        "mantener ramas uniformes y fáciles de identificar." \
        "usar un nombre como feat/user-login o fix/token-expiration."
fi

# 6. Integración: nada se fusiona en main desde local, y el merge de un PR lo hace quien revisa
if [[ "$branch" =~ $protected ]] && grep -qE 'git[[:space:]]+(merge|rebase|cherry-pick)' <<<"$cmd" \
   && ! grep -qE 'git[[:space:]]+(merge|rebase)[[:space:]]+(--abort|--ff-only[[:space:]]+origin/(main|master))' <<<"$cmd"; then
  block "no se integran cambios en main desde local." \
        "todo lo que llega a main pasa por revisión." \
        "subir la rama y abrir un Pull Request."
fi
if grep -qE 'gh[[:space:]]+pr[[:space:]]+merge' <<<"$cmd"; then
  block "el agente no fusiona Pull Requests." \
        "quien revisa decide qué llega a main." \
        "pedir la revisión y que el merge lo haga el desarrollador principal."
fi

exit 0
