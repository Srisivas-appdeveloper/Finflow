"""Builds docs/play-store/privacy-policy.html from privacy-policy.md.

The HTML is self-contained (no external files) so it can be uploaded to any
web host as the Play Store privacy policy URL.

    python3 tool/build_privacy_html.py
"""
import html
import re
from pathlib import Path

DOCS = Path(__file__).resolve().parent.parent / 'docs' / 'play-store'


def inline(text: str) -> str:
    text = html.escape(text)
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'_(.+?)_', r'<em>\1</em>', text)
    return text


def convert(md: str) -> tuple[str, str]:
    title, body, para = 'Privacy policy', [], []

    def flush():
        if para:
            body.append(f'<p>{inline(" ".join(para))}</p>')
            para.clear()

    for line in md.splitlines():
        if line.startswith('# '):
            flush()
            title = line[2:].strip()
            body.append(f'<h1>{inline(title)}</h1>')
        elif line.startswith('## '):
            flush()
            body.append(f'<h2>{inline(line[3:].strip())}</h2>')
        elif not line.strip():
            flush()
        else:
            para.append(line.strip())
    flush()
    return title, '\n'.join(body)


def main() -> None:
    title, body = convert((DOCS / 'privacy-policy.md').read_text())
    page = f'''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{html.escape(title)}</title>
<style>
  :root {{ color-scheme: light dark; --fg: #0e1130; --muted: #4a4f75;
    --bg: #f4f5fd; --card: #ffffff; --accent: #5b4bdb; }}
  @media (prefers-color-scheme: dark) {{
    :root {{ --fg: #f4f5ff; --muted: #a9aecf; --bg: #060816;
      --card: #12152b; --accent: #b4a9ff; }} }}
  body {{ margin: 0; background: var(--bg); color: var(--fg);
    font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }}
  main {{ max-width: 720px; margin: 0 auto; padding: 32px 16px 64px; }}
  article {{ background: var(--card); border-radius: 20px;
    padding: 28px clamp(18px, 5vw, 40px); }}
  h1 {{ font-size: 1.8rem; line-height: 1.2; margin: 0 0 8px; }}
  h2 {{ font-size: 1.1rem; margin: 28px 0 6px; color: var(--accent); }}
  p {{ margin: 0 0 12px; }}
  em {{ color: var(--muted); font-style: normal; }}
</style>
</head>
<body>
<main><article>
{body}
</article></main>
</body>
</html>
'''
    (DOCS / 'privacy-policy.html').write_text(page)
    print('wrote', DOCS / 'privacy-policy.html')


if __name__ == '__main__':
    main()
