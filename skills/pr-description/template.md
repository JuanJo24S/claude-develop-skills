<!--
PULL REQUEST TEMPLATE
Filling rules:
- Headings stay as they are. All content in Spanish (except code names, branches, variables and endpoints).
- Sections marked (opcional) are REMOVED entirely when they don't apply; never leave "N/A" or empty sections.
- No mentions of or attribution to AI assistants.
- Remove every <!-- --> comment before delivering the document.
-->

# <tipo>(<alcance>): <título descriptivo en español>

| | |
|---|---|
| **Rama** | `<type>/<description>` → `main` |
| **Tipo de cambio** | Nueva funcionalidad · Corrección · Refactor · Documentación · Mantenimiento |
| **Módulo(s) / servicio(s)** | `<módulo o servicio>` |
| **Impacto** | 🟢 Bajo · 🟡 Medio · 🔴 Alto |
| **Issue / tarea** | #<número> o enlace (opcional) |

## Contexto

<!-- 3–6 lines. Answer: what problem or need existed? Why now? What was the previous behavior? -->

## Cambios

<!-- List grouped by module or service. Describe behavior, not lines of code. -->

### `<module-or-service>`
- <cambio 1>
- <cambio 2>

## Cambios de nombres (opcional)

<!--
Use when renaming variables, functions, classes, files, columns, tables, layers, endpoints or environment variables.
One row per rename, in the order they appear in the code. With several categories, one subheading per category.
-->

### <Categoría: Variables | Funciones | Columnas | Tablas | Archivos | Endpoints>

| Antes | Después |
|---|---|
| `<old_name>` | `<new_name>` |

## Variables de entorno y configuración (opcional)

| Variable | Estado | Descripción | Valor de ejemplo |
|---|---|---|---|
| `<NAME>` | Nueva · Modificada · Eliminada | <para qué sirve> | `<example, no secrets>` |

## Cambios en contratos / API (opcional)

<!-- New, modified or removed endpoints, events or schemas. State whether the change is breaking. -->

| Método | Endpoint / evento | Cambio | ¿Incompatible? |
|---|---|---|---|
| `POST` | `/v1/...` | <descripción> | Sí / No |

## Base de datos y migraciones (opcional)

- Migración: `<file>` — <qué hace>
- ¿Es reversible? Sí / No — <cómo revertir>
- ¿Requiere carga o transformación de datos existentes? <detalle>

## Dependencias (opcional)

| Paquete | Versión | Motivo |
|---|---|---|
| `<package>` | `<x.y.z>` | <por qué se agrega o actualiza> |

## Decisiones técnicas

<!-- Chosen pattern or approach, why, and discarded alternatives when they add context. -->
- <decisión> — <justificación>

## ⚠️ Puntos de atención para la revisión

<!-- What the lead developer MUST look at: risks, breaking changes, security, performance, sensitive areas, detected TODOs. -->
- <punto>

## 🔎 Alertas de revisión (opcional)

<!--
Informative, non-blocking alerts: PR size (> ~400 lines), out-of-scope files, test gaps, unresolved self-review findings.
Calm, neutral tone; one line each, starting with ℹ️ and including the reason.
-->

> Son avisos informativos, no errores: solo indican dónde conviene revisar con un poco más de atención.

- ℹ️ <alerta> — <motivo>

## Autorevisión

<!-- One or two lines: what was reviewed and the result. Fixes are already folded into their original commits, so describe them briefly without listing fix commits. Pending findings go to "Alertas de revisión". -->
- <qué se revisó y qué se corrigió>

## Cómo probar

1. <preparación: comandos, variables necesarias, datos de prueba>
2. <acción: endpoint, payload o pasos>
3. **Resultado esperado:** <qué se debe observar>

## Fuera de alcance / pendientes (opcional)

<!-- What this PR deliberately does NOT include and is left for later. -->
- <pendiente>

## Checklist

<!-- Tick only what was actually verified. -->
- [ ] Compila y los tests pasan
- [ ] Tests nuevos o actualizados para el comportamiento cambiado
- [ ] Autorevisión realizada y hallazgos corregidos o reportados
- [ ] Escaneo de secretos sin hallazgos; `.env` ignorado por Git
- [ ] Credenciales y configuración leídas desde variables de entorno
- [ ] Variables de entorno nuevas documentadas en `.env.example`
- [ ] Cambios limitados al alcance de la tarea
- [ ] Documentación actualizada (README, OpenAPI, etc.)
- [ ] Sin código comentado, logs de depuración ni TODOs sin justificar

## Commits incluidos

- `<hash>` <mensaje>
