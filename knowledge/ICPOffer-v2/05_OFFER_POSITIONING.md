# 05 — Offer Positioning

The offer engine. Defines what a "sharp offer" is, how the app builds one from a user's raw input, and how that offer becomes a 30-second promo script + voiceover.

**Version:** 2.0 (app) · **App users:** solo founders · vibe coders · indie hackers
**Output target:** promo-video scripts + AI voiceover (NOT tweets)

---

## Role in the app

- **Stage 2 (Build Brain):** the app fills the Offer Schema below from the user's input, then runs the before → after sharpening.
- **Stage 3 (Generate):** the sharpened offer feeds hooks, CTAs, and 30-sec promo scripts.
- **Validation gate:** the prompt only runs when every *required input* is defined (see bottom). If one is missing, ask a single follow-up question instead of guessing.

---

## The Offer Schema

Every offer the app produces has these fields. Each maps to a beat of the promo.

| Field | What it is | In finished offer |
|---|---|---|
| **Core promise** | One line: the single result the offer delivers | Yes |
| **Who it's for** | The specific person + their situation | Yes |
| **Before state** | Where they are now (stuck, cost, frustration) | Yes |
| **After state** | Where the offer takes them (the dreamland) | Yes |
| **Mechanism** | *How* it works — the reason to believe | Yes |
| **Proof** | Numbers, timeframes, before/after, names | If available |
| **Value frame** | Why it's worth it (vs. cost / vs. alternative) | Yes |
| **Risk reversal** | Guarantee or why it's safe to try | Optional |
| **Deliverables** | What they walk away owning (services more than products) | Optional |
| **Effort / time-to-value** | How fast, how little work | Optional |

> **Note:** the last column is what the *finished offer* must contain — not what the user must type. The app infers and sharpens these from minimal input (see the validation gate at the bottom).

---

## Worked Example (neutral)

Used as the few-shot example inside the Stage 2 prompt. Product: **InvoiceZen — a simple invoicing app for freelancers.**

- **Core promise:** "Send a professional invoice and get paid in 60 seconds — no spreadsheets, no awkward follow-ups."
- **Who it's for:** Freelancers — designers, writers, developers — who do great work but bleed hours and money on invoicing admin.
- **Before state:** Cobbling invoices together in spreadsheets, losing track of who owes what, chasing late payments over uncomfortable emails, looking less professional than they actually are.
- **After state:** Every invoice out in a minute, automatic reminders doing the chasing, paid faster, looking buttoned-up.
- **Mechanism:** Pre-built templates + auto-reminders + one-tap payment links handle the admin — the freelancer just hits send.
- **Proof:** "Users get paid an average of 11 days faster." (Swap in the user's real proof when available.)
- **Value frame:** Less than a coffee a week; saves ~3 billable hours a month.
- **Risk reversal:** Free until your first invoice gets paid.
- **Deliverables:** n/a for a product — this field mostly applies to services/agencies.
- **Effort / time-to-value:** First invoice sent in under two minutes.

---

## Before → After (the on-stage "wow")

The signature move: take the user's vague offer and show the sharpened version beside it.

**Before (what a user types):**
> "InvoiceZen is an app that lets freelancers send invoices."

**After (what the app returns):**
> "Freelancers lose hours and get paid late because invoicing is a mess. InvoiceZen sends a professional invoice in 60 seconds and chases the payment for you — so you get paid faster, without the awkward emails."

Always render this contrast. It's the proof the brain did something a blank ChatGPT box wouldn't.

---

## Output Framing Rules — for video scripts + voiceover

Replaces the old tweet rules entirely.

- **Lead with the after-state or the pain**, never a feature. ("Get paid in 60 seconds" > "cloud-based invoicing software.")
- **A 30-sec promo IS a pitch.** End on ONE direct CTA. (This inverts the old Twitter rule of never pitching directly — that was for organic feeds; this is a promo.)
- **Show the math out loud** — spoken numbers land harder ("less than a coffee a week, and you get paid eleven days sooner").
- **Cost-of-inaction frame** works: "every week in spreadsheets is billable hours you're giving away."
- **One idea per sentence.** Voiceover has no punctuation the ear can see — short spoken lines, contractions, punchy verbs, no nested clauses.
- **Say numbers cleanly** for the voice model ("sixty seconds," not "60s"; "eleven days," not "11d").

### 30-second promo beat map (offer field → beat)

| Time | Beat | Pulls from |
|---|---|---|
| 0–3s | Hook | Before state / core promise |
| 3–8s | Problem | Before state |
| 8–15s | Turn | Mechanism |
| 15–22s | Proof | Proof / value frame |
| 22–30s | CTA | After state → one direct ask |

---

## Validation — "correctly defined" gate

Before Stage 2 runs, these inputs must be present (from the user or a quick follow-up):

1. **What the product/service does** (one sentence is enough)
2. **Who it's for** (or enough signal to infer it)
3. **The core result / promise** it delivers

If any is missing, the app asks a single clarifying question rather than generating a weak offer. Everything else the app can infer and sharpen.
