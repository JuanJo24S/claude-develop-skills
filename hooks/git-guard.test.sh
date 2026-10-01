#!/usr/bin/env bash
# Pruebas de git-guard.sh: cada regla contra repositorios git temporales, sin red ni remotos reales.
# © 2026 Juan Camacho (JuanJo24S). CC BY-NC-SA 4.0 con permiso adicional: ver LICENSE y PERMISO-ADICIONAL.md.
#   bash hooks/git-guard.test.sh
set -uo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
hook="$here/git-guard.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# new_repo <carpeta> <rama|vacio>: repo con un commit en esa rama, o sin commits si es "vacio"
new_repo() {
  git init -q -b main "$tmp/$1"
  [[ "$2" == vacio ]] && return
  git -C "$tmp/$1" -c user.name=test -c user.email=test@example.com commit -q --allow-empty -m 'chore: inicio'
  [[ "$2" == main ]] || git -C "$tmp/$1" switch -q -c "$2"
}
new_repo vacio vacio
new_repo main main
new_repo rama feat/demo
new_repo con-clave feat/demo
# Clave de AWS ficticia armada al ejecutar, para que este archivo no contenga una
printf 'aws_access_key_id = %s\n' "AKIA$(printf 'X%.0s' {1..16})" >"$tmp/con-clave/config.txt"

fails=0
# check <descripción> <comando> <repo> <código esperado: 0 pasa, 2 bloquea>
check() {
  local input code
  input="$(jq -n --arg c "$2" --arg d "$tmp/$3" '{tool_input: {command: $c}, cwd: $d}')"
  printf '%s' "$input" | "$hook" >/dev/null 2>&1
  code=$?
  if [[ "$code" == "$4" ]]; then
    echo "✔ $1"
  else
    echo "✖ $1: código $code, se esperaba $4"
    fails=$((fails + 1))
  fi
}

check 'un comando sin git pasa' 'ls -la' rama 0
check 'git status en main pasa' 'git status' main 0

check 'coautoría de Claude: se bloquea' "git commit -m 'feat: x' -m 'Co-Authored-By: Claude <noreply@anthropic.com>'" rama 2
check 'coautoría de OpenCode: se bloquea' "git commit -m 'feat: x' -m 'Co-authored-by: opencode <bot@example.com>'" rama 2
check 'PR con «Generated with Claude Code»: se bloquea' "gh pr create --title x --body 'Generated with [Claude Code](https://claude.com)'" rama 2
check 'coautoría del bot de OpenCode en GitHub: se bloquea' "git commit -m 'feat: x' -m 'Co-authored-by: opencode-agent[bot] <opencode-agent[bot]@users.noreply.github.com>'" rama 2
check 'coautoría de una persona pasa' "git commit -m 'feat: x' -m 'Co-authored-by: Ana <ana@example.com>'" rama 0

check 'push --force: se bloquea' 'git push --force' rama 2
check 'push -f: se bloquea' 'git push -f origin feat/demo' rama 2
check 'push --force-with-lease en la rama propia pasa' 'git push --force-with-lease' rama 0
check 'push a main: se bloquea' 'git push origin main' rama 2
check 'push estando en main: se bloquea' 'git push' main 2
check 'push de una rama pasa' 'git push -u origin feat/demo' rama 0

check 'commit en main con historial: se bloquea' "git commit -m 'feat: x'" main 2
check 'commit inicial en un repo vacío pasa' "git commit -m 'chore: inicio'" vacio 0
check 'commit en una rama pasa' "git commit -m 'feat: x'" rama 0

check 'git add .env: se bloquea' 'git add .env' rama 2
check 'git add de un .env.local en subcarpeta: se bloquea' 'git add config/.env.local' rama 2
check 'git add .env.example pasa' 'git add .env.example' rama 0
check 'commit con una clave en los cambios: se bloquea' "git commit -m 'feat: x'" con-clave 2

check 'rama válida pasa' 'git switch -c feat/user-login' rama 0
check 'rama con ñ: se bloquea' 'git switch -c feat/añadir-login' rama 2
check 'rama sin tipo: se bloquea' 'git checkout -b login' rama 2

check 'merge en main desde local: se bloquea' 'git merge feat/demo' main 2
check 'actualizar main con --ff-only pasa' 'git merge --ff-only origin/main' main 0
check 'gh pr merge: se bloquea' 'gh pr merge 12 --merge' rama 2
check 'gh pr create pasa' 'gh pr create --base main --title x --body y' rama 0

echo "fallos: $fails"
((fails == 0))
