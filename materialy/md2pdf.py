#!/usr/bin/env python3
"""
md2pdf.py — zamienia materiał Markdown na PDF A4 do druku.

Użycie:
    python3 materialy/md2pdf.py materialy/01-jak-pisac-prompty.md
    python3 materialy/md2pdf.py plik.md --out wynik.pdf --title "Tytuł w nagłówku"

Wymaga: pip install markdown, oraz Chromium (przez pakiet playwright w Node
lub binarkę chrome/chromium w PATH). Stopka ma numerację stron.
"""
import argparse, html, json, os, re, shutil, subprocess, sys, tempfile
import markdown

CSS = """
@page { size: A4; margin: 16mm 16mm 18mm 16mm; }
* { box-sizing: border-box; }
html { font-size: 10.4pt; }
body {
  font-family: "Liberation Sans", "DejaVu Sans", Arial, sans-serif;
  line-height: 1.38; color: #111; margin: 0;
}
h1 { font-size: 20pt; margin: 0 0 4mm 0; line-height: 1.2; }
h1 + p { color: #444; margin-top: 0; }
h2 {
  font-size: 14.5pt; margin: 8mm 0 3mm 0; padding-bottom: 1.2mm;
  border-bottom: 1.5px solid #222; break-after: avoid; page-break-after: avoid;
}
.pagebreak { break-before: page; page-break-before: always; }
.pagebreak + h2 { margin-top: 0; }
h3 { font-size: 11.8pt; margin: 5.5mm 0 2mm 0; break-after: avoid; page-break-after: avoid; }
h4 { font-size: 10.6pt; margin: 4.5mm 0 1.5mm 0; break-after: avoid; page-break-after: avoid; }
p { margin: 0 0 2.4mm 0; orphans: 3; widows: 3; }
ul, ol { margin: 0 0 2.6mm 0; padding-left: 5.5mm; }
li { margin-bottom: 1mm; }
li > p { margin-bottom: 1mm; }
strong { font-weight: 700; }
code {
  font-family: "DejaVu Sans Mono", "Liberation Mono", monospace;
  font-size: 8.9pt; background: #f1f1f1; padding: 0 1.5px; border-radius: 2px;
}
pre {
  font-family: "DejaVu Sans Mono", "Liberation Mono", monospace;
  font-size: 8.4pt; line-height: 1.32; background: #f4f4f4; border: 1px solid #d5d5d5;
  border-left: 3px solid #888; padding: 2.4mm 3mm; margin: 2mm 0 3.2mm 0;
  white-space: pre-wrap; overflow-wrap: anywhere; break-inside: avoid; page-break-inside: avoid;
}
pre code { background: none; padding: 0; font-size: inherit; }
table {
  border-collapse: collapse; width: 100%; margin: 2mm 0 3.5mm 0; font-size: 9.3pt;
  break-inside: auto;
}
th, td { border: 1px solid #bbb; padding: 1.3mm 2mm; vertical-align: top; text-align: left; }
th { background: #e9e9e9; font-weight: 700; }
tr { break-inside: avoid; page-break-inside: avoid; }
blockquote { margin: 2mm 0; padding: 1.5mm 3mm; border-left: 3px solid #999; color: #333; background: #fafafa; }
hr { border: 0; border-top: 1px solid #ccc; margin: 5mm 0; }
a { color: inherit; text-decoration: none; }
.toc ol { columns: 2; column-gap: 8mm; }
.toc li { break-inside: avoid; }
.bad { color: #a00; font-weight: 700; }
.good { color: #060; font-weight: 700; }
"""

def build_html(md_text: str, title: str) -> str:
    # Znaki ❌ / ✅ z czytelnymi, drukowalnymi odpowiednikami
    md_text = md_text.replace("❌", '<span class="bad">ŹLE:</span>').replace("✅", '<span class="good">DOBRZE:</span>')
    body = markdown.markdown(
        md_text,
        extensions=["tables", "fenced_code", "sane_lists", "attr_list", "md_in_html"],
        output_format="html5",
    )
    # Ręczne łamanie strony: w Markdown wstaw linię  <!-- pagebreak -->
    body = re.sub(r"<!--\s*pagebreak\s*-->", '<div class="pagebreak"></div>', body)
    # Spis treści w dwóch kolumnach: pierwsza lista <ol> po h2 "Spis treści"
    body = re.sub(r"(<h2>Spis treści</h2>\s*)<ol>", r'\1<div class="toc"><ol>', body, count=1)
    if '<div class="toc">' in body:
        body = body.replace("</ol>", "</ol></div>", 1) if body.index("</ol>") > body.index('<div class="toc">') else body
    return f"""<!doctype html><html lang="pl"><head><meta charset="utf-8">
<title>{html.escape(title)}</title><style>{CSS}</style></head><body>{body}</body></html>"""

def print_pdf(html_path: str, pdf_path: str, header_title: str) -> None:
    node_script = r"""
const {chromium} = require('playwright');
(async () => {
  const {MD_HTML: htmlPath, MD_PDF: pdfPath, MD_TITLE: title} = process.env;
  const browser = await chromium.launch();
  const page = await browser.newPage();
  await page.goto('file://' + htmlPath, {waitUntil: 'load'});
  await page.pdf({
    path: pdfPath, format: 'A4', printBackground: true, preferCSSPageSize: true,
    displayHeaderFooter: true,
    headerTemplate: `<div style="font-size:7.5pt;color:#666;width:100%;padding:0 16mm;font-family:Arial,sans-serif;">${title}</div>`,
    footerTemplate: `<div style="font-size:7.5pt;color:#666;width:100%;padding:0 16mm;font-family:Arial,sans-serif;display:flex;justify-content:space-between;"><span>Szkolenie n8n — materiał dla uczestników</span><span>Strona <span class="pageNumber"></span> z <span class="totalPages"></span></span></div>`,
    margin: {top: '16mm', bottom: '18mm', left: '16mm', right: '16mm'},
  });
  await browser.close();
})().catch(e => { console.error(e); process.exit(1); });
"""
    node_root = subprocess.run(["npm", "root", "-g"], capture_output=True, text=True).stdout.strip()
    env = dict(os.environ, NODE_PATH=node_root, MD_HTML=html_path, MD_PDF=pdf_path, MD_TITLE=header_title)
    try:
        subprocess.run(["node", "-e", node_script], check=True, env=env, capture_output=True, text=True)
        return
    except subprocess.CalledProcessError as e:
        sys.stderr.write("playwright nie zadziałał:\n" + e.stderr[-800:] + "\nPróbuję chromium z PATH\n")
    except FileNotFoundError:
        sys.stderr.write("brak node, próbuję chromium z PATH\n")
    chrome = shutil.which("chromium") or shutil.which("chromium-browser") or shutil.which("google-chrome")
    if not chrome:
        sys.exit("Brak Chromium: zainstaluj playwright (npm i -g playwright) lub chromium.")
    subprocess.run([chrome, "--headless", "--no-sandbox", "--disable-gpu", "--no-pdf-header-footer",
                    f"--print-to-pdf={pdf_path}", f"file://{html_path}"], check=True, capture_output=True)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("md")
    ap.add_argument("--out")
    ap.add_argument("--title")
    a = ap.parse_args()
    md_text = open(a.md, encoding="utf-8").read()
    m = re.search(r"^#\s+(.+)$", md_text, re.M)
    title = a.title or (m.group(1).strip() if m else os.path.basename(a.md))
    out = a.out or re.sub(r"\.md$", "", a.md) + ".pdf"
    with tempfile.TemporaryDirectory() as td:
        hp = os.path.join(td, "doc.html")
        open(hp, "w", encoding="utf-8").write(build_html(md_text, title))
        print_pdf(hp, os.path.abspath(out), title)
    print(f"OK: {out}")

if __name__ == "__main__":
    main()
