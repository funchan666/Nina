from pathlib import Path
from base64 import b64encode


website = Path(__file__).resolve().parent
app_legal = website.parent / "Nina" / "Resources" / "Legal"
assets = website / "dist" / "assets"
style = (assets / "site.css").read_text(encoding="utf-8")
# The fallback is granted read access to its HTML file only, so fonts stay inline.
for name in ("Barlow-Regular.woff", "Barlow-SemiBold.woff", "BarlowCondensed-Bold.woff"):
    encoded = b64encode((assets / name).read_bytes()).decode("ascii")
    style = style.replace(f'url("{name}")', f'url("data:font/woff;base64,{encoded}")')

for name, title in (("terms", "Terms of Use"), ("privacy", "Privacy Policy")):
    path = website / "dist" / f"{name}.html"
    source = path.read_text(encoding="utf-8")
    marker = '<article class="policy" id="policy-content">'
    start = source.index(marker)
    end = source.index("</article>", start) + len("</article>")
    article = source[start:end]
    page = f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<title>{title}</title>
<style>
{style}
</style>
</head>
<body class="policy-offline">
{article}
</body>
</html>
"""
    (app_legal / path.name).write_text(page, encoding="utf-8")
