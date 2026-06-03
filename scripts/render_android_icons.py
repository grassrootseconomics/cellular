#!/usr/bin/env python3
from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE_SVG = ROOT / "graphics" / "favicon.svg"
ANDROID_DIR = ROOT / "graphics" / "android"
REFERENCE_SIZE = 1024


def render_svg_reference(svg_path: Path, png_path: Path) -> None:
    chrome_bin = (
        shutil.which("google-chrome")
        or shutil.which("chromium")
        or shutil.which("chromium-browser")
    )
    if chrome_bin is not None:
        subprocess.run(
            [
                chrome_bin,
                "--headless=new",
                "--disable-gpu",
                "--no-sandbox",
                "--default-background-color=00000000",
                f"--screenshot={png_path}",
                f"--window-size={REFERENCE_SIZE},{REFERENCE_SIZE}",
                svg_path.resolve().as_uri(),
            ],
            check=True,
        )
        return

    convert_bin = shutil.which("magick") or shutil.which("convert")
    if convert_bin is None:
        raise SystemExit("Chrome or ImageMagick convert/magick is required to render Android icons.")

    command = [convert_bin]
    if Path(convert_bin).name == "magick":
        command.append("convert")
    command.extend([
        "-background",
        "none",
        str(svg_path),
        "-resize",
        f"{REFERENCE_SIZE}x{REFERENCE_SIZE}",
        "-depth",
        "8",
        f"PNG32:{png_path}",
    ])
    subprocess.run(command, check=True)


def resize_png(source_path: Path, png_path: Path, size: int) -> None:
    convert_bin = shutil.which("magick") or shutil.which("convert")
    if convert_bin is None:
        raise SystemExit("ImageMagick convert/magick is required to resize Android icons.")

    command = [convert_bin]
    if Path(convert_bin).name == "magick":
        command.append("convert")
    command.extend([
        str(source_path),
        "-resize",
        f"{size}x{size}",
        "-depth",
        "8",
        f"PNG32:{png_path}",
    ])
    subprocess.run(command, check=True)


def main() -> None:
    ANDROID_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        rendered_path = Path(tmp) / "favicon-browser.png"
        render_svg_reference(SOURCE_SVG, rendered_path)
        resize_png(rendered_path, ANDROID_DIR / "launcher_adaptive_background_432.png", 432)
        resize_png(rendered_path, ANDROID_DIR / "launcher_adaptive_foreground_432.png", 432)
        resize_png(rendered_path, ANDROID_DIR / "launcher_adaptive_monochrome_432.png", 432)
        resize_png(rendered_path, ANDROID_DIR / "launcher_main_192.png", 192)


if __name__ == "__main__":
    main()
