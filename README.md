# Live Translation

Speak English and hear it in Japanese. Speak Japanese and hear it in English.

Uses Gemini's real-time speech-to-speech model, `gemini-3.5-live-translate-preview`.

## Setup

```sh
pnpm install
echo "GEMINI_API_KEY=your-key" > .env.local
pnpm dev
```

Open the printed URL in Chrome, press **Start**, and allow microphone access.

## How it works

- The model translates into one target language per session. The app opens two sessions, one targeting Japanese and one targeting English, and sends the same mic audio to both. With `echoTargetLanguage: false`, a session stays silent when the speech is already in its target language, so only the session for the other language responds.
- The Vite dev server provides `/api/token`, which creates short-lived Live API tokens. The API key never reaches the browser.
- The mic is muted while a translation plays. Otherwise the speakers feed back into the mic and the app translates its own output. Because of this, you can't talk over a translation while it plays.

For the on-device macOS subtitle app, see [macos/README.md](macos/README.md).
