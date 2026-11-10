// SPDX-License-Identifier: Apache-2.0
// Every callback belongs to one request and one worker instance. Stale callbacks are ignored.
let pending = null;
const emit = (data) => window.emaEmit?.(data);
function settle(state, error, result) {
  if (pending !== state) return;
  pending = null;
  clearTimeout(state.bootTimer); clearTimeout(state.overallTimer);
  state.worker?.terminate();
  if (error) state.reject(error); else state.resolve(result);
}
window.cancelSynthesis = (requestID) => {
  if (!pending || (requestID && pending.id !== requestID)) return;
  const state = pending;
  settle(state, new Error('Synthesis cancelled'));
};
window.synthesize = (text, requestID = crypto.randomUUID(), options = {}) => {
  if (pending) return Promise.reject(new Error('A synthesis request is already running'));
  return new Promise((resolve, reject) => {
    const state = { id: requestID, resolve, reject, worker: null, stage: 'worker' };
    pending = state;
    const report = (data) => emit({ ...data, requestID });
    const fail = (error) => {
      if (pending !== state) return;
      report({ kind: 'error', stage: state.stage, detail: String(error?.message || error), stack: error?.stack || '' });
      settle(state, error instanceof Error ? error : new Error(String(error)));
    };
    report({ stage: 'worker', status: 'running', detail: 'Worker constructor çağrılıyor' });
    try {
      const url = new URL(options.workerFile || 'worker.js', import.meta.url);
      if (url.origin !== location.origin) throw new Error('Worker must be bundled on the local origin');
      url.searchParams.set('request', requestID);
      const worker = new Worker(url, { type: 'module' });
      state.worker = worker;
      state.bootTimer = setTimeout(() => fail(new Error('Worker hazır mesajı zaman aşımı')), options.bootTimeoutMs || 20000);
      state.overallTimer = setTimeout(() => fail(new Error('JavaScript synthesis promise zaman aşımı')), options.timeoutMs || 180000);
      worker.onmessage = ({ data }) => {
        if (pending !== state || data.requestID !== requestID) return;
        if (data.type === 'ready') {
          clearTimeout(state.bootTimer);
          report({ stage: 'worker', status: 'success', detail: 'Worker modülü yürütüldü ve hazır mesajı alındı' });
          state.stage = 'runtime';
          worker.postMessage({ text, pronunciations: options.pronunciations ?? [] });
        } else if (data.type === 'event') {
          if (data.status === 'running') state.stage = data.stage;
          report(data);
        } else if (data.type === 'error') {
          if (data.stage) state.stage = data.stage;
          const error = new Error(data.error || 'Worker error');
          if (data.stack) error.stack = data.stack;
          fail(error);
        } else if (data.type === 'result') {
          report({ stage: 'transfer', status: 'running', detail: 'WAV Worker’dan bridge’e ulaştı' });
          settle(state, null, data.result);
        }
      };
      worker.onerror = (event) => {
        event.preventDefault();
        const error = new Error(`${event.message || 'Worker script could not start'} (${event.filename || url.pathname}:${event.lineno || 0}:${event.colno || 0})`);
        error.stack = event.error?.stack || error.stack;
        fail(error);
      };
      worker.onmessageerror = () => fail(new Error('Worker message deserialization failed'));
    } catch (error) { fail(error); }
  });
};
window.emaReady = true;
if (!window.__EMA_HIDE_READY__) emit({ stage: 'bridge', status: 'success', detail: 'synthesize ve cancelSynthesis işlevleri hazır' });
