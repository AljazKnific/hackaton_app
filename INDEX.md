# ICPOffer-v2 — Index (App Brain)

The knowledge base the app's generation prompt runs on. From a user's product description, these files let the prompt build a marketing brain — ICP, pains, desires, objections, sharpened offer — and turn it into **30-second promo scripts + AI voiceover.**

**Version:** 2.0 (app) · **Updated:** Jul 2026
**App users:** solo founders · vibe coders · indie hackers
**Output:** promo-video scripts + voiceover (NOT tweets)
**For the developer:** input these files as the prompt's reference/brain. All examples use one neutral product — *InvoiceZen, a simple invoicing app for freelancers* — as the few-shot pattern.

---

## Files

| File | What it defines | Feeds |
|---|---|---|
| [01_ICP_PROFILE.md](01_ICP_PROFILE.md) | Who the user's customer is (identity, sub-segments, awareness, psychographics, language) | Everything downstream |
| [02_PAIN_POINTS.md](02_PAIN_POINTS.md) | The customer's pains + priority | Hook + problem beats |
| [03_DESIRES.md](03_DESIRES.md) | What the customer wants (the after-state) | Turn + CTA beats, offer after-state |
| [04_OBJECTIONS.md](04_OBJECTIONS.md) | Why they won't buy + reframes | Objection promos, CTA beat |
| [05_OFFER_POSITIONING.md](05_OFFER_POSITIONING.md) | Offer schema + before→after sharpening + validation gate | Whole promo |
| [06_CONTENT_ANGLE_MAP.md](06_CONTENT_ANGLE_MAP.md) | Maps brain → video-script structures → CTA | Stage 3 generation |

> `AGENT_NAVIGATOR.html` is legacy (Twitter ghostwriting) and not part of the app brain — ignore or delete.

---

## The App Flow (how the files are used)

```
STAGE 1 — INTAKE:      user pastes product info
STAGE 2 — BUILD BRAIN: prompt uses 01–05 → ICP + pains + desires + objections + sharpened offer
                       (validation gate in 05: only runs if product, audience, core result are defined)
STAGE 3 — GENERATE:    prompt uses 06 → hooks · CTAs · 3 promo scripts (30s each)
STAGE 4 — PICK:        user taps favorite script
STAGE 5 — VOICE:       ElevenLabs → MP3 voiceover
```

---

## Every File Follows the Same Shape

1. **Role in the app** — which stage uses it, what it feeds
2. **Schema** — the fields the app produces
3. **Method** — how the app derives them from user input
4. **Worked example** — neutral (InvoiceZen)
5. **Output note** — how it maps to video script + voiceover

---

## The 30-Second Beat Map (shared across the library)

| Time | Beat | Source file |
|---|---|---|
| 0–3s | Hook | 02_PAIN_POINTS |
| 3–8s | Problem | 02_PAIN_POINTS |
| 8–15s | Turn | 03_DESIRES + mechanism |
| 15–22s | Proof | 05_OFFER_POSITIONING |
| 22–30s | CTA | 05_OFFER_POSITIONING (after-state) |

---

## Global Rules

- **De-Twitterized:** output is promo video + voiceover, never tweets.
- **Generalized:** works for any user's product; examples are neutral, not hardcoded.
- **Validation first:** don't generate on thin input — ask one clarifying question (see `05`).
- **Voiceover-friendly:** short spoken lines, contractions, numbers spoken cleanly, end on the CTA.
