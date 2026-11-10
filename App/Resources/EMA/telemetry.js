// SPDX-License-Identifier: Apache-2.0
// Never log input text, audio bytes or arbitrary console objects.
window.emaEmit = (event) => {
  const data = { requestID: window.__EMA_REQUEST_ID__ || 'browser', ...event };
  window.dispatchEvent(new CustomEvent('ema-diagnostic', { detail: data }));
  window.webkit?.messageHandlers?.emaDiagnostics?.postMessage(data);
};
window.emaEmit({ stage: 'bridge', status: 'running', detail: 'Yerel telemetry betiği yürütülüyor' });
window.addEventListener('error', (e) => window.emaEmit({ kind: 'error', detail: e.message || 'JavaScript resource error', stack: e.error?.stack || `${e.filename || ''}:${e.lineno || 0}:${e.colno || 0}` }));
window.addEventListener('unhandledrejection', (e) => window.emaEmit({ kind: 'error', detail: String(e.reason?.message || e.reason), stack: e.reason?.stack || '' }));
document.addEventListener('securitypolicyviolation', (e) => window.emaEmit({ kind: 'error', detail: `CSP: ${e.violatedDirective}; ${e.blockedURI}` }));
for (const level of ['warn', 'error']) {
  const original = console[level].bind(console);
  console[level] = (...args) => {
    original(...args);
    // Only strings are forwarded; tensor/user objects are deliberately not serialized.
    window.emaEmit({ kind: 'log', detail: `console.${level}: ${args.filter(x => typeof x === 'string').join(' ').slice(0, 2000)}` });
  };
}
