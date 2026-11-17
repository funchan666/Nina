from pathlib import Path


website = Path(__file__).resolve().parent
app_legal = website.parent / "Nina" / "Resources" / "Legal"
style = """
:root { background: #f5f0e5; color: #182620; }
body { margin: 0 auto; max-width: 42rem; padding: 1.2rem; font: -apple-system-body; line-height: 1.55; }
header { margin-bottom: 1.7rem; }
.caption { color: #516254; font: -apple-system-subheadline; }
h1 { font: -apple-system-title1; font-weight: 700; margin: .5rem 0 .75rem; }
section { border-top: 1px solid #b6bca9; padding-top: 1rem; }
h2 { font: -apple-system-headline; margin: 0 0 .4rem; }
p { margin: 0 0 1rem; }
""".strip()

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
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{title}</title>
<style>
{style}
</style>
</head>
<body>
{article}
</body>
</html>
"""
    (app_legal / path.name).write_text(page, encoding="utf-8")
