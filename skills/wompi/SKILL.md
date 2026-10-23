---
name: wompi
description: Integrate and operate Wompi (Colombia) payments - widget in tokenize and payment modes, payment sources, transactions with integrity signature, signed events, reconciliation, refunds, sandbox testing, keys, PCI and legal obligations - with the author's preferred defaults. Use before writing or changing anything that charges with Wompi, stores payment methods, handles the Wompi webhook, refunds, Wompi keys or the Wompi merchant panel.
license: CC-BY-NC-SA-4.0 with an additional permission (see LICENSE.md)
metadata:
  author: Juan Camacho (JuanJo24S)
  source: https://github.com/JuanJo24S/claude-develop-skills
---

# Wompi (Colombia)

Wompi (Bancolombia group) processes cards, Nequi and other Colombian payment methods in COP. This skill covers a
merchant that charges its own customers (subscriptions, services, one-off payments) from a web app and a backend.

## Sources (read the one you need, don't guess)

- [`references/guia-wompi.md`](references/guia-wompi.md) (Spanish), written 2026-10-02 from the official docs. Every
  claim cites its source. It covers:
  - the three capture options and PCI (widget vs. a custom form);
  - the obligations in Wompi's docs, merchant and payer regulations;
  - Visa's rules for trials that turn into subscriptions;
  - refunds and chargebacks, brand rules, and Colombian legal points to review with a lawyer;
  - CSP, sandbox data and test cases, and open questions for Wompi support.
- Official docs: https://docs.wompi.co/docs/colombia/ (fuentes de pago, tokens de aceptación, transacciones, eventos,
  datos de prueba, reembolsos V2). Wompi changes: confirm details there before relying on them.

## How a sound integration works

1. **Never see card data.** Open the **Wompi widget** from the web (iframe from `checkout.wompi.co`). Card or Nequi data
   is typed there; the web only gets a token (`tok_…` / `nequi_…`).
2. **Save the method** (tokenize mode): the backend turns the token into a **payment source** with the private key and
   stores only its id, type and masked data (brand + last 4, or a masked phone). Never reuse a card token for several
   charges.
3. **Acceptance:** show the links of Wompi's two documents (payer regulation and personal-data authorization) and get
   **explicit acceptance**: one unchecked checkbox each, links taken from the API, never hard-coded. Send both
   acceptance tokens when creating the payment source. Fetch them again right before registering, since they expire.
4. **Charge from the server only:** `POST /transactions` with `payment_source_id` and a **unique reference per attempt**
   (for example `<chargeId>-<attempt>`).
   - **Integrity signature:** SHA-256 of reference + amount in cents + currency (+ expiration) + integrity secret,
     computed on the server.
   - Send `installments` and the COF `recurrent` flag as the docs say.
5. **On-screen payments** can use the **widget in payment mode** (Wompi's own payment screen). The widget creates a
   transaction, not a payment source. To charge the same method later, register it first (tokenize), then pay.
6. **The result comes from events, not redirects:**
   - Verify the event checksum (values of `signature.properties` + `timestamp` + events secret), answer HTTP 200, and
     apply `transaction.updated` **once per transaction and status** (idempotent).
   - Add reconciliation: query the transaction by reference with the private key while the user waits, and in a job.
     Events can't reach `localhost`, and they can be lost.
7. **Zero amounts** don't go to Wompi (it doesn't charge 0): settle them locally.
8. **Refunds:** Wompi **refunds V2** (`POST /v1/refunds`, cards and Nequi; Wompi doesn't guarantee success). Colombian
   law gives 15 calendar days to refund what is owed (Ley 2439 de 2024): alert before that.
9. **Without keys the app must still start:** payment routes answer `503` and no job charges.

## The author's preferred defaults (ask the project owner before changing them)

| Default | Why |
|---|---|
| **Widget only, never a custom card or Nequi form** | With a custom form, card data passes through your page's JavaScript: PCI SAQ A-EP and skimming risk. With Wompi's iframe the expected questionnaire is SAQ A. |
| **Charge up front**, with automatic renewal; cancel anytime keeps access until the end of the paid period | It is how the big subscription apps charge, and it is simple to explain. |
| **No retries and no dunning:** a failed renewal suspends the service at the first failure; the customer reactivates by paying | No debt to chase, and no collection rules to apply (Colombia: Ley 2300 de 2023). |
| **Only an email when a charge fails,** no reminder before each charge; keep a 30-day notice for price changes | Fewer messages. Risk: Visa asks for a reminder at least 7 days before the first charge after a free trial (guide §2.4). Accept it consciously or send that one reminder. |
| **Only the refunds the law requires** (double charge, what is owed by law), stated clearly before paying | Wompi's merchant regulation requires a clear refund policy. Review the right of withdrawal (retracto) with a lawyer. |
| **Production stays on sandbox keys** until the real launch (legal texts, e-invoicing if applicable) | No real money moves by accident. |
| **Keys are never printed, logged or pasted in chat**; they live in a secret manager | The private key and both secrets give access to charges. |

## Configuration

| Variable | Notes |
|---|---|
| `WOMPI_PUBLIC_KEY` | `pub_test_…` / `pub_prod_…`. The browser sees it. |
| `WOMPI_PRIVATE_KEY` | **Secret.** Payment sources, transactions, refunds, queries. |
| `WOMPI_EVENTS_SECRET` | **Secret.** Event checksum. |
| `WOMPI_INTEGRITY_SECRET` | **Secret.** Transaction signature. |
| `WOMPI_API_URL` | Derive it from the keys' environment (`https://sandbox.wompi.co/v1` or `https://production.wompi.co/v1`). Mixing environments is a config error. |

- Require all four keys or none, from the same environment.
- Set the events URL for each environment in the Wompi merchant panel (`comercios.wompi.co`), pointing at your public
  webhook over HTTPS.
- **CSP:** `frame-src https://checkout.wompi.co`. With `'strict-dynamic'`, insert `widget.js` from code. Fallback
  `script-src` origins are in the guide, §3.1.

## Testing

- **Sandbox only.** Cards: `4242 4242 4242 4242` approves, `4111 1111 1111 1111` declines (any CVC, a future date).
  Nequi: `3991111111` approves, `3992222222` declines. Refunds V2 take a `test_scenario`.
- Keep a **sandbox smoke test** that skips without test keys and refuses to run with production keys.
- Unit tests fake Wompi (gateway, signatures, event verifier): never call the real API from CI.
- The widget is a cross-origin iframe: test it by hand, or with Playwright's `frameLocator` outside CI (guide §3.2).

## Rules when you change payments

1. Keep the guarantees: no card data stored, server-side signatures, verified events, idempotent settlement, one
   reference per attempt, and no tokens or keys in logs, traces or error trackers.
2. Tell the payer that **you charge and Wompi only processes the payment** (merchant regulation §2.2.8). Keep Wompi's
   two documents always available where you integrate.
3. Before paying, show the price with taxes, periodicity, renewal, how to cancel and the refund policy (Ley 1480). Keep
   payment evidence for 12 months.
4. Wompi's logo, if shown, follows its graphic resources (guide §2.6).
5. Open questions for Wompi support are listed in the guide (§3.3): PCI questionnaire, 3DS on payment sources, minimum
   charge, trial reminders. Don't assume the answers.
