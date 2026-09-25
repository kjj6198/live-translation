// Batches mic input into 100ms chunks of 16-bit PCM, the format the Live API expects.
const CHUNK_SAMPLES = sampleRate / 10;

class MicProcessor extends AudioWorkletProcessor {
  buffer = new Int16Array(CHUNK_SAMPLES);
  length = 0;

  process([input]) {
    const channel = input[0];
    if (!channel) return true;

    for (const sample of channel) {
      this.buffer[this.length++] = Math.max(-1, Math.min(1, sample)) * 0x7fff;
      if (this.length === CHUNK_SAMPLES) {
        this.port.postMessage(this.buffer.buffer, [this.buffer.buffer]);
        this.buffer = new Int16Array(CHUNK_SAMPLES);
        this.length = 0;
      }
    }
    return true;
  }
}

registerProcessor("mic-processor", MicProcessor);
