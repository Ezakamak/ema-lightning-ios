---
license: apache-2.0
language:
- tr
pipeline_tag: text-to-speech
tags:
- text-to-speech
- tts
- turkish
- speech-synthesis
- flow-matching
---

![EMA Lightning](assets/ema-lightning.webp)

# ⚡ EMA Lightning

**Tiny, fast and accurate Turkish text to speech.** A 5.6M-parameter DiT acoustic model and a 3M-parameter vocoder: 8.6M in total, about 34 MB. Apache 2.0.

- **Most accurate on Freya-TR-Eval:** 0.92% WER, the lowest of every system measured, including ElevenLabs v4, Gemini 3.8 and the 2.38B-parameter Trendyol-TTS.
- **Fast:** first audio in 3.86 ms and 440× faster than real time on an RTX 4090; 1,316× with batching.
- **Streams:** audio starts while the rest of the text is still being generated.
- **Cheap:** about $0.0085 per million characters on a rented RTX 4090.
- **Runs anywhere:** GPU or CPU, fully offline. No API key, and no text or audio leaves the machine.
- **One model serves many callers:** call it from as many threads as you like; its scheduler, Playhead, runs everyone's work together on the GPU.

- **Code:** [EMA Lightning on GitHub][github]
- **Package:** [`pip install ema-lightning`](https://pypi.org/project/ema-lightning/)
- **Text frontend:** [normalizer-tr](https://github.com/erdemtuna/normalizer-tr), by Erdem Tuna

![EMA Lightning architecture](assets/architecture.png)

**Figure 1.** Text is encoded per letter, placed on a word–letter timeline by a duration predictor, turned into one condition per frame by a windowed aligner, generated as latents in four steps by a DiT, and decoded to 48 kHz audio. Details under [Architecture](#architecture).

## Listen

Every clip below is made with `say()` at seed 0, straight from the text shown.

**Model sadece 8.6 milyon parametre ve çok hızlı.**
<audio controls src="https://huggingface.co/canberkkkkkk/ema-lightning/resolve/main/assets/sample-1.wav"></audio>

**15 Ekim 2026 Çarşamba günü saat 14:30'da, 1.250.000 TL tutarındaki ödemeniz hesabınıza yatırılacak.**
<audio controls src="https://huggingface.co/canberkkkkkk/ema-lightning/resolve/main/assets/sample-2.wav"></audio>

**Sabahın erken saatlerinde liman henüz uyanmamıştı. Balıkçılar ağlarını sessizce topluyor, martılar ise teknelerin etrafında dönerek şanslarını deniyordu.**
<audio controls src="https://huggingface.co/canberkkkkkk/ema-lightning/resolve/main/assets/sample-3.wav"></audio>

## Quickstart

```bash
pip install ema-lightning
```

Make one `EMA` and keep it for the whole program. There are two ways to get speech out of it:

| | `say()` | `stream()` |
|---|---|---|
| Gives you | the whole audio, once it's ready | the audio piece by piece, as it's made |
| Takes | one text, or a list of texts | one text per call |
| Use it for | files, voiceovers, batch jobs | playing as you go: speakers, phone calls, live apps |

### `say()`: a whole text, back when it's ready

```python
from ema_lightning import EMA

tts = EMA()                                     # downloads ema.pt and decoder.pt, uses the GPU if there is one
speech = tts.say("Merhaba, size nasıl yardımcı olabilirim?", path="merhaba.wav")
print(speech.duration, speech.sample_rate)      # seconds of audio, 48000
```

`say()` returns a `Speech`: the `audio` (a float32 NumPy array, mono, between -1 and 1), its `sample_rate`, its `duration` in seconds, and the `seed` that made it. With `path`, it also writes a WAV file. A list is made in shared batches, one `Speech` per text, in order; with `path`, the clips go into that folder as `0.wav`, `1.wav`, …:

```python
speeches = tts.say(["Günaydın.", "Siparişiniz yola çıktı.", "İyi günler dileriz."], path="clips")
```

### `stream()`: hear it while it's being made

```python
import sounddevice as sd                        # pip install sounddevice

with sd.OutputStream(samplerate=48000, channels=1, dtype="float32") as speaker:
    for chunk in tts.stream("Merhaba! Bu ses siz dinlerken üretiliyor. İlk kelimeyi duyduğunuzda, "
                            "cümlenin geri kalanı çoktan hazır."):
        speaker.write(chunk)
```

The first chunk is one second of audio and is ready in about 4 ms on a GPU. The rest follows four seconds at a time, far faster than it plays, so playback never waits. Leave the loop early and the rest of that text's work is dropped. Joined together, the chunks are the same audio `say()` gives.

`stream()` takes one text per call. To stream many texts at once, call it once per text, each from its own thread. All the calls share the model, and Playhead runs them together on the GPU:

```python
from concurrent.futures import ThreadPoolExecutor

texts = ["Merhaba, size nasıl yardımcı olabilirim?", "Siparişiniz yola çıktı.", "Randevunuz onaylandı, görüşmek üzere."]


def stream_one(text):
    chunks = []
    for chunk in tts.stream(text):
        chunks.append(chunk)                    # in a real app: send it to this caller right away
    return chunks


with ThreadPoolExecutor(max_workers=len(texts)) as pool:
    results = list(pool.map(stream_one, texts))  # one list of chunks per text, in the same order
```

### `.lightning()`: the fast path on NVIDIA GPUs

```python
tts = EMA().lightning()
```

Call it once at startup. It measures the best batch size for your GPU (once, then cached), compiles the model, records CUDA graphs, checks them against the plain path and prints when it's ready, with its first-audio time. Without it, or on a CPU, everything works the same, just slower.

| Option | Values | Default |
|---|---|---|
| `speed` | 0.25 to 4 | 1.0 |
| `seed` | non-negative integer; the same seed gives the same audio | random (returned in `speech.seed`) |
| `sample_rate` | 48000, 24000, 16000, 8000 | 48000 |
| `path` | `say()` only: a `.wav` file for one text, a folder for a list | none |

Any text is accepted, and text never raises. Invalid settings raise `ValueError` before any work starts.

## One model, many callers

![Playhead: callers, the two queues and the GPU, and one turn of the loop](assets/playhead.svg)

Every `say()` and `stream()` call goes through Playhead, a scheduler inside `EMA`. A GPU making one sentence at a time is mostly idle, so Playhead collects what every caller needs at that moment and runs it together. It keeps two first-come-first-served queues: sentences waiting for the model, and audio windows waiting for the decoder. Each turn, it takes up to one batch from the front of each, makes them in one pass each on the GPU, and hands every window straight back to the call that asked for it, in order. Nobody's sentences are overtaken, a caller who hangs up leaves the queues, and a batch that fails fails only its own callers.

On one RTX PRO 6000, 64 streams started at the same instant made 887 seconds of audio in 0.74 seconds, and every one matched its text said alone.

## Benchmarks

Freya-TR-Eval, all 495 sentences, speed 1.0:

| # | System | Params | Size vs EMA | WER % | CER % | RTF | × real time | x real time (batch 64) | GPU memory |
|---|---|---|---|---|---|---|---|---|---|
| 1 | **EMA Lightning (compiled)** | **5.6M DiT + 3M decoder** | **1×** | **0.92 ± 0.13** | **0.18** | **0.0023** | **440×** | **1,316×** | — |
| 1 | **EMA Lightning (plain PyTorch)** | **5.6M DiT + 3M decoder** | **1×** | **0.92 ± 0.13** | **0.18** | **0.0115** | **87×** | **952×** | **0.28 GB; 1.39 GB at batch 64** |
| 2 | Trendyol-TTS | 2.38B | 277× | 0.98 ± 0.15 | 0.19 ± 0.03 | 0.360 | 2.8× | — | — |
| 3 | Gemini 3.8 Flash-Lite | — | — | 1.31 ± 0.13 | 0.28 ± 0.02 | — | — | — | — |
| 4 | Gemini 3.8 Flash | — | — | 1.35 ± 0.23 | 0.28 ± 0.06 | — | — | — | — |
| 5 | ElevenLabs v4 | — | — | 1.43 ± 0.12 | 0.27 ± 0.03 | — | — | — | — |
| 6 | ElevenLabs v4 Turbo | — | — | 1.54 ± 0.22 | 0.29 ± 0.04 | — | — | — | — |
| 7 | Anka TTS † | 336M | 39× | 1.73 ± 0.05 | 0.41 ± 0.05 | 0.160 | 6.3× | — | — |
| 8 | Chatterbox MTL † | 500M | 58× | 1.84 ± 0.20 | 0.41 ± 0.08 | 0.379 | 2.6× | — | — |
| 9 | Piper (tr, dfki) † | 16M | 1.9× | 3.22 | 0.71 | 0.065 | 15× | — | — |
| 10 | XTTS-v2 (base) † | 470M | 55× | 3.34 ± 0.38 | 1.33 ± 0.20 | 0.140 | 7.1× | — | — |
| 11 | MMS-TTS (tr) † | 36M | 4.2× | 6.41 | 1.52 | 0.015 | 67× | — | — |
| 12 | Antalia 1 ‡ | 305M | 35× | 6.88 ± 0.34 | 2.72 ± 0.21 | 0.328 | 3.0× | — | — |
| 13 | Coqui GlowTTS (tr) † | 28M | 3.3× | 10.75 | 2.92 | 0.016 | 63× | — | — |
| 14 | FreyaTTS † | 183M | 21× | 12.02 | 4.95 | 0.119 | 8.4× | — | — |
| 15 | F5 base (no Turkish) † | 336M | 39× | 77.84 ± 0.13 | 32.58 ± 0.54 | 0.146 | 6.8× | — | — |
 

- **Our runs** (every row without †): all 495 sentences, 3 seeds or takes, raw text in, an 8 kHz band, Whisper large-v3 with beam 5, and Freya's text normalisation. ElevenLabs uses its default voice (George) with default settings. Gemini uses the voice Kore.
- **† marks numbers as reported on the Anka TTS model card.**
- **All RTFs are measured on an RTX 4090**, as total generation time divided by total audio length, three passes after a warm-up, middle pass reported. Cloud APIs have no RTF or parameter count.
- **"±" is the spread across the three seeds.** EMA Lightning's spread comes from its lowest, highest and average result (0.79 to 1.05%); its CER has no spread.
- **‡** "Antalia 1" by Sezgin Saygili, Emre Kaplaner, Oncel Ozgul and Fikri San Koktas (Patientdesk.ai): [huggingface.co/cloud0day3/antalia-1](https://huggingface.co/cloud0day3/antalia-1). Three of its takes failed inside its own code and count as silence.

### Speed and cost

All on an RTX 4090 with `.lightning()`:

| | |
|---|---|
| One request | 440× real time (RTF 0.0023) |
| First audio, typical | 3.86 ms, from raw text, normalisation included |
| Batch of 64 | 1,316× real time; plain PyTorch 952× |
| A 6 h 7 min audiobook, batched | about 17 seconds |
| Cost at $0.74/hour | about $0.0085 per million characters (24,091 characters a second) |
| CPU | about 6× real time (RTF 0.166, measured on a cloud-container CPU) |

## Architecture

**Figure 1 (top of this card).** **(a)** Overview. Normalized Turkish text is encoded per letter; a duration predictor and a word–letter timeline place every output frame at a word and a position within it; a windowed aligner builds one condition per frame; a latent generator produces 64-dimensional latents at 25 Hz in four steps; a decoder upsamples them ×1920 to 48 kHz audio. **(b)** Windowed Gaussian aligner. Each frame attends only to letters of its own word and the adjacent words, with a Gaussian bias around its position. **(c)** DiT block with shared timestep modulation. One linear layer maps the timestep embedding to all modulation parameters; each of the six blocks adds a learned offset.

| Part | File | Parameters |
|---|---|---|
| Acoustic model: text encoder, durations, windowed aligner and the DiT latent generator | `ema.pt` | 5.6M |
| Vocoder: the HiFi-GAN-style decoder from latents to 48 kHz audio | `decoder.pt` | 3.0M |
| **Total** | | **8.6M** |

The acoustic model stays at 5.6M partly through shared modulation (Fig. 1c, below): one projection serves all six DiT blocks, which takes the modulation parameters from 1.81M to 0.31M.

**Text encoder.** Input text is normalized to spoken-form Turkish with [normalizer-tr](https://github.com/erdemtuna/normalizer-tr) and lowercased. Letters are embedded in *d* = 224 dimensions and encoded by four ConvNeXt blocks followed by two self-attention blocks with RoPE, giving **h** ∈ ℝ<sup>*L*×*d*</sup>.
 
**Word–letter timeline.** A convolutional duration predictor estimates the number of frames *d̂*<sub>ℓ</sub> for each letter ℓ. Durations are grouped by word: each word receives the frames of its letters, and each letter receives a position *π*<sub>ℓ</sub> ∈ [0, 1] within its word *w*<sub>ℓ</sub>. Each output frame *f* is likewise assigned a word *w*<sub>*f*</sub> and a position *π*<sub>*f*</sub>. The duration model is trained without external alignments.
 
**Windowed Gaussian aligner (Fig. 1b).** With *p* = *w* + *π*, frame *f* attends to letter ℓ through
 
$$
\alpha_{f\ell} = \operatorname{softmax}_{\ell}\left( \tau \, \frac{\mathbf{q}_f^{\top} \mathbf{k}_\ell}{\sqrt{d}} - \beta \, \frac{(p_f - p_\ell)^2}{2\sigma^2} \right), \qquad |w_f - w_\ell| \le 1, \tag{1}
$$
 
$$
\mathbf{c}_f = \mathbf{W}_o \sum_{\ell} \alpha_{f\ell} \, \mathbf{v}_\ell, \tag{2}
$$
 
where **q**<sub>*f*</sub> and **k**<sub>ℓ</sub> are rotated by RoPE at *p*<sub>*f*</sub> and *p*<sub>ℓ</sub>, and *τ*, *β* and *σ* are learned per head. Letters outside the window are masked. The conditions **c** ∈ ℝ<sup>*T*×*d*</sup> are computed once per utterance.
 
**Latent generator with shared modulation (Fig. 1c).** Six DiT blocks (8 heads, RoPE over frames, SwiGLU feed-forward) predict a flow-matching velocity on latents **z** ∈ ℝ<sup>*T*×64</sup>. Instead of one adaptive-norm projection per block, a single projection **W** is shared by all blocks:
 
$$
[\boldsymbol{\gamma}_1, \boldsymbol{\beta}_1, \boldsymbol{\alpha}_1, \boldsymbol{\gamma}_2, \boldsymbol{\beta}_2, \boldsymbol{\alpha}_2]_k = \mathbf{W} \, \operatorname{SiLU}(\mathbf{e}(t)) + \boldsymbol{\delta}_k, \tag{3}
$$
 
$$
\operatorname{Mod}(\mathbf{x}) = \operatorname{LN}(\mathbf{x}) \odot (1 + \boldsymbol{\gamma}) + \boldsymbol{\beta}, \tag{4}
$$
 
with a learned offset **δ**<sub>*k*</sub> ∈ ℝ<sup>6×*d*</sup> per block. This reduces the modulation parameters from 1.81M to 0.31M.
 
**Sampling: four steps, distilled with DMD2.** The latent generator was first trained as an ordinary flow-matching model. That teacher has the same architecture and the same 5.6M parameters, and samples with 16 midpoint steps: 32 passes of the network per sentence. The shipped generator is a student distilled from it with DMD2 ([Yin et al., 2024](https://arxiv.org/abs/2405.14867)), and it needs four steps, at *t* ∈ {0, ¼, ½, ¾}. Each step predicts the clean latents
 
$$
\hat{\mathbf{z}}_1 = \mathbf{z}_t + (1 - t)\, v_\theta(\mathbf{z}_t, t, \mathbf{c}), \tag{5}
$$

**Decoder.** A HiFi-GAN-style generator with upsampling factors (8, 6, 5, 2, 2, 2) maps the 25 Hz latents to 48 kHz audio. Latents are decoded in 4 s windows with 8 frames of context on each side, so the joined output is identical to decoding the whole utterance at once; a stream's first window is 1 s, so its first audio comes early.
 
**Inference.** `.lightning()` enables cuDNN benchmark mode, compiles the model once for any batch size, and records CUDA graphs at batch sizes 1, 2, 4 and every multiple of 8 up to the measured batch size, for length buckets of 32, 64, 128 and 256 letters and 40, 80, 160 and 320 frames, and decoder windows of 48 and 120 frames. Each batch is padded only to the nearest recorded size. The compiled path is verified against the eager path at startup.

## Files

| File | What it is |
|---|---|
| `ema.pt` | acoustic model: text encoder, durations, aligner, latent generator (5.6M) |
| `decoder.pt` | decoder, latents to 48 kHz audio (3M) |
| `assets/architecture.png` | the architecture figure |
| `assets/playhead.png` | the Playhead figure |
| `samples/` | the example clips under [Listen](#listen), made with `say()` at seed 0 |

## Training data

An internal corpus of about 1,000 hours of single-speaker Turkish speech, all synthetic, generated with [VoxCPM2](https://huggingface.co/openbmb/VoxCPM2) (OpenBMB, Apache 2.0). The voice is not a real person's: it was designed in VoxCPM2 from a short text description, with no recording of anyone as a reference.

## Limitations

- **One voice.** No voice cloning and no emotion control.
- **Turkish only.** Foreign words are read with Turkish spelling rules.
- **Naturalness is good, not the best.** UTMOS is about 3.30 on Freya-TR-Eval: level with ElevenLabs v4 (3.30), below Gemini 3.8 (3.52 to 3.61) and Trendyol-TTS (3.83).
- **WER is measured by Whisper,** so some of the counted errors are the recogniser's.

## Responsible use
 
EMA Lightning makes synthetic speech, and people who hear it should know that. Tell listeners they are hearing an AI-generated voice, for example at the start of a call ("Bu görüşmede yapay zekâ ile üretilmiş bir ses kullanılmaktadır."), and label the audio you publish the same way ("Bu ses yapay zekâ ile üretilmiştir."); laws in many places, including the EU AI Act, require this disclosure. Do not present it as a real person's voice, use it in scams or impersonation, or make it say things a real person did not say. Numbers, dates and abbreviations are read through automatic text normalization, which can misread unusual input, so for banking, health, legal or emergency messages, have a person check the text and the audio before it reaches anyone.

## Disclaimer
 
EMA Lightning is provided "as is", without warranty of any kind, under the Apache License 2.0. The authors are not liable for how it is used or for any damage arising from its use. Whoever deploys it is responsible for using it lawfully, including the disclosure and consent rules that apply where it is used. This section is not legal advice.

## License

Apache 2.0, for the weights and the code. Commercial use included.

## Acknowledgements

Special thanks to **[Erdem Tuna](https://github.com/erdemtuna)**, who built [normalizer-tr](https://github.com/erdemtuna/normalizer-tr), the Turkish text normalizer behind EMA Lightning. Every number, date, amount and symbol you hear read aloud goes through his work.

Thanks also to **Freya** for the Freya-TR-Eval benchmark, and to **the Anka TTS authors** for the published baselines marked †.

## Citation

```bibtex
@misc{aslan2026emalightning,
  title        = {EMA Lightning: Tiny, Fast and Accurate Turkish Text to Speech},
  author       = {Aslan, Canberk},
  year         = {2026},
  howpublished = {\url{https://huggingface.co/canberkkkkkk/ema-lightning}}
}
```

[github]: https://github.com/canberk7/ema-lightning