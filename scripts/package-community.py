from json import loads
from pathlib import Path
from plistlib import load
from shutil import copyfile
from tempfile import NamedTemporaryFile
from zipfile import ZIP_DEFLATED, ZipFile, ZipInfo


root = Path(__file__).resolve().parents[1]
resources = root / "Nina/Resources"
community = root / "web/community"
art = root / "assets/brand/exports"
glyphs = root / "assets/navigation/glyphs"

with (resources / "Info.plist").open("rb") as plist:
    app_name = load(plist)["CFBundleDisplayName"]

art_sources = {f"art/{name}": art / name for name in ("welcome-ground.jpg", "wheel-mark.jpg")}
for name in ("check", "spot", "crew", "lines", "like", "save"):
    art_sources[f"art/ink-{name}.png"] = glyphs / f"ink-{name}.png"
for name in ("Barlow-Regular.ttf", "Barlow-SemiBold.ttf", "BarlowCondensed-Bold.ttf",
             "Barlow-OFL.txt", "BarlowCondensed-OFL.txt"):
    art_sources[f"fonts/{name}"] = resources / "Fonts" / name
for name, source in art_sources.items():
    destination = community / name
    destination.parent.mkdir(parents=True, exist_ok=True)
    copyfile(source, destination)

lines = loads((resources / "LinesCatalog.json").read_bytes())
media = {item[field] for item in lines for field in ("path", "poster") if item[field]}
media_root = community / "media"
if {file.name for file in media_root.iterdir()} != media:
    raise SystemExit("The bundled media directory must match the Lines catalog.")

names = {"index.html", "community.css", "community/community.js", *art_sources}
names.update(f"media/{name}" for name in media)
files = {name: community / name for name in names}

with NamedTemporaryFile(dir=resources, delete=False) as output:
    temporary = Path(output.name)
    try:
        with ZipFile(output, "w") as archive:
            for name, source in sorted(files.items()):
                archive.writestr(ZipInfo(name), source.read_bytes(), compress_type=ZIP_DEFLATED, compresslevel=9)
        output.flush()
        temporary.chmod(0o644)
        temporary.replace(resources / f"{app_name}.zip")
    finally:
        temporary.unlink(missing_ok=True)
