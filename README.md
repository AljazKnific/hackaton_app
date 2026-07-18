# Marketing copy + text-to-speech generator

Flutter client, TypeScript/Express API, PostgreSQL, OpenAI structured outputs,
and ElevenLabs text-to-speech. Marketing copy and speech are deliberately
separate stages: the user chooses a target duration before copy generation,
reviews the result, then selects a voice and requests audio.

## Configuration

Create a root `.env` for Docker (or copy `backend/.env.example` for local API
development). These secrets only belong on the backend:

```env
OPENAI_API_KEY=...
OPENAI_MODEL=gpt-5-mini
ELEVENLABS_API_KEY=...
ELEVENLABS_VOICE_ID=JBFqnCBsd6RMkjVDRZzb
```

Four delivery presets are seeded from `ELEVENLABS_VOICE_ID`: Calm & reassuring,
Energetic & upbeat, Professional & confident, and Casual & conversational.
They share one voice identity with different delivery settings; replace the
voice ID or add per-preset IDs later if you need different speakers.

## Run with Docker

```bash
docker compose up --build
```

The API listens on `http://localhost:3000`; PostgreSQL data and generated MP3s
are held in named Docker volumes. The service removes expired sessions and their
audio hourly. A session expires after 24 hours.

## Flutter

```bash
cd flutter_app
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
```

For iOS Simulator, macOS, or web use `http://localhost:3000`; Android emulators
use `10.0.2.2` to reach the development machine.

## Flow and safeguards

- Create a duration-bound session (15/30/60 seconds) and receive a possession
  token; send it as `Authorization: Bearer <token>` on all session calls.
- Structured extraction checks product name, audience, tone, and benefit.
  After five LLM attempts the client switches to a manual typed form.
- The backend moderates typed extracted data, then sends only those typed fields
  to the marketing prompt—never raw product text.
- Generation is limited to one in-flight text or speech call per session.
- Audio is streamed only by the authenticated session endpoint.
