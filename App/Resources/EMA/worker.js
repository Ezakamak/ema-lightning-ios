// SPDX-License-Identifier: Apache-2.0
import { EMA, RATE, wavBlob } from "./tts.js";
let engine;
self.onmessage = async ({ data }) => {
  try {
    if (typeof data.text !== "string" || !data.text.trim() || [...data.text].length > 1200)
      throw new Error("Invalid text (maximum 1000 user-visible characters)");
    engine ??= await EMA.load("wasm");
    const pieces = engine.pieces(data.text, 1);
    if (!pieces.length) throw new Error("Metinde okunabilir Türkçe sözcük bulunamadı.");
    const chunks = [];
    let count = 0, energy = 0, peak = 0;
    const stats = {};
    for await (const chunk of engine.stream(data.text, { speed: 1, seed: 42, stats })) {
      for (const x of chunk) {
        if (!Number.isFinite(x)) throw new Error("Model returned non-finite audio");
        energy += x * x;
        peak = Math.max(peak, Math.abs(x));
      }
      count += chunk.length;
      if (count > RATE * 180) throw new Error("Audio exceeds the 180 second memory limit");
      chunks.push(chunk);
    }
    if (count < RATE / 10 || peak < 1e-5) throw new Error("Model returned empty/silent audio");
    const bytes = new Uint8Array(await wavBlob(chunks).arrayBuffer());
    let binary = "";
    for (let i = 0; i < bytes.length; i += 8192)
      binary += String.fromCharCode(...bytes.subarray(i, i + 8192));
    self.postMessage({ wav: btoa(binary), samples: count, sampleRate: RATE,
      rms: Math.sqrt(energy / count), peak, normalized: pieces.map(([text]) => text).join(" "), stats });
  } catch (error) {
    self.postMessage({ error: String(error?.message || error) });
  }
};
