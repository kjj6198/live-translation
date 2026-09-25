import { useEffect, useRef, useState } from "react";
import { startTranslator, type Turn } from "./translator";

type Status = "idle" | "connecting" | "listening";

const DIRECTION_LABEL = { ja: "EN → JA", en: "JA → EN" } as const;

export function App() {
  const [status, setStatus] = useState<Status>("idle");
  const [error, setError] = useState<string>();
  const [turns, setTurns] = useState<Turn[]>([]);
  const stopRef = useRef<() => void>(undefined);
  const endRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    endRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [turns]);
  useEffect(() => () => stopRef.current?.(), []);

  const upsertTurn = (turn: Turn) =>
    setTurns((previous) => {
      const index = previous.findIndex(({ id }) => id === turn.id);
      return index === -1 ? [...previous, turn] : previous.with(index, turn);
    });

  const stop = () => {
    stopRef.current?.();
    stopRef.current = undefined;
    setStatus("idle");
  };

  const start = async () => {
    setError(undefined);
    setStatus("connecting");
    try {
      stopRef.current = await startTranslator({
        onTurn: upsertTurn,
        onError: (message) => {
          setError(message);
          stop();
        },
      });
      setStatus("listening");
    } catch (caught) {
      setError(caught instanceof Error ? caught.message : String(caught));
      setStatus("idle");
    }
  };

  return (
    <main>
      <header>
        <h1>Live Translation</h1>
        <p>Speak English to hear Japanese. 日本語で話すと英語に翻訳されます。</p>
      </header>

      <section className="transcript" aria-live="polite">
        {turns.length === 0 ? (
          <p className="empty">
            {status === "listening" ? "Listening… / 聞いています…" : "Press Start and speak."}
          </p>
        ) : (
          turns.map((turn) => (
            <article key={turn.id} className={turn.done ? "" : "pending"}>
              <span className="direction">{DIRECTION_LABEL[turn.target]}</span>
              {turn.source && <p className="source">{turn.source}</p>}
              <p className="translation" lang={turn.target}>
                {turn.translation}
              </p>
            </article>
          ))
        )}
        <div ref={endRef} />
      </section>

      {error && <p className="error">{error}</p>}

      <footer>
        {status === "listening" ? (
          <button type="button" className="stop" onClick={stop}>
            Stop
          </button>
        ) : (
          <button type="button" onClick={start} disabled={status === "connecting"}>
            {status === "connecting" ? "Connecting…" : "Start"}
          </button>
        )}
      </footer>
    </main>
  );
}
