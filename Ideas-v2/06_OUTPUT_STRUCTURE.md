# 06 — Output Structure

The format for each generated angle, and how the model should produce them. This is what Stage 3 hands to the hook + script stages.

**Role in the app:** defines the idea-engine's output contract.

---

## Per-Angle Output

| Field | What it is |
|---|---|
| **Angle title** | short, specific label for the concept |
| **One-line angle** | the promo concept in a sentence |
| **Pain / desire** | which brain item it targets (`ICPOffer-v2/02`,`03`) |
| **Emotional trigger** | 1–2 from `02` |
| **Reframe + lens** | from `03` |
| **Hook type** | which `ViralHooks-v2` pattern fits the opening |
| **Suggested structure** | which script shape (`ICPOffer-v2/06` beat map) |
| **CTA direction** | the kind of ask it points to (`CTA-v2`) |
| **Tone hint** | suggested voice mode (`Voice-v2/01`) |

---

## Instructions for the Model

1. Read the brain (ICP, pains, desires, offer).
2. Generate **5 distinct angles** using the formula (`01`) — vary pain/desire, trigger, and reframe.
3. Fill every field above for each angle.
4. Validate each against `05`; drop or regenerate any that fail.
5. Return the surviving angles for the user to pick from.

---

## Quantity

| Mode | Angles |
|---|---|
| Quick | 3 |
| Standard | 5 |
| Deep | 8–10 |

**Default: 5.** Enough choice without overwhelming the pick step.
