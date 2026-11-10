"""Real bundled WASM/ONNX inference, with all non-loopback requests blocked."""
from pathlib import Path
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import threading, json, base64, wave, io
from playwright.sync_api import sync_playwright

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'App/Resources/EMA'
class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ASSETS), **kwargs)
    def log_message(self, *args): pass
    def end_headers(self):
        self.send_header('Content-Security-Policy', "default-src 'none'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self'; worker-src 'self'; connect-src 'self'")
        super().end_headers()

server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
origin = f'http://127.0.0.1:{server.server_port}'
out = ROOT / 'build/offline-engine'
out.mkdir(parents=True, exist_ok=True)
try:
    with sync_playwright() as p:
        browser = p.chromium.launch(executable_path='/usr/bin/chromium', args=['--no-sandbox'])
        context = browser.new_context(service_workers='block')
        external = []
        def route_handler(route):
            if route.request.url.startswith(origin + '/'):
                route.continue_()
            else:
                external.append(route.request.url)
                route.abort()
        context.route('**/*', route_handler)
        page = context.new_page()
        page.on('console', lambda m: print('browser:', m.type, m.text[:500], flush=True))
        page.on('pageerror', lambda e: print('browser error:', e, flush=True))
        page.add_init_script("window.emaTestEvents = []; window.addEventListener('ema-diagnostic', e => window.emaTestEvents.push(e.detail));")
        page.goto(origin + '/index.html')
        page.wait_for_function('window.emaReady === true')
        results = []
        for i, text in enumerate(['Merhaba dünya.', 'Saat 14:30, fiyat 125 TL. İstanbul ve Iğdır.', 'Çağrı, güzel bir öğleden sonra görüşürüz!']):
            result = page.evaluate('text => window.synthesize(text)', text)
            audio = base64.b64decode(result.pop('wav'))
            with wave.open(io.BytesIO(audio)) as wav:
                assert wav.getframerate() == 48000 and wav.getnchannels() == 1
                assert wav.getsampwidth() == 2 and wav.getnframes() == result['samples']
            assert result['samples'] > 4800 and result['rms'] > 1e-5
            assert not any(c.isdigit() for c in result['normalized'])
            (out / f'ema-{i}.wav').write_bytes(audio)
            results.append({'input': text, **result})
            print(json.dumps(results[-1], ensure_ascii=False), flush=True)
        events = page.evaluate('window.emaTestEvents')
        for stage in ['worker', 'runtime', 'normalizer', 'textModel', 'soundModel', 'decoderModel', 'normalization', 'synthesis', 'wav']:
            assert any(e.get('stage') == stage and e.get('status') == 'running' for e in events), stage
            assert any(e.get('stage') == stage and e.get('status') == 'success' for e in events), stage
        # Real Worker failures and unresolved promises must reject, preserve details and recover.
        for file, expected in [('missing-worker.js', 'Worker'), ('test-fixtures/throw-worker.js', 'EMA_TEST_WORKER_ERROR'), ('test-fixtures/stalled-worker.js', 'zaman aşımı'), ('test-fixtures/unresolved-worker.js', 'zaman aşımı')]:
            error = page.evaluate("""async ([workerFile]) => {
              try { await window.synthesize('Merhaba.', crypto.randomUUID(), {workerFile, bootTimeoutMs: 300, timeoutMs: 500}); return ''; }
              catch(e) { return String(e.message); }
            }""", [file])
            assert expected.lower() in error.lower(), (file, error)
        console_result = page.evaluate("() => window.synthesize('Merhaba dünya.', crypto.randomUUID(), {workerFile: 'test-fixtures/console-worker.js'})")
        assert console_result['samples'] > 4800
        assert page.evaluate("window.emaTestEvents.some(e => e.kind === 'log' && e.detail.includes('EMA_TEST_WORKER_CONSOLE_DETAIL'))")
        # Cancellation must reject the request and allow a fresh worker/session afterwards.
        assert page.evaluate('''async () => {
          const promise = window.synthesize('İptal edilecek uzun bir metin.').then(() => false, () => true);
          window.cancelSynthesis(); return await promise;
        }''')
        recovered = page.evaluate("() => window.synthesize('Yeniden merhaba.')")
        assert recovered['samples'] > 4800
        assert not external, external
        (out / 'results.json').write_text(json.dumps({'external_requests': external, 'cases': results, 'cancellation_recovery': True}, indent=2, ensure_ascii=False))
        browser.close()
finally:
    server.shutdown()
print('Bundled ONNX inference, Turkish normalization, WAV validity and cancellation recovery passed.')
