"""Build Nina's media-only resource ZIP. Optionally pass a folder of catalog media."""
import hashlib
import json
from pathlib import Path
import plistlib
import re
import sys
from tempfile import NamedTemporaryFile
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo

root = Path(__file__).resolve().parents[1]
resources = root / "Nina/Resources"
catalog = json.loads((resources / "LinesCatalog.json").read_bytes())
app_name = plistlib.loads((resources / "Info.plist").read_bytes())["CFBundleDisplayName"]
destination = resources / f"{app_name}.zip"
filenames = {item[field] for item in catalog for field in ("path", "poster") if item.get(field)}
if not filenames or len(filenames) > 512 or any(not re.fullmatch(r"[a-z0-9][a-z0-9.-]*", name) for name in filenames):
    raise SystemExit("The catalog has an invalid media filename.")

if len(sys.argv) > 2:
    raise SystemExit("Usage: python3 scripts/package-media.py [media-directory]")
if len(sys.argv) == 2:
    source = Path(sys.argv[1])
    if {file.name for file in source.iterdir() if file.is_file()} != filenames:
        raise SystemExit("The media directory must match the complete catalog.")
    files = {f"media/{name}": (source / name).read_bytes() for name in filenames}
else:
    with ZipFile(destination) as archive:
        names = archive.namelist()
        expected = {f"media/{name}" for name in filenames}
        if len(names) != len(set(names)) or {name for name in names if name.startswith("media/")} != expected:
            raise SystemExit("The current media package does not match the complete catalog.")
        if sum(archive.getinfo(name).file_size for name in expected) > 64 * 1024 * 1024:
            raise SystemExit("The media package exceeds the extraction limit.")
        files = {name: archive.read(name) for name in expected}

if sum(map(len, files.values())) > 64 * 1024 * 1024:
    raise SystemExit("The media package exceeds the extraction limit.")
hashes = {name: hashlib.sha256(data).digest() for name, data in files.items()}
with NamedTemporaryFile(dir=resources, prefix=".media-", suffix=".zip", delete=False) as output:
    temporary = Path(output.name)
try:
    with ZipFile(temporary, "w") as archive:
        for name, data in sorted(files.items()):
            info = ZipInfo(name)
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            archive.writestr(info, data, compress_type=ZIP_DEFLATED, compresslevel=9)
    with ZipFile(temporary) as archive:
        if set(archive.namelist()) != set(files) or archive.testzip() is not None:
            raise SystemExit("The new media package could not be verified.")
        for name, digest in hashes.items():
            if hashlib.sha256(archive.read(name)).digest() != digest:
                raise SystemExit(f"Media bytes changed while packaging: {name}")
    temporary.chmod(0o644)
    temporary.replace(destination)
finally:
    temporary.unlink(missing_ok=True)
print(json.dumps({"archive": str(destination.relative_to(root)), "files": len(files),
                  "bytes": destination.stat().st_size, "expandedBytes": sum(map(len, files.values()))}))
