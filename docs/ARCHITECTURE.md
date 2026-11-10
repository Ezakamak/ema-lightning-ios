# Architecture

Dependency direction: SwiftUI → SpeechViewModel → SpeechCore.SpeechEngine ← SystemSpeechEngine.

| Location | Responsibility |
| --- | --- |
| App/Application | Composition root; owns engine and screen lifetime |
| App/Features/Speech | Editor, accessibility labels, user actions and error presentation |
| Packages/SpeechCore | UI-independent request validation and engine contract; Swift Package tests |
| App/Infrastructure | AVFoundation adapter for the explicitly labeled system voice preview |
| App/Resources | Licenses and notices shipped inside the app |
| scripts | Repeatable packaging and repository checks |

The composition root injects the engine. No view creates a runtime, downloads a model or reads secrets. UI and the current engine run on the main actor; synthesis is scheduled by AVFoundation. The app stops speech when it leaves the active scene. It does not request a microphone or add a background audio mode.

## Native EMA integration roadmap

1. Review a specific model/export revision, all model licenses, ONNX Runtime binary/transitive notices, normalizer dependencies and device resource requirements. Record hashes and provenance before bundling anything.
2. Implement an EMA adapter behind `SpeechEngine`. Keep tokenization/normalization, model loading, inference and audio playback in separate components. Heavy inference must run off the main actor with cancellation and bounded memory.
3. Compare Turkish normalization, tensor shapes, sample rate and audio against upstream fixtures. Measure physical iPhone memory/latency and test offline behavior.
4. Extend the contract with observable progress/completion and cancellation if asynchronous model loading requires it. Add fake-engine view model tests and integration tests for the real adapter.
5. Update UI labels, documentation, dependency audit and shipped notices together. Do not relabel the system voice preview as EMA output.

No native EMA quality, speed, offline model execution or binary compatibility claim is made by the current preview.
