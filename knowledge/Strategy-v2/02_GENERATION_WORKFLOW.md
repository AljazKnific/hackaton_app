# 02 — Generation Workflow

The step-by-step the app runs to turn a founder's input into a narrated promo. This is the dev's build guide — it maps to the two GPT calls + the ElevenLabs call.

**Role in the app:** the operational sequence behind the pipeline (`01`).

---

## Step 1 — Intake + Validate
- Take the user's product info.
- Check the gate (`ICPOffer-v2/05`): is the product, audience, and core result defined? If not, ask ONE clarifying question. Otherwise proceed.

## Step 2 — Build the Brain  *(GPT call #1)*
- Run `ICPOffer-v2` to produce: ICP (`01`), pains (`02`), desires (`03`), objections (`04`), and the sharpened offer with before→after (`05`).
- Output as structured JSON the next call can read.

## Step 3 — Generate Promos  *(GPT call #2)*
For each of ~3 promos:
1. **Angle** — `Ideas-v2`: pick a pain/desire, an emotional trigger (`Emotions-v2`), and a reframe → one-line angle.
2. **Hook** — `ViralHooks-v2`: open the angle (0–3s); run the hook checklist.
3. **Structure** — `ICPOffer-v2/06`: lay the angle across the 30-sec beats.
4. **Copy** — `WritingSystem-v2`: write each line (sentence style, value delivery, persuasion).
5. **CTA** — `CTA-v2`: one closing ask matched to offer type + awareness.
6. **Tone** — `Voice-v2`: pick the tone mode by product; apply spoken delivery.
7. **Format** — `Structure-Formatting-v2`: lay out labelled beats + timings + voiceover cues.
- Vary the 3 promos (different angles/triggers/CTAs).

## Step 4 — Pick
- User selects their favorite of the 3 scripts.

## Step 5 — Voice  *(ElevenLabs call)*
- Send the chosen script (with voiceover cues) to ElevenLabs → MP3.

## Step 6 — Handoff
- Deliver script + MP3 + optional caption tips (`Structure-Formatting-v2/03`) for the user's editor.

---

## Output Filter (every promo must pass)

| # | Check |
|---|---|
| 1 | Speaks to one ICP, one pain, one idea |
| 2 | Hook stops the scroll and is honest |
| 3 | Fits 30 seconds spoken (~55–75 words) |
| 4 | Ends on exactly one CTA |
| 5 | Every claim/number is real — nothing fabricated |

Fail any → regenerate that promo.
