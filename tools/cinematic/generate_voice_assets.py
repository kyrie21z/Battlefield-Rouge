#!/usr/bin/env python3
"""Render the 23 original Mandarin lines with a pinned, local Kokoro model.

The model directory is external to the project. No network access is required
during generation; see voice_assets.md for acquisition and licensing sources.
"""
import argparse
import hashlib
import importlib.metadata
import json
import os
from pathlib import Path

os.environ["HF_HUB_OFFLINE"] = "1"
os.environ["TRANSFORMERS_OFFLINE"] = "1"
os.environ["TOKENIZERS_PARALLELISM"] = "false"

import numpy as np
import soundfile as sf
import torch
from kokoro import KModel, KPipeline


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", required=True, type=Path)
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--lines", type=Path, default=Path(__file__).with_name("voice_lines.json"))
    parser.add_argument("--only", help="Render a filename stem for a local smoke check")
    args = parser.parse_args()
    source = json.loads((args.model_dir / "manifest.json").read_text())
    for asset in source["files"]:
        path = args.model_dir / asset["path"]
        assert digest(path) == asset["sha256"], f"Model file changed: {path}"
    torch.set_num_threads(4)
    torch.use_deterministic_algorithms(True)
    model = KModel(
        repo_id=source["repo"], config=str(args.model_dir / "config.json"),
        model=str(args.model_dir / source["weight_file"]),
    ).to("cpu").eval()
    pipeline = KPipeline(lang_code="z", repo_id=source["repo"], model=model)
    lines = json.loads(args.lines.read_text())
    records = []
    for index, line in enumerate(lines):
        if args.only and Path(line["path"]).stem != args.only:
            continue
        seed = 14700 + index
        torch.manual_seed(seed)
        voice_path = args.model_dir / "voices" / (line["voice"] + ".pt")
        segments = list(pipeline(line["text"], voice=str(voice_path), speed=line["speed"]))
        assert segments and all(s.audio is not None for s in segments), line["path"]
        audio = np.concatenate([s.audio.detach().cpu().numpy() for s in segments])
        assert np.isfinite(audio).all() and audio.size >= 2400, line["path"]
        raw_peak = float(np.max(np.abs(audio)))
        assert raw_peak > 0.001, f"Silent synthesis: {line['path']}"
        # Keep amplitude consistent without changing pitch, tempo, or dynamics.
        gain = 0.92 / raw_peak
        audio = np.pad(audio * gain, (2880, 4320))  # 120/180 ms clean ends.
        target = args.project / line["path"]
        target.parent.mkdir(parents=True, exist_ok=True)
        sf.write(target, audio, 24000, subtype="PCM_16", format="WAV")
        actual, rate = sf.read(target, dtype="float32")
        record = {
            **line, "seed": seed, "sample_rate": rate, "channels": 1,
            "sample_width_bits": 16, "frames": len(actual),
            "duration_seconds": len(actual) / rate, "bytes": target.stat().st_size,
            "peak": float(np.max(np.abs(actual))),
            "rms": float(np.sqrt(np.mean(actual * actual))),
            "nonzero_samples": int(np.count_nonzero(actual)),
            "clipped_samples": int(np.count_nonzero(np.abs(actual) >= 1)),
            "normalization_gain": gain, "sha256": digest(target),
            "phonemes": [s.phonemes for s in segments],
        }
        records.append(record)
        print(f"#{line['issue']} {target.name}: {record['duration_seconds']:.3f}s {record['sha256']}", flush=True)
    manifest = {
        "engine": "kokoro", "engine_license": "Apache-2.0",
        "model": source, "device": "cpu", "offline_generation": True,
        "human_listening_review": False,
        "validation_scope": "Waveform, original script, hashes and in-game playback; no claim of human listening or acted emotional quality.",
        "packages": {name: importlib.metadata.version(name) for name in [
            "kokoro", "misaki", "torch", "transformers", "soundfile", "numpy", "pypinyin", "jieba",
        ]},
        "lines_sha256": digest(args.lines), "clips": records,
    }
    suffix = ".smoke" if args.only else ""
    destination = args.project / f"tools/cinematic/voice_assets_manifest{suffix}.json"
    destination.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print(f"Wrote {len(records)} clips and {destination}", flush=True)


if __name__ == "__main__":
    main()
