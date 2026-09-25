import { GoogleGenAI, Modality, type LiveServerMessage, type Session } from "@google/genai";
import { createPlayer, startMic } from "./audio";

const MODEL = "gemini-3.5-live-translate-preview";

export type Target = "ja" | "en";

export type Turn = {
  id: number;
  target: Target;
  source: string;
  translation: string;
  done: boolean;
};

type Callbacks = {
  onTurn: (turn: Turn) => void;
  onError: (message: string) => void;
};

let nextTurnId = 0;

/**
 * Translates English speech to Japanese and Japanese speech to English.
 *
 * Runs one session per target language on the same mic stream. With
 * `echoTargetLanguage: false`, a session stays silent when speech is already
 * in its target language, so only the session for the other language answers.
 */
export async function startTranslator({ onTurn, onError }: Callbacks) {
  const ai = new GoogleGenAI({ apiKey: await fetchToken(), httpOptions: { apiVersion: "v1alpha" } });
  const player = createPlayer();

  const connect = (target: Target) => {
    let turn: Turn = { id: nextTurnId++, target, source: "", translation: "", done: false };

    const handleMessage = ({ serverContent: content }: LiveServerMessage) => {
      if (!content) return;

      for (const part of content.modelTurn?.parts ?? []) {
        if (part.inlineData?.data) player.play(Uint8Array.fromBase64(part.inlineData.data));
      }
      if (content.inputTranscription?.text) turn.source += content.inputTranscription.text;
      if (content.outputTranscription?.text) turn.translation += content.outputTranscription.text;

      if (content.turnComplete) turn.done = true;
      // Both sessions hear every word, so only the one that translated shows it.
      if (turn.translation) onTurn({ ...turn });
      if (turn.done) turn = { id: nextTurnId++, target, source: "", translation: "", done: false };
    };

    return ai.live.connect({
      model: MODEL,
      config: {
        responseModalities: [Modality.AUDIO],
        inputAudioTranscription: {},
        outputAudioTranscription: {},
        translationConfig: { targetLanguageCode: target, echoTargetLanguage: false },
      },
      callbacks: {
        onmessage: handleMessage,
        onerror: (event) => onError(event.message),
        onclose: (event) => {
          if (event.code !== 1000) onError(`Connection closed: ${event.reason || event.code}`);
        },
      },
    });
  };

  const sessions: Session[] = await Promise.all([connect("ja"), connect("en")]);
  const closeAll = () => {
    for (const session of sessions) session.close();
    player.close();
  };

  try {
    const stopMic = await startMic((pcm) => {
      // Without headphones the mic hears our own playback and would translate it back.
      if (player.isPlaying()) return;
      const audio = { data: new Uint8Array(pcm).toBase64(), mimeType: "audio/pcm;rate=16000" };
      for (const session of sessions) session.sendRealtimeInput({ audio });
    });
    return () => {
      stopMic();
      closeAll();
    };
  } catch (error) {
    closeAll();
    throw error;
  }
}

async function fetchToken() {
  const response = await fetch("/api/token", { method: "POST" });
  const body: { token?: string; error?: string } = await response.json();
  if (!body.token) throw new Error(body.error ?? "Failed to get a session token");
  return body.token;
}
