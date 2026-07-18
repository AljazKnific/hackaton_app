# 02 — Voiceover Cues

How to mark up a script so the ElevenLabs read sounds natural — pauses, emphasis, and pacing, without relying on anything the ear can't hear.

**Role in the app:** applied to the script before it's sent to the voice model.

---

## Pauses
- Use a **line break** as a short pause and a **blank line** as a longer beat.
- The most important pause is right before the Turn (after the Problem) — it's where the tension lands.
- Optional explicit cue for the model: `(pause)` on its own line where you want a clear beat.

---

## Emphasis (without caps)
- The ear can't hear capital letters. Create emphasis with **word choice, short sentences, and placement** instead.
- Put the word you want to land **at the end of the line**: "and it chases the payment — *for you.*"
- One emphasis moment per beat. Everything can't be emphasized.

---

## Pacing
- Short lines = momentum; a lone short line after a longer one = punch.
- Vary line length so the read doesn't get monotone.
- Read it aloud mentally: if you run out of breath or stumble, shorten the line.

---

## Numbers & symbols
- Always spell numbers as spoken: "eleven days," "two minutes," "under a minute."
- No "$9/mo," "11d," "<60s," "→," "&" — write "nine dollars a month," "and," etc.

---

## Tone note
- The chosen voice mode (`Voice-v2/01`) sets the delivery; these cues just make it read cleanly. Keep the read calm and clear — let the words do the work.
