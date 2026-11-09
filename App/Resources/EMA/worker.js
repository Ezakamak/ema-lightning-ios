// SPDX-License-Identifier: Apache-2.0
import { EMA, RATE, wavBlob } from './tts.js';
const requestID = new URL(self.location.href).searchParams.get('request');
let currentStage = 'worker';
for (const level of ['warn', 'error']) {
  const original = console[level].bind(console);
  console[level] = (...args) => {
    original(...args);
    self.postMessage({ type: 'event', requestID, kind: 'log', stage: currentStage,
      detail: `Worker console.${level}: ${args.filter(x => typeof x === 'string').join(' ').slice(0, 2000)}` });
  };
}
const stage = (name, status, detail = '') => {
  if (status === 'running') currentStage = name;
  self.postMessage({ type: 'event', requestID, stage: name, status, detail });
};
const fail = (error) => self.postMessage({ type: 'error', requestID, stage: currentStage,
  error: String(error?.message || error), stack: error?.stack || '' });
self.addEventListener('unhandledrejection', (e) => { e.preventDefault(); fail(e.reason); });
self.postMessage({ type: 'ready', requestID });
self.onmessage = async ({ data }) => {
  try {
    if (typeof data.text !== 'string' || !data.text.trim() ||
        [...new Intl.Segmenter('tr', { granularity: 'grapheme' }).segment(data.text)].length > 1000)
      throw new Error('Invalid text (maximum 1000 user-visible characters)');
    const engine = await EMA.load('wasm', undefined, stage);
    stage('normalization', 'running');
    const pieces = engine.pieces(data.text, 1);
    if (!pieces.length) throw new Error('Metinde okunabilir Türkçe sözcük bulunamadı.');
    stage('normalization', 'success', `${pieces.length} parça doğrulandı; metin loglanmadı`);
    const chunks = [];
    let count = 0, energy = 0, peak = 0;
    const stats = {};
    stage('synthesis', 'running');
    for await (const chunk of engine.stream(data.text, { speed: 1, seed: 42, stats, preparedPieces: pieces })) {
      for (const x of chunk) {
        if (!Number.isFinite(x)) throw new Error('Model returned non-finite audio');
        energy += x * x; peak = Math.max(peak, Math.abs(x));
      }
      count += chunk.length;
      if (count > RATE * 180) throw new Error('Audio exceeds the 180 second memory limit');
      chunks.push(chunk);
    }
    if (count < RATE / 10 || peak < 1e-5) throw new Error('Model returned empty/silent audio');
    stage('synthesis', 'success', `${count} sonlu ses örneği doğrulandı`);
    stage('wav', 'running');
    const bytes = new Uint8Array(await wavBlob(chunks).arrayBuffer());
    if (bytes.length !== 44 + 2 * count) throw new Error('WAV length validation failed');
    let binary = '';
    for (let i = 0; i < bytes.length; i += 8192) binary += String.fromCharCode(...bytes.subarray(i, i + 8192));
    const wav = btoa(binary);
    stage('wav', 'success', 'PCM16 WAV ve base64 hazır');
    self.postMessage({ type: 'result', requestID, result: { wav, samples: count, sampleRate: RATE,
      rms: Math.sqrt(energy / count), peak, normalized: pieces.map(([text]) => text).join(' '), stats } });
  } catch (error) { fail(error); }
};
