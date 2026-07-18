# 09 — Choosing & Validating the CTA

How the app selects the single best CTA for a promo and checks it before it ships.

**Role in the app:** runs between CTA generation and the final script.

---

## Selection Steps

1. **Read the offer type** (`ICPOffer-v2/05`) → pick the CTA family (`06`).
2. **Read the awareness stage** (`ICPOffer-v2/01`) → set the intensity (`05`).
3. **Pick a phrasing framework** (`04`) and write the line using the real after-state + one step.
4. **Frame the value** around it (`07`).

---

## Validation Checklist (before the CTA ships)

- [ ] Exactly one ask
- [ ] Names the outcome/after-state, not a feature
- [ ] The first step is the lowest-friction action possible
- [ ] Matches the offer type (self-serve ≠ "book a call")
- [ ] Intensity matches awareness stage
- [ ] No fabricated urgency or scarcity
- [ ] Stated plainly and confidently (no hedging)
- [ ] Can be said in one breath (voiceover)

**Fails any check → regenerate.**

---

## If the app generates options

When producing multiple promos, vary the CTA across them (direct vs soft, different phrasing frameworks) so the user can pick the one that fits their goal — but each individual promo still ends on exactly one ask.
