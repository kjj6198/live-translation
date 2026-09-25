const INPUT_SAMPLE_RATE = 16_000;
const OUTPUT_SAMPLE_RATE = 24_000;
// Room echo keeps reaching the mic briefly after playback stops.
const ECHO_TAIL_SECONDS = 0.3;

export async function startMic(onChunk: (pcm: ArrayBuffer) => void) {
  const stream = await navigator.mediaDevices.getUserMedia({
    audio: { channelCount: 1, echoCancellation: true, noiseSuppression: true },
  });
  const context = new AudioContext({ sampleRate: INPUT_SAMPLE_RATE });
  await context.audioWorklet.addModule("/mic-worklet.js");

  const worklet = new AudioWorkletNode(context, "mic-processor");
  worklet.port.onmessage = (event: MessageEvent<ArrayBuffer>) => onChunk(event.data);
  context.createMediaStreamSource(stream).connect(worklet);

  return () => {
    stream.getTracks().forEach((track) => track.stop());
    void context.close();
  };
}

export function createPlayer() {
  const context = new AudioContext({ sampleRate: OUTPUT_SAMPLE_RATE });
  let nextStartTime = 0;

  return {
    play(pcm: Uint8Array) {
      const int16 = new Int16Array(pcm.buffer, pcm.byteOffset, pcm.byteLength / 2);
      const buffer = context.createBuffer(1, int16.length, OUTPUT_SAMPLE_RATE);
      buffer.getChannelData(0).set(Float32Array.from(int16, (sample) => sample / 0x8000));

      const source = context.createBufferSource();
      source.buffer = buffer;
      source.connect(context.destination);
      nextStartTime = Math.max(nextStartTime, context.currentTime);
      source.start(nextStartTime);
      nextStartTime += buffer.duration;
    },
    isPlaying() {
      return context.currentTime < nextStartTime + ECHO_TAIL_SECONDS;
    },
    close() {
      void context.close();
    },
  };
}
