"""Restore a standalone Sloth reserve from a pinned tracked base plus an overlay.

The main checkout is read-only. No network, engine installation or Git mutation.
Usage: python prototypes/sloth_enemy_reserve/prepare.py --out <new-directory>
"""

from __future__ import annotations

import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import tarfile


BASE_COMMIT = "438fa73e99311607bb6a5d2a0617bf59a7a7b09f"
PACKAGE = Path(__file__).resolve().parent
REPOSITORY = PACKAGE.parents[1]


def checked_git(*args: str, cwd: Path = REPOSITORY) -> bytes:
    return subprocess.check_output(["git", "-C", str(cwd), *args])


def verify_payload() -> None:
    manifest = json.loads((PACKAGE / "payload.json").read_text(encoding="utf-8"))
    if manifest["base_commit"] != BASE_COMMIT:
        raise ValueError("Payload base differs from the builder base")
    actual_overlay = {
        file.relative_to(PACKAGE).as_posix()
        for file in (PACKAGE / "overlay").rglob("*") if file.is_file()
    }
    expected_overlay = {name for name in manifest["sha256"] if name.startswith("overlay/")}
    if actual_overlay != expected_overlay:
        raise ValueError("Overlay file set differs from the manifest")
    for name, expected in manifest["sha256"].items():
        raw_path = PACKAGE / name
        if raw_path.is_symlink():
            raise ValueError(f"Symbolic links are not allowed in the payload: {name}")
        candidate = raw_path.resolve()
        if not candidate.is_relative_to(PACKAGE) or not candidate.is_file():
            raise ValueError(f"Invalid payload path: {name}")
        if hashlib.sha256(candidate.read_bytes()).hexdigest() != expected:
            raise ValueError(f"Payload checksum differs: {name}")


def prepare(output: Path) -> None:
    output = output.resolve()
    # Never overwrite the checkout, an existing demo, or another task's files.
    if output.exists() or REPOSITORY.is_relative_to(output):
        raise ValueError("Output must be a new directory outside the checkout")
    if output.is_relative_to(REPOSITORY) and not output.is_relative_to(PACKAGE / ".build"):
        raise ValueError("Inside the checkout, only this package's .build is allowed")
    verify_payload()
    # Fails before creating output if this clone lacks the pinned base commit.
    archive = checked_git("archive", "--format=tar", BASE_COMMIT)
    output.mkdir(parents=True)
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:") as source:
        for member in source.getmembers():
            name = PurePosixPath(member.name)
            destination = (output / member.name).resolve()
            if name.is_absolute() or ".." in name.parts or not destination.is_relative_to(output):
                raise ValueError(f"Unsafe archive member: {member.name}")
            if member.isdir():
                destination.mkdir(parents=True, exist_ok=True)
            elif member.isfile():
                destination.parent.mkdir(parents=True, exist_ok=True)
                stream = source.extractfile(member)
                if stream is None:
                    raise ValueError(f"Unreadable archive member: {member.name}")
                with stream, destination.open("wb") as target:
                    shutil.copyfileobj(stream, target)
            else:
                raise ValueError(f"Unsupported archive member: {member.name}")
    patch = PACKAGE / "integration.patch"
    checked_git("apply", "--check", str(patch), cwd=output)
    checked_git("apply", str(patch), cwd=output)
    overlay = PACKAGE / "overlay"
    for file in sorted(overlay.rglob("*")):
        if file.is_symlink():
            raise ValueError(f"Symbolic links are not allowed in the overlay: {file}")
        if file.is_file():
            destination = output / file.relative_to(overlay)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(file, destination)
    docs = output / "reserve-package"
    docs.mkdir()
    (docs / ".gdignore").write_text("\n", encoding="utf-8")
    for name in ["README.md", "DESIGN.md", "ASSETS.md"]:
        content = (PACKAGE / name).read_text(encoding="utf-8")
        (docs / name).write_text(content.replace("../../docs/", "../docs/"), encoding="utf-8")
    shutil.copytree(PACKAGE / "proof", docs / "proof")
    (output / "README.md").write_text(
        "# Sloth Enemy Reserve\n\n"
        "Independent review prototype; the main game is unchanged.\n\n"
        "[Instructions](reserve-package/README.md) · "
        "[Design](reserve-package/DESIGN.md) · "
        "[Results and pending work](reserve-package/proof/README.md)\n\n"
        "The default scene is the model gallery. See the current validation records for the isolated reserve.\n",
        encoding="utf-8")
    (output / "RESERVE_ORIGIN.json").write_text(
        json.dumps({"base_commit": BASE_COMMIT, "status": "isolated reserve; not integrated"}, indent=2)
        + "\n", encoding="utf-8")
    print(f"Prepared independent reserve: {output}")
    print(f'godot --editor --path "{output}" --import --quit')
    print(f'godot --path "{output}"')
    print(f'godot --path "{output}" res://maps/zone_1.tscn -- --skip-opening')
    print(f'godot --headless --fixed-fps 60 --path "{output}" res://tests/sloth_enemy_test.tscn')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", required=True, type=Path, help="New standalone output directory")
    args = parser.parse_args()
    prepare(args.out)


if __name__ == "__main__":
    main()
