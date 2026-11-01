"""Export a primary PNG icon from a built iOS app without modifying its bundle."""
from __future__ import annotations

from pathlib import Path
import plistlib
import re
import tempfile

from validate import run


def icon_names(info: dict[str, object]) -> list[str]:
    names: list[str] = []
    for key in ('CFBundleIcons', 'CFBundleIcons~ipad'):
        icons = info.get(key)
        if not isinstance(icons, dict):
            continue
        primary = icons.get('CFBundlePrimaryIcon')
        if isinstance(primary, dict):
            files = primary.get('CFBundleIconFiles')
            if isinstance(files, list):
                names.extend(name for name in files if isinstance(name, str) and name)
    if not names:
        files = info.get('CFBundleIconFiles')
        if isinstance(files, list):
            names.extend(name for name in files if isinstance(name, str) and name)
        single = info.get('CFBundleIconFile')
        if isinstance(single, str) and single:
            names.append(single)
    return names


def image_size(path: Path) -> tuple[int, int]:
    output = run('sips', '-g', 'pixelWidth', '-g', 'pixelHeight', str(path))
    dimensions = dict(re.findall(r'^\s*(pixelWidth|pixelHeight):\s*(\d+)\s*$', output, re.MULTILINE))
    if dimensions.keys() != {'pixelWidth', 'pixelHeight'} or any(int(value) <= 0 for value in dimensions.values()):
        raise ValueError(f'Cannot read icon dimensions: {path}')
    return int(dimensions['pixelWidth']), int(dimensions['pixelHeight'])


def primary_icon(app: Path) -> Path:
    app = app.resolve(strict=True)
    info = plistlib.loads((app / 'Info.plist').read_bytes())
    if not isinstance(info, dict):
        raise ValueError('Expected an Info.plist dictionary')
    candidates: set[Path] = set()
    for name in icon_names(info):
        relative = Path(name)
        if relative.is_absolute() or '..' in relative.parts:
            raise ValueError(f'Icon path escapes the App Bundle: {name}')
        stem = relative.name[:-4] if relative.name.lower().endswith('.png') else relative.name
        pattern = re.compile(re.escape(stem) + r'(?:@\d+x)?(?:~(?:iphone|ipad))?\.png', re.IGNORECASE)
        parent = app / relative.parent
        if not parent.is_dir():
            continue
        for path in parent.iterdir():
            if not path.is_file() or not pattern.fullmatch(path.name):
                continue
            if not path.resolve(strict=True).is_relative_to(app):
                raise ValueError(f'Icon path escapes the App Bundle: {path}')
            candidates.add(path)
    if not candidates:
        raise ValueError('No primary PNG icon found in the App Bundle; Assets.car-only icons are not supported')
    dimensions = {path: image_size(path) for path in candidates}
    return max(candidates, key=lambda path: (dimensions[path][0] * dimensions[path][1], path.name))


def export_icon(app: Path, output: Path) -> None:
    app = app.resolve(strict=True)
    output = output.resolve()
    if output.is_relative_to(app):
        raise ValueError('Icon output must be outside the App Bundle')
    source = primary_icon(app)
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='.icon-', dir=output.parent) as temporary:
        image = Path(temporary) / 'icon.png'
        run('sips', '-s', 'format', 'png', str(source), '--out', str(image))
        image.replace(output)
