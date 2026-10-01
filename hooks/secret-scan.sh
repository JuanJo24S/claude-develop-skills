#!/usr/bin/env bash
# secret-scan: parte de git-guard.
# © 2026 Juan Camacho (JuanJo24S). CC BY-NC-SA 4.0 con permiso adicional: ver LICENSE y PERMISO-ADICIONAL.md.
# https://github.com/JuanJo24S/claude-develop-skills
#
# Escanea los cambios pendientes de commit (staged, unstaged y archivos nuevos no ignorados)
# en busca de claves y credenciales hardcodeadas, y de archivos .env que Git no ignora.
# Uso: secret-scan.sh [directorio-del-repo]
# Salida: lista de hallazgos (archivo + tipo, nunca el valor). Exit 1 si encuentra algo.
# Para ignorar un falso positivo evidente (dato ficticio de un test), añade "secret-scan:allow" en esa línea.

set -uo pipefail
export LC_ALL=C

repo="${1:-.}"
cd "$repo" 2>/dev/null || exit 0
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0

# secret-scan:allow (definiciones de patrones)
patterns=(
  'Clave de AWS|AKIA[0-9A-Z]{16}'
  'Clave privada|-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'Token de GitHub|(gh[pousr]_[A-Za-z0-9]{36}|github_pat_[A-Za-z0-9_]{22,})'
  'Token de Slack|xox[abprs]-[A-Za-z0-9-]{10,}'
  'Clave de API (sk-/sk_live_)|(sk-[A-Za-z0-9_-]{20,}|sk_live_[A-Za-z0-9]{16,})'
  'Clave de Google|AIza[0-9A-Za-z_-]{35}'
  'Credenciales en URL de conexión|[a-zA-Z][a-zA-Z0-9+.-]*://[^/:@[:space:]$]+:[^/@[:space:]$]{3,}@'
  'Credencial hardcodeada|[Pp][Aa][Ss][Ss][Ww]([Oo][Rr])?[Dd]|[Ss][Ee][Cc][Rr][Ee][Tt]|[Aa][Pp][Ii]_?[Kk][Ee][Yy]|[Tt][Oo][Kk][Ee][Nn]|[Pp][Rr][Ii][Vv][Aa][Tt][Ee]_?[Kk][Ee][Yy]'
)
# Para "Credencial hardcodeada" exige además una asignación a un literal: nombre = "valor" (≥6 caracteres)
literal_assign='["'"'"']?[[:space:]]*[:=][[:space:]]*["'"'"'][^"'"'"'[:space:]$]{6,}["'"'"']'

is_excluded() {
  case "$1" in
    *.env.example|*.env.sample|*.env.template|*.lock|*package-lock.json|secret-scan.sh|*/secret-scan.sh) return 0 ;;
  esac
  return 1
}

# Líneas añadidas: "archivo<TAB>contenido"
added_lines() {
  { git diff --cached -U0 --no-color; git diff -U0 --no-color; } 2>/dev/null |
    awk '/^\+\+\+ b\//{f=substr($0,7);next} /^\+\+\+/{next} /^\+/{print f "\t" substr($0,2)}'
  git ls-files --others --exclude-standard -z 2>/dev/null |
    while IFS= read -r -d '' f; do
      [[ -f "$f" ]] && grep -Iv -e '^$' -- "$f" 2>/dev/null | awk -v f="$f" '{print f "\t" $0}'
    done
}

findings=""

while IFS=$'\t' read -r file line; do
  is_excluded "$file" && continue
  [[ "$line" == *secret-scan:allow* ]] && continue
  for p in "${patterns[@]}"; do
    label="${p%%|*}"; re="${p#*|}"
    if [[ "$label" == "Credencial hardcodeada" ]]; then
      echo "$line" | grep -qE "(${re})[A-Za-z_]*${literal_assign}" || continue
    else
      echo "$line" | grep -qE -- "$re" || continue
    fi
    findings+="  - ${file}: ${label}"$'\n'
  done
done < <(added_lines)

# Archivos .env presentes que Git NO ignora
while IFS= read -r envf; do
  git check-ignore -q -- "$envf" || findings+="  - ${envf}: archivo .env no ignorado por .gitignore"$'\n'
done < <(find . -path ./.git -prune -o -path '*/node_modules' -prune -o -type f -name '.env*' \
           ! -name '*.example' ! -name '*.sample' ! -name '*.template' -print 2>/dev/null | sed 's|^\./||')

# Archivos .env ya versionados
while IFS= read -r envf; do
  is_excluded "$envf" || findings+="  - ${envf}: archivo .env versionado en Git (usar git rm --cached)"$'\n'
done < <(git ls-files 2>/dev/null | grep -E '(^|/)\.env(\.[^/]*)?$')

if [[ -n "$findings" ]]; then
  printf 'Posibles secretos detectados:\n%s' "$(printf '%s' "$findings" | sort -u)"
  echo
  exit 1
fi
exit 0
