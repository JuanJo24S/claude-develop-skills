# Guía de integración de Wompi (Colombia)

Escrita el 2026-10-02 a partir de la documentación oficial de Wompi, sus reglamentos, las reglas de PCI y de Visa, para
un comercio que cobra suscripciones o servicios con tarjeta y Nequi. Es una guía técnica y de producto: **no es
asesoría legal**. Wompi cambia: confirma en https://docs.wompi.co/docs/colombia/ lo que vayas a usar.

**Convenciones**

- Las citas entre corchetes ([D2], [C1]…) remiten a la lista de fuentes de la sección 4.
- «Documentado» = está en docs.wompi.co (Colombia) o en un documento oficial de Wompi.
- «Observado en el código de Wompi» = leído en el JavaScript público que Wompi sirve (`widget.js`, el bundle del
  checkout, Wompi JS). **No está documentado**, puede cambiar sin aviso y hay que confirmarlo en el sandbox.
- «No encontrado en la documentación» = se buscó y no está; no se afirma.

## Resumen en una página

1. **Recomendación: usar el widget de Wompi en modo tokenización** (`widgetOperation: 'tokenize'`) para registrar la
   tarjeta o la cuenta Nequi, y **descartar el formulario propio**. Wompi lo documenta en «Fuentes de pago &
   Tokenización» [D2]: el widget abre un iframe de `checkout.wompi.co`, el pagador escribe ahí la tarjeta (o su
   celular Nequi y acepta en la app) y la web recibe solo un token, que el backend convierte en fuente de pago con la
   llave privada.
2. **Por qué:** con el formulario propio el número y el CVC pasan por el DOM y el JavaScript del comercio (su framework, sus
   dependencias, el SDK de errores, otros scripts del mismo origen). Eso deja al comercio, según el PCI SSC, en el
   cuestionario **SAQ A-EP** (unos 140 requisitos) y con el riesgo de *skimming*; con el iframe de Wompi el cuestionario
   esperable es **SAQ A** (unos 24 requisitos, más el criterio nuevo de protección contra scripts) [P1][P2]. Wompi no
   dice en su documentación qué SAQ exige: hay que preguntárselo.
3. **Obligaciones que sí impone Wompi** (documentación y Reglamento de Comercios): pedir al pagador la **aceptación
   explícita** de dos documentos de Wompi (reglamento de pagadores y autorización de datos personales) con los enlaces
   que da la API, y enviar sus dos tokens al crear la fuente de pago [D3]; tener esos dos documentos **siempre
   disponibles** donde se integra el API o el checkout [C1 §5]; **no guardar datos de tarjeta** [D4][C1 §12];
   llaves privadas y secretos solo en el servidor [D1][D2]; validar los eventos con su checksum y no confiar en la
   redirección [D1][D6]; informar con claridad la política de reembolsos [C1 §12]; decir al pagador que el comercio cobra
   y que Wompi solo procesa el pago [C1 §2.2.8]; responder contracargos y reversiones con soportes en 5 días hábiles y
   conservarlos 12 meses [C1 §6.9.5, §12].
4. **Regla de las franquicias, fuera de Wompi:** la política de Visa para pruebas gratuitas que pasan a suscripción (aplica a
   LAC) pide consentimiento expreso, copia electrónica de las condiciones al inscribirse, **recordatorio al menos 7 días
   antes** del primer cobro tras la prueba o de un cobro con condiciones distintas (p. ej. una bajada) y cancelación
   en línea fácil [V1].
5. **CSP:** `frame-src https://checkout.wompi.co`; en `script-src`, `https://checkout.wompi.co` y los dos
   scripts antifraude que inyecta el widget (`https://cdn.siftscience.com`, `https://device.clearsale.com.br`) como
   respaldo de `'strict-dynamic'`; `connect-src` no necesita Wompi con el widget. Los dominios de los scripts
   antifraude están observados en el código, no documentados.

---

## 1. Captura de la tarjeta y de Nequi para el cobro recurrente

### 1.1 Las tres vías que ofrece Wompi

| Vía | Qué hace | Sirve para cobro recurrente | Fuente |
|---|---|---|---|
| **Widget en modo tokenización** | Iframe de Wompi que pide la tarjeta (o Nequi) y devuelve un token para crear la fuente de pago desde el servidor. | Sí | [D2] sección final «Widget en modo de tokenización» |
| **API de tokenización** (`POST /v1/tokens/cards`, `POST /v1/tokens/nequi`) | El comercio construye su formulario y envía los datos a Wompi con la llave pública (con la tarjeta cifrada en JWE, que es lo que Wompi recomienda por defecto, o en claro). | Sí | [D4] «Tokeniza una tarjeta»; [D2] «Cuentas Nequi» |
| Widget o Web Checkout en modo compra | Cobra una vez (transacción), no crea fuente de pago. | No (para esto) | [D1] |

El Web Checkout (redirección) **no** tiene modo tokenización: observado en el código de Wompi, la operación
`tokenize` solo es válida en modo widget («Operación inválida en modo widget» para otros valores) [S2].

### 1.2 Widget en modo tokenización

**Documentado** [D2]: «Puedes integrar nuestro Widget en modo tokenización para que puedas guardar la información de
tus usuarios de forma más rápida y segura», con este ejemplo:

```html
<form method="POST" action="/process_token">
  <script src="https://checkout.wompi.co/widget.js"
          data-render="button"
          data-widget-operation="tokenize"
          data-public-key="pub_test_…"></script>
</form>
```

y «Con el token dentro de la respuesta debes hacer un POST a /v1/payment_sources desde tu servidor y usando tu llave
privada de comercio». La página de transporte `postMessage` confirma que el widget tiene dos modos, «compra y
tokenización», y que ambos funcionan con los dos transportes [D11]. La página de fuentes de pago también anuncia que
Wompi «planea facilitar el proceso pronto, ofreciendo realizar el primer paso a través de nuestro Widget» [D2].

**No documentado y observado en el código de Wompi** (confirmar en el sandbox registrando el objeto completo):

- En JavaScript (sin botón) se configura con `new WidgetCheckout({ publicKey, widgetOperation: 'tokenize' })` y
  `checkout.open(callback)`; en modo tokenización la única obligatoria es `publicKey` (`configAsTokenize`) [S1].
  Acepta también `bootstrapTransport: 'postmessage'` para que la configuración no viaje en la URL del iframe [D11].
- Con el botón y sin callback, el widget añade al `<form>` los campos ocultos `payment_source_token` y
  `payment_source_type` y lo envía por POST [S1]. En una SPA conviene el callback.
- El callback recibe `{ payment_source: … }` [S1]. El checkout arma ese objeto así [S2]:
  - tarjeta: `{ token: 'tok_…', type: 'CARD', cardHolder, lastFour, brand, name }`; <!-- secret-scan:allow: marcador de posición, no es un token -->
  - Nequi: `{ token: 'nequi_…', type: 'NEQUI', phoneNumber }`, **después** de que el token de Nequi llegue a su estado <!-- secret-scan:allow: marcador de posición, no es un token -->
    final (el propio widget espera la aceptación en la app; `checkNequiTokenForFinalStatus`).
- El widget tokeniza la tarjeta **cifrada** (JWE con la llave pública de Wompi) contra `api.wompi.co` /
  `api-sandbox.wompi.co` desde su iframe [S2]: exactamente lo que Wompi recomienda en [D4].
- Si la persona cierra el widget (Esc, «volver al comercio»), el modal se cierra **sin llamar al callback** [S1]: la
  web no debe quedarse esperando.
- El widget **no devuelve tokens de aceptación**: los documentos de Wompi y sus tokens los sigue pidiendo el comercio (ver
  2.1). El checkout tiene un componente con las casillas de esos documentos (`presignedAcceptance`,
  `presignedPersonalDataAuth`, con una opción `hideChecks`), pero no confirmé si lo muestra en modo tokenización [S2].
- Qué medios aparecen en el widget (tarjeta, Nequi) depende de lo que tenga activo la cuenta de comercio: **no
  encontrado en la documentación**; verificar en el sandbox.

### 1.3 Formulario propio con `POST /tokens/*` (desaconsejado)

- Está **documentado y permitido** por Wompi [D4][D2]: no es ilegal en sí. Para tarjetas, Wompi recomienda por defecto
  cifrar con JWE (`GET /v1/tokens/keys/tokenization`, RSA-OAEP-256 + A256GCM) y deja la tokenización en claro solo
  «si no puedes cifrar la información» [D4].
- El número, la fecha y el CVC existen en el DOM y en la memoria del JavaScript del comercio hasta que Wompi responde.
  Cualquier script de la página (una dependencia npm comprometida, un XSS, el SDK de errores si captura entradas o
  *breadcrumbs*, un script de terceros) puede leerlos.
- Además obliga a mantener validaciones, mensajes de error por campo, el sondeo de Nequi y la accesibilidad del
  formulario, que el widget ya resuelve.

### 1.4 PCI DSS y responsabilidad

Wompi dice que «cuenta con una certificación PCI DSS para el manejo, transmisión y procesamiento seguro de datos de
tarjeta, de manera que ningún comercio deba guardar estos datos, usando únicamente los tokens seguros generados»
[D4]. **No encontrado en la documentación:** qué cuestionario (SAQ) o validación PCI exige Wompi a sus comercios. Lo
que sigue sale del PCI SSC, no de Wompi:

| | Widget (iframe de `checkout.wompi.co`) | Formulario propio + `POST /tokens/cards` |
|---|---|---|
| Quién ve número y CVC | Solo Wompi (iframe de otro origen) | La página y el JavaScript del comercio antes de llegar a Wompi |
| Cuestionario esperable | **SAQ A**: comercio que externaliza toda la captura en un iframe de un TPSP PCI DSS. Desde PCI DSS v4.0.1 (vigente el 1-abr-2025, FAQ 1588) se quitaron de SAQ A los requisitos 6.4.3, 11.6.1 y 12.3.1 y se añadió un criterio: el comercio confirma que su sitio no es susceptible a ataques de scripts, protegiendo él la página (técnicas de 6.4.3 y 11.6.1: inventario y autorización de scripts, detección de cambios) **o** con la confirmación del TPSP de que su solución «incluye técnicas que protegen la página de pagos de ataques de scripts» [P1] | **SAQ A-EP**: «el sitio de comercio electrónico del comercio no recibe datos de cuenta pero controla cómo los clientes, o sus datos de cuenta, se redirigen a un TPSP/procesador» [P2]; unos 140 requisitos (incluye escaneos ASV trimestrales y pruebas de penetración) |
| Riesgo principal | Que alguien sustituya el script del widget en nuestra página | *Skimming* tipo Magecart, XSS, dependencias o SDKs que lean los campos |
| Mantenimiento | Bajo (Wompi valida la tarjeta, la cifra y espera la aceptación de Nequi) | Alto |
| Responsabilidad ante Wompi | La misma base contractual, con mucha menos superficie de incidente | Un incidente en nuestro sitio activa el deber de indemnizar multas y pérdidas y la auditoría externa que Wompi puede exigir [C1 §13.1, §13.2], la indemnidad [C1 §17.4] y la posible cancelación de la cuenta |

En ambas opciones, el riesgo de fraude y las reclamaciones en ventas no presentes los asume el comercio [C1 §6.9.2].

### 1.5 Recomendación

**Widget de Wompi en modo tokenización para tarjeta y Nequi**, abierto desde la web del comercio con la llave pública, y
creación de la fuente de pago en el backend con la llave privada. Motivos: (1) el comercio nunca toca el número ni el CVC y su
alcance PCI queda en lo mínimo; (2) es una integración documentada por Wompi [D2]; (3) el widget ya cifra la tarjeta
como Wompi recomienda y gestiona la espera de Nequi; (4) el backend solo recibe un token. Lo pendiente: pedir a Wompi el SAQ que
espera y su confirmación del criterio de scripts [P1], y mantener la CSP (sección 3.1) como protección de la página.

---

## 2. Obligaciones legales y de producto

### 2.1 Impuestas o recomendadas por la documentación técnica de Wompi

| # | Obligación | Fuente |
|---|---|---|
| 1 | **Dos tokens de aceptación** obligatorios al crear transacciones y fuentes de pago: `acceptance_token` (reglamento o política, tipo `END_USER_POLICY`) y `accept_personal_auth` (autorización de datos personales, `PERSONAL_DATA_AUTH`), «cumpliendo con la regulación colombiana y la ley de Habeas data». | [D3]; [D2] «Cambio importante en el API» |
| 2 | Obtenerlos de `GET /merchants/info` con la cabecera `x-merchant-public-key`. `GET /merchants/:llave` deja de existir el **31-oct-2026**. | [D3] |
| 3 | **Mostrar los enlaces** (`permalink`) de ambos documentos y que el usuario **acepte explícitamente** que los leyó, «a través de checkboxes por ejemplo», **y acto seguido** enviar los tokens. Pasos: obtener tokens, mostrar enlaces, aceptación explícita, enviar. | [D3] |
| 4 | Casillas **sin marcar**: Wompi no lo dice con esas palabras, pero pide que el usuario «acepte explícitamente» y que «una vez que el usuario haya activado cada checkbox, se confirma». Una casilla premarcada no es una aceptación explícita. | [D3] (inferencia) |
| 5 | ¿Guardar la aceptación? **No encontrado en la documentación**: Wompi no pide al comercio guardar nada; el token prefirmado identifica el documento (su payload trae `contract_id`, `permalink`, `file_hash` y una expiración). | [D3] (ejemplos decodificados) |
| 6 | Vigencia de los tokens: **no documentada**. En el token de ejemplo de [D14], `exp` es 1 hora después de su emisión. | [D14] (inferencia) |
| 7 | **Nunca guardar datos sensibles** de tarjetas, Nequi o DaviPlata: «podrías enfrentar sanciones y problemas legales». | [D2]; [D4] |
| 8 | Crear fuentes de pago y transacciones **solo desde el servidor** con la llave privada; «nunca» desde el navegador. | [D2] Paso 2 y 3; [D9] |
| 9 | Firma de integridad SHA-256 de referencia + centavos + moneda (+ expiración) + secreto, generada **en el servidor**. | [D1] Paso 3; [C4] |
| 10 | Referencia **única** por transacción (no reutilizable). | [D1] Paso 2; [D5] |
| 11 | Usar **eventos** (`transaction.updated`) para conocer el resultado; no validar con la redirección; verificar el checksum (propiedades + `timestamp` + secreto de eventos); responder **HTTP 200**; Wompi reintenta 3 veces en 24 h (30 min, 3 h, 24 h); URL de eventos distinta por ambiente; HTTPS. | [D1] Paso 7; [D6] |
| 12 | Consultar transacciones **solo con la llave privada** (con la pública: 404). | [D5]; [D12]; [D17] |
| 13 | **No usar un token de tarjeta más de dos veces**; para varios cobros, fuentes de pago. | [D4] |
| 14 | Con tarjeta, enviar `installments` (cuotas) y, para Visa/Mastercard con procesador RBM, `recurrent`: `true` si el titular autoriza cobros **del mismo monto de forma periódica**, `false` si son montos distintos sin periodicidad (COF). Si no aplica, la transacción va sin COF. | [D2] «Transacciones con COF» |
| 15 | Nequi: el token queda `PENDING` hasta que el cliente acepta la suscripción en su celular; solo con `APPROVED` se crea la fuente. Recordar al cliente que necesita la app. Hay evento `nequi_token.updated`. | [D2] «Cuentas Nequi»; [D4] «Nequi»; [D6] |
| 16 | Wompi JS (`$wompi.initialize` → `sessionId`, `deviceID`) recomendado en la página donde se crean transacciones o fuentes de pago, para antifraude; el `session_id` se envía al crear la fuente desde el backend. Recomendado, no obligatorio. | [D9]; [D10] (versión antigua, deprecada) |
| 17 | Recomendado: HTTPS en el sitio; capturar la **IP** del pagador (`ip`) para antifraude y trazabilidad, en el servidor y con `X-Forwarded-For` bien configurado; guardar id, referencia, estado, monto, método, IP y fecha de cada transacción. | [D1]; [D5] «Trazabilidad y Seguridad», «Mejores prácticas» |
| 18 | Impuestos opcionales e informativos (`taxes`: `VAT`, `CONSUMPTION`); no se suman al total. | [D16]; [D1] Paso 5 |
| 19 | Wompi envía por **correo** el resultado de cada transacción al pagador (`customer_email`) y al comercio. | [D12]; [C2 §3.7] |
| 20 | 3DS en fuentes de pago: **opcional y bajo solicitud** al equipo de fraude; si se activa, la fuente nace `PENDING` y el comercio debe sondearla y renderizar el *challenge* del banco; da protección 3RI a los cobros automáticos (3RI solo Mastercard). | [D14]; [D15] |

### 2.2 Impuestas por el Reglamento de Comercios de Wompi (contrato, versión V4-2026) [C1]

| Sección | Qué dice (resumen fiel) |
|---|---|
| §5 Herramientas de acceso: **API** y **Checkout** | «Si usas esta herramienta te obligas a garantizar que en este espacio se encuentre **siempre disponible** los Términos y Condiciones de Pagadores de WOMPI y las Autorizaciones para el Tratamiento de Datos Personales de WOMPI». Además, al usar el API «aceptas los términos y condiciones/reglamentos especiales del uso de la API de WOMPI» publicados en wompi.co. |
| §2.2.8 | El comercio actúa en nombre propio y debe «comunicarles [a los pagadores] cuál es tu calidad y la de WOMPI». |
| §2.1.13 | «Las transacciones realizadas con las franquicias Visa y MasterCard, se procesarán utilizando la autenticación 3DSecure», sin garantía de aprobación. |
| §6.9.2 | En ventas no presentes, el riesgo de fraude y las reclamaciones del titular los asume el comercio. |
| §6.9.5 | Wompi puede pedir los soportes de una transacción; hay que entregarlos en **5 días hábiles** o reintegrar lo reclamado. |
| §6.10 | **Reversión** del pago (ventas no presentes): la gestiona el comercio; si prospera, Wompi la descuenta. |
| §6.11 | **Reembolso** desde la cuenta Wompi; Wompi no garantiza que salga y puede cobrar un costo adicional. |
| §6.8 | Fondo de reserva de hasta el 15 % en actividades de alto riesgo o más de 50.000 USD/mes. |
| §7.3 | En **Gateway**, contracargos, reversiones y reembolsos se gestionan directamente con la entidad adquirente. |
| §12 | Entregar recibo o **factura** según la ley; **no almacenar** datos de la transacción o la tarjeta salvo requerimiento; no usar datos de los pagadores para otros fines; **conservar 12 meses** los soportes; **informar con claridad la política de devolución o reembolso**; cumplir la protección al consumidor; proteger sistemas y contraseñas; prácticas razonables de seguridad y privacidad; aplicar actualizaciones y parches. |
| §13.1, §13.2 | Indemnizar multas y pérdidas por incumplir las reglas de seguridad y fraude; ante sospecha de brecha, auditoría externa aprobada por Wompi; posible cancelación. |
| §14.1 | Prohibido usar los Servicios en nombre de un tercero sin autorización. |
| §16 | Wompi trata como **responsable** los datos que recibe por API o tokenización y no está obligado a devolverlos al comercio. |
| §17.4 | Indemnidad, incluidos fraudes por suplantación e incumplimientos del Estatuto del Consumidor frente a los pagadores. |

### 2.3 Lo que acepta el pagador: Reglamento de Pagadores [C2] (documento `END_USER_POLICY`)

El enlace que hoy devuelve la API apunta a `reglamento-Usuarios-Colombia.pdf` (en el token de ejemplo de [D14]; en el
de [D3] aparece uno anterior). Puntos que conviene que el comercio no contradiga en sus textos: Wompi **no es parte** del
contrato entre el pagador y el comercio ni garantiza el servicio (§2.7, §2.8); puede rechazar o reversar pagos que
crea no autorizados (§3.8); puede notificar el resultado al correo del pagador (§3.7); las controversias se tramitan
entre el emisor y el comercio, y el comercio debe atenderlas (§10); el pagador «podrá retractarse de ciertas compras»
avisando al comercio y al emisor dentro de los cinco días siguientes (§10); Wompi trata los datos del pagador
como responsable (§7). La **autorización de datos personales** (`autorizacion-administracion-datos-personales.pdf`)
**no la pude leer**: el servidor de Wompi responde 403 a las descargas automáticas. Su texto parece coincidir con el
§7 del reglamento de pagadores, pero no lo afirmo.

### 2.4 Cobros recurrentes: lo que dice y lo que no dice Wompi

- **Dice:** las fuentes de pago permiten cobrar «sin su intervención directa», p. ej. «un cobro periódico» [D2]; el
  marcado COF `recurrent` (punto 14 de 2.1); con 3DS en la fuente, los cobros automáticos quedan bajo 3RI [D14].
- **No encontrado en la documentación de Wompi:** avisos previos al pagador antes de cada cobro, plazos de reintento,
  límites de reintentos de un cobro rechazado, reglas de mora o la forma de cancelar una suscripción con tarjeta o
  Nequi. La anulación de una fuente (`PUT /v1/payment_sources/{id}/void`) solo está documentada para DaviPlata y
  Bancolombia [D2].
- **Reglas de la franquicia (no de Wompi), Visa** [V1], vigente desde el 18-abr-2020 para AP, Canadá, CEMEA, **LAC** y
  EE. UU., para comercios con prueba gratuita u oferta introductoria que pasa a suscripción:
  - consentimiento **expreso** a la suscripción al inscribirse;
  - **copia electrónica** (correo o SMS) de las condiciones al inscribirse, aunque no se cobre nada: que acepta una
    suscripción salvo que cancele, fecha de inicio, el servicio, monto y frecuencia o fecha de cobro, y un enlace para
    cancelar en línea;
  - **recordatorio al menos 7 días antes** de un cobro recurrente si terminó la prueba o la oferta, o si cambió la
    naturaleza del acuerdo (p. ej. precio o periodicidad), con enlace para cancelar;
  - en el comprobante: duración de la prueba, aviso de que se cobrará salvo que cancele, monto y fecha del primer cobro
    y de los siguientes, y el enlace de cancelación;
  - **cancelación en línea fácil**, «similar a darse de baja de una lista de correo».
  Aplica cuando el pagador paga con Visa; confirmar con Wompi si Mastercard u otras franquicias exigen algo
  equivalente (**no encontrado**).

### 2.5 Reembolsos, anulaciones, reversiones y contracargos

- **Anulación (void):** `POST /v1/transactions/{id}/void` con llave privada, solo tarjetas y «solo disponible para
  ciertos estados» [D5]; el estado `VOIDED` solo existe para tarjetas [D4][D5].
- **Reembolsos V2:** `POST /v1/refunds` con llave privada, totales o parciales, con motivo y hasta 5 referencias; en el
  sandbox se simulan `approved`, `declined`, `error` y `cancelled` con `test_scenario` [D8]. La versión anterior era
  `POST /v1/transactions/:id/refunds`. Por contrato, Wompi no garantiza el éxito y puede cobrar un costo [C1 §6.11].
- **Reversión y contracargos:** procedimientos entre el emisor, el adquirente y el comercio; el comercio los gestiona,
  entrega soportes en 5 días hábiles y asume lo que prospere [C1 §6.9, §6.10, §6.12, §7.3]; [C2 §10].
- **Reintento de pago** [D19] es una función del checkout (el pagador reintenta con otro medio en 3 minutos); no tiene
  que ver con los reintentos automáticos que haga el backend.
- **Política de reembolsos del comercio** (por ejemplo «sin reembolsos al cancelar»): debe estar clara antes de
  aceptar [C1 §12]; su validez frente al retracto se revisa con un abogado (2.7).

### 2.6 Marca Wompi

- Mostrar el logo de Wompi **no es obligatorio**: no encontrado en la documentación ni en la página de recursos
  gráficos [C3].
- Si se muestra: solo las versiones oficiales descargables, al menos 40 px de distancia con otros elementos, sin
  alterar proporciones ni espacios; colores oficiales en [C3]. La marca es propiedad de Wompi [C1 §17.5].
- El botón que pinta el propio widget dice «Paga con **Wompi**» en compra y «Guarda tu **método de pago**» en
  tokenización [S1]; con botón propio, basta con nombrar a Wompi en el texto (§2.2.8).

### 2.7 A revisar con un abogado — Colombia

Señalado para la revisión, sin afirmar conclusiones:

1. **¿El pagador (una empresa) es «consumidor»?** La Ley 1480 de 2011 (art. 5) protege a quien adquiere un producto como
   destinatario final para una necesidad propia, privada, familiar, doméstica **y empresarial cuando no esté ligada
   intrínsecamente a su actividad económica**. Un servicio que la empresa usa para su negocio podría estar
   ligado a su actividad: de eso dependen el retracto, la reversión y los deberes de información. Wompi, en su
   contrato, trata la reversión como un riesgo de las ventas no presentes [C1 §6.10] y, en el capítulo de venta
   presente, pide aceptar que se apliquen las normas de reversión a las ventas no presentes [C1 §9.8].
2. **Información previa y comercio electrónico** (Ley 1480, arts. 23 y 50): identidad del comercio (razón social, NIT,
   dirección, contacto), precio total con IVA, periodicidad, fecha del primer cobro y fin de la prueba, renovación automática, cómo cancelar, sin reembolsos, reintentos y suspensión; resumen antes de
   confirmar y constancia después.
3. **Retracto** (art. 47, 5 días hábiles en ventas a distancia, con excepciones como los servicios que empezaron a
   prestarse con acuerdo del consumidor) frente a «sin reembolsos». El reglamento de pagadores de Wompi lo menciona
   [C2 §10].
4. **Reversión del pago** (art. 51 de la Ley 1480 y su reglamentación, Decreto 587 de 2016 compilado en el Decreto
   1074 de 2015): ventas no presenciales pagadas con tarjeta u otros medios electrónicos, por fraude, operación no
   solicitada, producto no recibido o que no corresponde; plazo de 5 días hábiles. Definir el proceso interno.
5. **Renovación automática y cancelación:** validez de la cláusula en un contrato de adhesión (régimen de cláusulas
   abusivas, arts. 42 y 43), si debe ofrecerse cancelar por el mismo medio de contratación y con qué antelación
   avisar. Las reglas de Visa (2.4) ya piden aviso de 7 días tras la prueba y cancelación en línea.
6. **Validez de la aceptación electrónica** (Ley 527 de 1999) y qué evidencia guardar: versión, fecha, usuario, IP.
7. **Datos personales** (Ley 1581 de 2012, Decreto 1377 de 2013, hoy en el Decreto 1074 de 2015): aplica a los
   pagadores persona natural y a los datos de contacto de las personas jurídicas; autorización previa, expresa e
   informada para los fines propios del comercio (cobro, avisos, conciliación); **conservar prueba de la autorización**
   (art. 17, lit. b); política y aviso de privacidad que nombren a Wompi como responsable independiente de los datos
   que recibe [C1 §16]; si aplica el RNBD.
8. **Cobranza y mora:** posible aplicación de la Ley 2300 de 2023 (horarios, canales y frecuencia de contacto en
   gestiones de cobranza) a los avisos de cobro rechazado y mora; y, **solo si** se reportara la mora a centrales de
   riesgo, la Ley 1266 de 2008 (modificada por la Ley 2157 de 2021).
9. **Factura electrónica DIAN** por cada cobro; además Wompi exige entregar recibo o factura [C1 §12].
10. **Términos especiales de uso del API de Wompi** [C1 §5]: conseguirlos y revisarlos.

---

## 3. Integración web

### 3.1 CSP

Con una CSP basada en `'strict-dynamic'` (hashes o nonces), un script que inserta otro script de confianza también es
de confianza: por eso `widget.js` debe insertarse desde el código, no con un `<script>` fijo en el HTML. Los scripts
que a su vez inserta `widget.js` (Sift y ClearSale, observados en [S1]) heredan esa confianza. Las listas de orígenes
solo las usan los navegadores sin `'strict-dynamic'`.

| Directiva | Añadir | Por qué |
|---|---|---|
| `script-src` | `https://checkout.wompi.co https://cdn.siftscience.com https://device.clearsale.com.br` | Respaldo para navegadores sin `'strict-dynamic'`. Los dos últimos están **observados** en `widget.js` (antifraude que el widget inyecta en nuestra página) [S1], no documentados. |
| `frame-src` | `https://checkout.wompi.co` | El iframe del widget (`https://checkout.wompi.co/p/…`) [S1]. |
| `connect-src` | Nada para Wompi | Con el widget, las llamadas al API las hace el iframe, bajo la CSP de Wompi. Sift y ClearSale sí conectarán desde nuestra página a orígenes **no documentados**: añadir lo que muestren los informes de GlitchTip antes de pasar la política a obligatoria. |
| `img-src` | Lo que muestren los informes | Posibles píxeles de Sift o ClearSale (no confirmado). |
| `style-src` | Nada | El widget crea un `<style>` y usa `insertRule` [S1]; ya se permite `'unsafe-inline'`. |
| `form-action` | Nada | En modo callback el widget no envía formularios en nuestra página. |
| `frame-ancestors`, `X-Frame-Options` | Nada | Limitan quién nos enmarca, no lo que enmarcamos. |

Si algún día se adopta Wompi JS: `script-src https://wompijs.wompi.com` y `connect-src https://api.wompi.co
https://api-sandbox.wompi.co`, más los orígenes de FingerprintJS que muestren los informes (en el código aparecen
`m1.openfpcdn.io` y `fpjs.dev`) [S3]. Para el criterio de scripts de SAQ A [P1], llevar un inventario de los scripts
que carga la ruta del registro del medio de pago y no cargar ahí scripts de terceros que no hagan falta (p. ej. Google
Maps).

### 3.2 Pruebas con el sandbox

**Preparación.** Llaves `pub_test_…`, `prv_test_…`, `test_events_…` y `test_integrity_…` en el `.env` (nunca en el
repositorio); la web toma la llave pública de la configuración. En el panel de comercios, la URL de eventos del sandbox
apunta al webhook público del backend; en local Wompi no alcanza `localhost`, así que el resultado debe llegar por una
consulta de la transacción por su referencia (conciliación).

**Datos de prueba** [D7]:

| Medio | Dato | Resultado |
|---|---|---|
| Tarjeta | `4242 4242 4242 4242`, fecha futura, CVC de 3 dígitos | Aprobada (verificado en la prueba de humo) |
| Tarjeta | `4111 1111 1111 1111`, fecha futura, CVC de 3 dígitos | Rechazada en el cobro (verificado): sirve para probar rechazos |
| Tarjeta | Cualquier otra | `ERROR` |
| Nequi | `3991111111` | Token aprobado y cobro aprobado (verificado) |
| Nequi | `3992222222` | Cobro rechazado (documentado para transacciones; para el token, no verificado) |
| Nequi | Cualquier otro | `ERROR` |
| Tarjeta 3DS (solo si se activa 3DS en fuentes) | `2303 7799 5100 0446` (challenge), `…0354` (error de autenticación), `…0347` (versión no soportada) | Ver [D15] |
| Reembolso V2 | `test_scenario`: `approved`, `declined`, `error`, `cancelled` | Ver [D8] |

**Casos manuales** (el iframe es de otro origen: se prueban a mano o con `frameLocator` de Playwright fuera de CI):

1. Sin marcar las casillas de los documentos de Wompi, el botón no abre el widget y señala lo que falta.
2. Tarjeta 4242: registra el medio (y cobra, si el flujo cobra en el acto).
3. Tarjeta 4111: registra el medio y el cobro se rechaza; la pantalla lo explica y deja reintentar.
4. Nequi 3991111111: el widget espera la aceptación en la app y registra el celular enmascarado.
5. Cerrar el widget sin terminar: la pantalla vuelve al estado inicial y se puede abrir de nuevo.
6. Cambiar el medio: el nuevo reemplaza al anterior.
7. Documentos de Wompi distintos entre la primera y la segunda consulta (simulado con un *stub*): se piden de nuevo.
8. Revisar en el panel del sandbox que cada transacción lleva su referencia única.
9. Registrar una sola vez el objeto completo del callback para confirmar su forma (no trae datos de la tarjeta) y
   quitar ese registro después.
10. Revisar los informes de la CSP tras los casos 2 a 4.

**Tests unitarios** (sin red): el servicio que carga el widget con un `WidgetCheckout` falso (carga única del script,
traducción de tipos, tipo desconocido, sin callback) y el formulario (casillas obligatorias, nueva consulta de la
configuración, documentos cambiados, errores del backend y que no exista ningún `input` de tarjeta en el DOM).

### 3.3 Preguntas para el soporte de Wompi

1. ¿Qué validación PCI (SAQ) exigen al comercio con el widget en modo tokenización? ¿Confirman por escrito que su widget
   incluye técnicas que protegen la página de pagos de ataques de scripts (criterio de SAQ A, FAQ 1588)? [P1]
2. ¿La cuenta exige 3DS en la creación de fuentes de pago (Reglamento §2.1.13)?
3. ¿`acceptance_token` es obligatorio en `POST /transactions` con `payment_source_id` en producción?
4. ¿`PUT /v1/payment_sources/{id}/void` sirve para `CARD` y `NEQUI`?
5. Forma oficial del callback en modo tokenización y cómo saber que el usuario cerró el widget.
6. ¿El modo tokenización muestra sus propias casillas de aceptación? ¿Qué medios ofrece y de qué depende?
7. ¿Un cambio de monto en la renovación invalida el marcado `recurrent` (COF)?
8. ¿La cuenta es Agregador o Gateway? (contracargos, reserva, a quién reclamar) [C1 §6, §7]
9. Los «términos y condiciones/reglamentos especiales del uso de la API» que cita el Reglamento §5.
10. ¿Exigen avisos al tarjetahabiente antes de cobros recurrentes o tras una prueba gratuita, además de las reglas de
    Visa [V1]? ¿Qué orígenes necesitan en la CSP del comercio los scripts antifraude del widget?

---

## 4. Fuentes leídas

**Documentación de Wompi (Colombia)**, leída completa salvo lo marcado:

- [D1] Widget & Checkout Web — https://docs.wompi.co/docs/colombia/widget-checkout-web/
- [D2] Fuentes de pago & Tokenización (incluye «Transacciones con COF» y «Widget en modo de tokenización») — https://docs.wompi.co/docs/colombia/fuentes-de-pago/
- [D3] Tokens de aceptación — https://docs.wompi.co/docs/colombia/tokens-de-aceptacion/
- [D4] Métodos de pago (tarjetas, «Tokeniza una tarjeta», Nequi y demás) — https://docs.wompi.co/docs/colombia/metodos-de-pago/
- [D5] Transacciones — https://docs.wompi.co/docs/colombia/transacciones/
- [D6] Eventos — https://docs.wompi.co/docs/colombia/eventos/
- [D7] Datos de prueba en Sandbox — https://docs.wompi.co/docs/colombia/datos-de-prueba-en-sandbox/
- [D8] Reembolsos V2 (Sandbox) — https://docs.wompi.co/docs/colombia/reembolsos-sandbox/
- [D9] Wompi JS (versión vigente) — https://docs.wompi.co/docs/colombia/latest-version/
- [D10] Wompi JS (versión deprecada) — https://docs.wompi.co/docs/colombia/js/
- [D11] Transporte postMessage para el Widget — https://docs.wompi.co/docs/colombia/transporte-postmessage-widget/
- [D12] Seguimiento de transacciones — https://docs.wompi.co/docs/colombia/seguimiento-de-transacciones/
- [D13] Ambientes y llaves — https://docs.wompi.co/docs/colombia/ambientes-y-llaves/
- [D14] Transacciones automáticas con el protocolo 3RI (fuentes de pago con 3DS) — https://docs.wompi.co/docs/colombia/fuentes-de-pago-3ds/
- [D15] Fuentes de pago seguras con 3D Secure (Sandbox) — https://docs.wompi.co/docs/colombia/fuentes-de-pago-3ds-sandbox/
- [D16] Impuestos — https://docs.wompi.co/docs/colombia/impuestos/
- [D17] Errores en el API — https://docs.wompi.co/docs/colombia/errores/
- [D18] Inicio rápido — https://docs.wompi.co/docs/colombia/inicio-rapido/
- [D19] Reintento de pagos — https://docs.wompi.co/docs/colombia/reintento-de-pago/
- [D20] Preautorización & Captura — https://docs.wompi.co/docs/colombia/preautorizacion-captura/
- [D21] Transacciones con 3D Secure (Sandbox) v2 — https://docs.wompi.co/docs/colombia/transacciones-con-3d-secure-v2/
- [D22] Referencia del API — https://docs.wompi.co/docs/colombia/referencia/ → OpenAPI 1.2.0 en https://app.swaggerhub.com/apis-docs/waybox/wompi/1.2.0
- Hojeadas, fuera de alcance: https://docs.wompi.co/docs/colombia/integracion-3ds-externo/, https://docs.wompi.co/docs/colombia/cifrado-jwe-pse/, https://docs.wompi.co/docs/colombia/links-de-pago/, https://docs.wompi.co/docs/colombia/consultas-y-operaciones/ (pagos a terceros), https://docs.wompi.co/docs/colombia/roles/, https://docs.wompi.co/docs/colombia/usuarios/, https://docs.wompi.co/docs/colombia/reporte-recurrente/, https://docs.wompi.co/docs/colombia/reporte-unico/, https://docs.wompi.co/docs/colombia/conoce-nuestros-planes/.
- No leídas (no aplican): pagos a terceros, Bre-B y plugins de comercio electrónico.

**Documentos contractuales y de soporte de Wompi**

- [C1] Reglamento de Comercios Wompi, versión V4-2026 — https://wompi.com/assets/downloadble/reglamento-Comercios-Colombia.pdf
- [C2] Reglamento de uso para los Pagadores Wompi, v-1 (el `END_USER_POLICY`) — https://wompi.com/assets/downloadble/reglamento-Usuarios-Colombia.pdf
- [C3] Recursos gráficos (logo y reglas de uso) — https://wompi.com/es/co/desarrolladores/recursos-graficos
- [C4] Recomendaciones de seguridad WEBCHECKOUT — https://soporte.wompi.co/hc/es-419/articles/16593065375891-Recomendaciones-de-seguridad-WEBCHECKOUT
- [C5] Tips de seguridad (sus PDF adjuntos no se leyeron) — https://soporte.wompi.co/hc/es-419/articles/1500005290621-Tips-de-seguridad
- **No se pudieron leer** (el servidor responde 403 a las consultas automáticas): la autorización de datos personales
  https://wompi.com/assets/downloadble/autorizacion-administracion-datos-personales.pdf y los términos para comercios
  https://wompi.com/es/co/terminos-condiciones-comercios/. Leerlos desde un navegador.

**Código público de Wompi** (observado, no documentado)

- [S1] https://checkout.wompi.co/widget.js
- [S2] https://checkout.wompi.co/bundle.js (aplicación del checkout que se carga en el iframe)
- [S3] https://wompijs.wompi.com/libs/js/v1.js

**PCI SSC y franquicias**

- [P1] PCI SSC, «FAQ Clarifies New SAQ A Eligibility Criteria for E-Commerce Merchants» (FAQ 1588, 28-feb-2025) — https://blog.pcisecuritystandards.org/faq-clarifies-new-saq-a-eligibility-criteria-for-e-commerce-merchants
- [P2] PCI DSS v4.0 SAQ A-EP (criterio de elegibilidad, consultado por su texto citado en buscadores) — https://listings.pcisecuritystandards.org/documents/PCI-DSS-v4-0-SAQ-A-EP.pdf
- [V1] Visa, «Updated Policy for Subscription Merchants Offering Free Trials or Introductory Promotions» (vigente desde el 18-abr-2020; AP, Canadá, CEMEA, LAC, EE. UU.) — https://usa.visa.com/dam/VCOM/global/support-legal/documents/subscription-merchants-visa-public.pdf
