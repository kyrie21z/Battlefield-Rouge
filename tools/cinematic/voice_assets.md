# Offline Mandarin voice assets

The 23 WAV files are synthesized offline from this project's original dialogue:
- **17 Crown (Pride) clips** (`opening/{wake,care,obstacle,better,invitation}`, `dynamic/*`, `climax/crown_breakdown`): synthesized with unmodified `openbmb/VoxCPM2` (Apache-2.0) using an original Voice Design anchor (`quiet_01`, seed `107`, not a clone of any named person) and stage-specific style instructions, resampled to 24 kHz mono PCM16 WAV (peak `0.92`, `120/180 ms` clean ends), and human-auditioned line by line.
- **6 non-Crown clips** (`opening/interview` and the 5 player inner-voice climax lines): retained from the unmodified official `hexgrad/Kokoro-82M-v1.1-zh` model (`zm_010`, Apache-2.0).

## Sources and rights

- Model: https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh
- Fixed model revision: `01e7505bd6a7a2ac4975463114c3a7650a9f7218`.
- Fixed model card: https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh/blob/01e7505bd6a7a2ac4975463114c3a7650a9f7218/README.md
- The publisher marks the weights Apache-2.0. The model card states that its
  professional Chinese training data was permissively granted by LongMaoData.
  This records the publisher's statement; it is not an independent audit of
  every training item or a claim of exclusive copyright in synthetic output.
- Official Chinese preset example: https://huggingface.co/hexgrad/Kokoro-82M-v1.1-zh/blob/01e7505bd6a7a2ac4975463114c3a7650a9f7218/samples/make_zh.py
- Inference code: https://github.com/hexgrad/kokoro ; package `kokoro==0.9.4`,
  Apache-2.0. The unchanged distributed license is retained in
  `licenses/KOKORO-APACHE-2.0.txt`.
- G2P: https://github.com/hexgrad/misaki ; package `misaki==0.9.4`, Apache-2.0.
- The game distributes only generated WAV files and its original scripts, not
  the model, voice tensors, inference engine, or dependencies. Generated WAVs
  are not labeled CC0 and are not copies of the previous Windows SAPI output.
- Previous Microsoft Huihui Desktop output was replaced because no explicit
  output redistribution grant was established from desktop Windows terms.
  Azure Speech terms do not establish rights for desktop SAPI output.

## Reproduction

Use a disposable Python 3.11 virtual environment. The synthesis run does not
modify any existing ML environment. Download only the fixed model's config,
weight, `voices/zf_001.pt`, `voices/zm_010.pt`, README and Chinese example to a
folder outside the repository. Verify their SHA-256 values against the model
section of `voice_assets_manifest.json`, and save that section as `manifest.json`
in the external model folder. The weight's publisher-provided SHA-256 is
`b1d8410fa44dfb5c15471fd6c4225ea6b4e9ac7fa03c98e8bea47a9928476e2b`.

```sh
python3.11 -m venv /tmp/mind-freak-voice
/tmp/mind-freak-voice/bin/pip install kokoro==0.9.4 'misaki[zh]==0.9.4' 'transformers==4.57.6' soundfile
/tmp/mind-freak-voice/bin/python tools/cinematic/generate_voice_assets.py --model-dir /path/outside/repo/kokoro-zh
```

Generation uses CPU, a fixed per-line random seed, local voice tensors and
`HF_HUB_OFFLINE=1` / `TRANSFORMERS_OFFLINE=1`. It adds 120/180 ms clean ends and
normalizes peak amplitude to 0.92 without changing pitch or tempo. All outputs
are 24 kHz mono PCM16 WAV. Exact package versions, original texts, speed,
phonemes, durations, peak/RMS, clipped samples and SHA-256 are in the manifest.

## Godot verification by issue

Import the current checkout first. The default verifies all 23 clips after the
complete Epic 4 stack is assembled. Individual issue prefixes can load only the
clips belonging to that issue, so future PR assets need not exist yet:

```sh
godot --headless --path <repo> --editor --import --quit
godot --headless --path <repo> --script res://tools/cinematic/verify_voice_assets.gd -- --issue=147
godot --headless --path <repo> --script res://tools/cinematic/verify_voice_assets.gd -- --issue=148
godot --headless --path <repo> --script res://tools/cinematic/verify_voice_assets.gd -- --issue=149
godot --headless --path <repo> --script res://tools/cinematic/verify_voice_assets.gd -- --issue=150
# Complete Epic 4 only:
godot --headless --path <repo> --script res://tools/cinematic/verify_voice_assets.gd
```

The manifest's `issue` field selects 6 / 11 / 5 / 1 clips respectively. Every
selected clip must import, match its declared format and duration, advance, and
emit `finished`; missing selected files fail verification. Unknown or repeated
selectors exit with status 2. Omitting the selector retains the full 23-clip check.

## Verification boundary

The evidence covers nonempty finite waveform output, complete phonemized
source lines, zero clipped samples, exact hashes, Godot resource import and
runtime playback completion. The agent has no audio listening input in this
session. There is no claim of human listening approval, pronunciation review,
or professional emotional acting. Punctuation and speech speed provide
reproducible delivery differences; listening remains an artistic review item.
