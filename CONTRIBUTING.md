# Cómo contribuir

Se aceptan aportes de cualquier persona. Esta guía explica qué aportar, cómo preparar el cambio y bajo qué licencia queda. [English below](#contributing-english).

## Qué puedes aportar

- **Errores en `git-guard` o `secret-scan`.** Un comando que se bloquea sin motivo, uno que debería bloquearse y pasa, o un tipo de secreto que el escáner no detecta.
- **Mejoras a las skills existentes**, para que el agente las siga mejor o cubran más casos.
- **Compatibilidad** con otras versiones de Claude Code u OpenCode.
- **Documentación**: correcciones, ejemplos y traducciones.
- **Skills nuevas.** Abre primero un [issue](https://github.com/JuanJo24S/claude-develop-skills/issues) para acordar si encajan en el kit.

Para cualquier cambio grande, abre también un issue antes de escribir código. Issues y PRs se aceptan en español o en inglés.

## Cómo preparar tu cambio

1. Haz un fork del repositorio y clónalo.
2. Crea una rama desde `main` con el patrón `<tipo>/<descripcion>`, en inglés y kebab-case: `fix/secret-scan-gcp-keys`, `feat/rust-support`, `docs/opencode-global-install`.
3. Escribe commits con [Conventional Commits](https://www.conventionalcommits.org/es/): tipo y alcance en inglés y descripción en español, por ejemplo `fix(hooks): detecta claves de servicio de GCP`. Si no hablas español, la descripción en inglés también se acepta.
4. Comprueba que todo pase:
   ```bash
   bash hooks/git-guard.test.sh          # debe terminar en «fallos: 0»
   claude plugin validate . --strict     # si tienes Claude Code
   ```
   Si cambias una regla de `git-guard.sh`, agrega en `hooks/git-guard.test.sh` un caso que la pruebe.
5. Abre un Pull Request contra `main` explicando qué cambia, por qué y cómo lo probaste. El autor lo revisa y hace el merge; `main` está protegida y solo recibe cambios por PR.

Si usas Claude Code u OpenCode con este kit instalado, el agente sigue estos pasos solo, con las skills `git-workflow` y `pr-description`.

## Reglas

- **Nada de secretos ni datos reales.** Usa valores ficticios en ejemplos y pruebas. Si un dato ficticio parece un secreto, márcalo con `secret-scan:allow` en esa línea.
- **Sin coautoría ni atribución de IA en los commits** (`Co-Authored-By: Claude`, `Generated with ...`). Puedes usar asistentes de IA, pero el commit lo firmas tú y respondes por el cambio.
- **No quites ni cambies los avisos de autoría y licencia**: el encabezado de cada `SKILL.md`, el `LICENSE.md` de cada skill y las cabeceras de los scripts.
- **Mantén las skills genéricas**, sin nada propio de un proyecto o de una empresa.
- **Aporta solo contenido escrito por ti.** No copies skills, código ni textos de terceros.

## Licencia de tus aportes

Al enviar un aporte aceptas que:

- se publique bajo [CC BY-NC-SA 4.0](LICENSE) con el mismo [permiso adicional de uso comercial](PERMISO-ADICIONAL.md) que el resto del repositorio, para que todo el kit tenga las mismas condiciones: se puede usar gratis, también en trabajo remunerado, pero no se puede vender;
- tienes derecho a aportarlo, porque lo escribiste tú.

Tu autoría queda registrada en el historial de commits.

---

## Contributing (English)

Contributions from anyone are welcome. *Translation for reference; the Spanish text above prevails.*

**What you can contribute:** bugs in `git-guard` or `secret-scan` (a command blocked for no reason, one that should be blocked but passes, a kind of secret the scanner misses); improvements to the existing skills; compatibility with other Claude Code or OpenCode versions; documentation fixes, examples and translations. For new skills or any large change, open an [issue](https://github.com/JuanJo24S/claude-develop-skills/issues) first. Issues and PRs are welcome in Spanish or English.

**How to prepare your change:**

1. Fork the repository and clone it.
2. Branch off `main` using `<type>/<description>` in English kebab-case, e.g. `fix/secret-scan-gcp-keys`.
3. Use [Conventional Commits](https://www.conventionalcommits.org/): type and scope in English, description in Spanish (English is also accepted), e.g. `fix(hooks): detecta claves de servicio de GCP`.
4. Check that everything passes: `bash hooks/git-guard.test.sh` must end with `fallos: 0`, and `claude plugin validate . --strict` if you have Claude Code. If you change a `git-guard.sh` rule, add a test case for it.
5. Open a Pull Request against `main` explaining what changes, why, and how you tested it. The author reviews and merges it; `main` is protected and only takes changes through PRs.

**Rules:** no secrets or real data (use fake values; mark fake data that looks like a secret with `secret-scan:allow`); no AI co-authorship or attribution in commits (you may use AI assistants, but you sign the commit and answer for the change); don't remove or alter the authorship and license notices; keep the skills generic; contribute only content you wrote yourself.

**License of your contributions:** by submitting a contribution you agree that it is published under [CC BY-NC-SA 4.0](LICENSE) with the same [additional permission for commercial use](PERMISO-ADICIONAL.md#additional-permission-for-commercial-use-english) as the rest of the repository (free to use, including in paid work, but not to be sold), and that you have the right to contribute it because you wrote it. Your authorship is recorded in the commit history.
