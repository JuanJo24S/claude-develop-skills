# claude-develop-skills

Skills y hooks para que tu agente de código, **Claude Code** u **OpenCode**, trabaje con un flujo de Git ordenado, Pull Requests fáciles de revisar, secretos fuera del código y código limpio.

Autor: **Juan Camacho ([JuanJo24S](https://github.com/JuanJo24S))** · Licencia: [CC BY-NC-SA 4.0 con permiso adicional](#licencia) · [English](README.en.md)

## Qué incluye

### Skills

| Skill | Qué hace |
|---|---|
| [`git-workflow`](skills/git-workflow/SKILL.md) | Ramas `<tipo>/<descripcion>` en inglés, Conventional Commits, nada directo a `main`, flujo estándar y checklist antes del push. |
| [`pr-description`](skills/pr-description/SKILL.md) | Al terminar una rama: corre los tests, hace una autorrevisión, sube los cambios y genera el documento del PR en `.pr/` con una [plantilla](skills/pr-description/template.md) fija. |
| [`secrets-management`](skills/secrets-management/SKILL.md) | Reglas para `.env`, `.gitignore` y la configuración centralizada, y qué hacer si se filtra un secreto. |
| [`clean-code`](skills/clean-code/SKILL.md) | SOLID, legibilidad, arquitectura hexagonal, catálogo de patrones, testing y, si el proyecto los usa, principios de microservicios. |

### Hooks

| Archivo | Qué hace |
|---|---|
| [`hooks/git-guard.sh`](hooks/git-guard.sh) | Revisa cada comando que el agente va a ejecutar y bloquea los que rompen las reglas (lista abajo). |
| [`hooks/secret-scan.sh`](hooks/secret-scan.sh) | Busca claves y credenciales en los cambios pendientes. `git-guard` lo ejecuta antes de cada commit. |
| [`hooks/git-guard.test.sh`](hooks/git-guard.test.sh) | Pruebas de `git-guard` con repositorios temporales. |
| [`opencode/git-guard.js`](opencode/git-guard.js) | Plugin de OpenCode que aplica `git-guard.sh` antes de cada comando. |

### Qué bloquea git-guard

Cuando bloquea algo, el agente recibe un aviso «⛔ ACCIÓN BLOQUEADA» con el motivo, la finalidad de la regla y qué hacer.

- Commits o push directos a `main` o `master`. Se permite el commit inicial de un repositorio vacío.
- `git push --force`. `--force-with-lease` sí se permite.
- Coautoría o atribución de una IA en commits y PRs (`Co-Authored-By: Claude`, `Generated with Claude Code`...).
- `git add` de archivos `.env`. Los `.env.example` sí se permiten.
- Commits con posibles claves o credenciales en los cambios.
- Ramas que no siguen `<tipo>/<descripcion>` en inglés y kebab-case (por ejemplo `feat/user-login`).
- Merge, rebase o cherry-pick sobre `main` desde local, y `gh pr merge`: el merge lo hace quien revisa.

## Requisitos

- `bash`, `git` y [`jq`](https://jqlang.org/). Sin `jq`, `git-guard` avisa y no aplica las reglas.
- `gh` es opcional; `pr-description` lo usa para crear el PR si está instalado.

## Instalación en Claude Code

### Como plugin (recomendado)

Dentro de Claude Code:

```text
/plugin marketplace add JuanJo24S/claude-develop-skills
/plugin install develop-skills@claude-develop-skills
```

Las skills quedan disponibles como `/develop-skills:git-workflow`, `/develop-skills:pr-description`, etc., y el agente las usa solo cuando corresponden. El hook se activa en todos los proyectos donde el plugin esté habilitado. Para instalarlo solo en un proyecto:

```bash
claude plugin install develop-skills@claude-develop-skills --scope project
```

### Copia manual en un proyecto

```bash
git clone https://github.com/JuanJo24S/claude-develop-skills ~/claude-develop-skills
mkdir -p .claude/skills .claude/hooks
cp -r ~/claude-develop-skills/skills/* .claude/skills/
cp ~/claude-develop-skills/hooks/*.sh .claude/hooks/
```

Después, registra el hook en `.claude/settings.json`:

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

## Instalación en OpenCode

OpenCode lee el mismo formato de skills. El hook se instala como plugin de OpenCode ([`opencode/git-guard.js`](opencode/git-guard.js)), que llama a `git-guard.sh`. Probado con OpenCode 1.18.25.

### Si solo usas OpenCode

En un proyecto:

```bash
git clone https://github.com/JuanJo24S/claude-develop-skills ~/claude-develop-skills
mkdir -p .opencode/skills .opencode/hooks .opencode/plugins
cp -r ~/claude-develop-skills/skills/* .opencode/skills/
cp ~/claude-develop-skills/hooks/*.sh .opencode/hooks/
cp ~/claude-develop-skills/opencode/git-guard.js .opencode/plugins/
```

Para todos tus proyectos, usa las mismas carpetas dentro de `~/.config/opencode/` (`skills/`, `hooks/` y `plugins/`) en lugar de `.opencode/`.

### Si usas Claude Code y OpenCode en el mismo proyecto

OpenCode también lee `.claude/skills/`. Haz la [copia manual de Claude Code](#copia-manual-en-un-proyecto) y agrega solo el plugin:

```bash
mkdir -p .opencode/plugins
cp ~/claude-develop-skills/opencode/git-guard.js .opencode/plugins/
```

El plugin encuentra los scripts en `.claude/hooks/`. No copies las skills también en `.opencode/skills/`, porque OpenCode las vería duplicadas. OpenCode no ve las skills instaladas como plugin de Claude Code, así que para compartirlas usa la copia manual.

### Notas

- El plugin busca `git-guard.sh` primero en `../hooks/` respecto a su carpeta y después en `.claude/hooks/` del proyecto. Si no lo encuentra, bloquea los comandos `git` y `gh` y avisa, para que no quedes sin protección sin darte cuenta.
- El archivo tiene que ir directamente dentro de `plugins/`, no en una subcarpeta.
- Para comprobar la instalación: `opencode debug info` lista los plugins cargados y `opencode debug skill` lista las skills.

## Personalización

- **Idiomas.** Por defecto, las descripciones de los commits y el documento del PR van en español, y las ramas siempre en inglés. Para cambiar el idioma de commits y PRs, indícalo en el `CLAUDE.md` o `AGENTS.md` del proyecto.
- **Falsos positivos del escáner.** Si una línea con datos claramente ficticios (por ejemplo, en un test) parece un secreto, añade el comentario `secret-scan:allow` en esa línea. Nunca lo uses con valores reales.
- **Ramas protegidas.** Son `main` y `master`. Se cambian en la variable `protected` de `hooks/git-guard.sh`.

## Pruebas

```bash
bash hooks/git-guard.test.sh
```

## Licencia

© 2026 Juan Camacho (JuanJo24S). Todo el contenido de este repositorio se distribuye bajo [CC BY-NC-SA 4.0](LICENSE) con un [permiso adicional de uso comercial](PERMISO-ADICIONAL.md).

| Puedes | No puedes |
|---|---|
| Usarlo gratis, también en trabajo remunerado, en proyectos para clientes o dentro de una empresa. | Venderlo, licenciarlo a cambio de un pago o cobrar por acceder a él. |
| Copiarlo, modificarlo y compartirlo. | Incluirlo en un producto, curso o paquete de pago cuyo valor principal sea este material. |
| Publicar tu versión adaptada, bajo esta misma licencia. | Quitar el aviso de autoría. |

Si compartes este material o una versión adaptada, da crédito así:

> Basado en [claude-develop-skills](https://github.com/JuanJo24S/claude-develop-skills) de Juan Camacho (JuanJo24S), licencia CC BY-NC-SA 4.0 con permiso adicional de uso comercial.

Si lo modificaste, indícalo.
