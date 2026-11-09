# Architecture

Default inference path:

SwiftUI → SpeechViewModel → SpeechRequest → EMASpeechEngine → WKWebView → module Web Worker → bundled normalizer + ONNX CPU/WASM → 48 kHz WAV → AVAudioPlayer.

Apple AVSpeechSynthesizer is a separate **explicitly selected alternative**, never an automatic fallback or a substitute for EMA test output.

| Location | Responsibility |
| --- | --- |
| App/Application | Composition root and foreground lifecycle |
| App/Features/Speech | Engine choice (EMA by default), editor, progress, cancellation and errors |
| Packages/SpeechCore | Request validation (1,000 graphemes) and async engine contract |
| App/Infrastructure/EMASpeechEngine.swift | Main-actor WebKit lifecycle, validated WAV bridge and native playback |
| App/Infrastructure/LoopbackAssetServer.swift | Bundled read-only assets over ephemeral IPv4 loopback HTTP, random path token |
| App/Resources/EMA | Pinned real model graphs, normalizer, CPU runtime, JS pipeline, notices and hashes |
| IntegrationTests | Hosted iOS tests executing the production engine and decoding real WAV with AVFoundation |
| tests/test_offline_engine.py | Linux Chromium inference with all non-loopback requests blocked |

## Runtime choice and offline behavior

This implementation uses ONNX Runtime **Web (WASM)** inside Apple's WKWebView, not a Swift/Objective-C ONNX Runtime binding. This reuses Özcan Çelik's actual frontend/frame planner/decoder pipeline and normalizer WASM, rather than introducing an unverified Turkish frontend port. Only the CPU backend is enabled; it uses one thread and no WebGPU or SharedArrayBuffer requirement.

All assets live in the app bundle. An in-process Network.framework listener is bound to `127.0.0.1` only; it is not a remote inference service or a LAN listener. Standard loopback HTTP allows WebKit to load ES modules and WASM reliably. ATS permits local networking only. A CSP permits scripts, workers and fetches from the same origin, navigation is restricted to the token path, and no external URL occurs in the application bridge/worker. No model requests go to the internet.

The worker loads sessions on first request, retains them for repeated requests, normalizes and chunks Turkish text, runs text/sound/decoder graphs and returns PCM16 WAV. Heavy inference runs outside the Swift/UI thread. WAV output is finite/non-silent checked before native playback. The current version waits for the whole utterance; it does not stream playback. Input is capped at 1,000 characters, output at 180 seconds, and a 180-second operation timeout limits stalled work.

Stop, engine changes and leaving the foreground cancel the worker and stop audio. The next request reloads the worker/page as needed. WebContent termination reports an error and allows restart. Model failure never silently selects Apple's voice. A nonpersistent WebKit data store prevents reliance on a previous online cache.

## Remaining validation

Physical iPhone airplane mode, cold launch after installation, audible quality, memory/thermal behavior and long-text cancellation must be checked on real hardware before a stable release. Browser and simulator inference cannot establish those device properties. See TESTING.md for recorded evidence and limitations.
