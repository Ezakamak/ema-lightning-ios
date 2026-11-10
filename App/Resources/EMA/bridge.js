// SPDX-License-Identifier: Apache-2.0
// Workers isolate inference from WebKit's UI thread. Nothing is fetched remotely.
let worker = null;
let pending = null;
window.cancelSynthesis = () => {
  worker?.terminate();
  worker = null;
  pending?.reject(new Error("Synthesis cancelled"));
  pending = null;
};
window.synthesize = (text) => {
  if (pending) throw new Error("A synthesis request is already running");
  worker ??= new Worker(new URL("worker.js", import.meta.url), { type: "module" });
  return new Promise((resolve, reject) => {
    pending = { resolve, reject };
    worker.onmessage = ({ data }) => {
      pending = null;
      if (data.error) {
        window.cancelSynthesis();
        reject(new Error(data.error));
      } else resolve(data);
    };
    worker.onerror = (event) => {
      window.cancelSynthesis();
      reject(new Error(event.message || "EMA worker failed"));
    };
    worker.postMessage({ text });
  });
};
window.emaReady = true;
