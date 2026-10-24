import html
import json
import os
import re

JSONL_PATH = "/Users/yasseinshehata/.gemini/antigravity/brain/04107c39-f54d-4989-bea6-a001a87af3da/.system_generated/logs/transcript_full.jsonl"
OUT_HTML = "/Users/yasseinshehata/Documents/robbylox/USER_PROMPTS_ARCHIVE.html"
OUT_MD = "/Users/yasseinshehata/Documents/robbylox/USER_PROMPTS_ARCHIVE.md"

def extract_prompts():
    prompts = []
    with open(JSONL_PATH, "r", encoding="utf-8") as f:
        for line in f:
            data = json.loads(line)
            if data.get("type") == "USER_INPUT":
                content = data.get("content", "")
                created = data.get("created_at", "")
                step = data.get("step_index", "")

                match = re.search(r"<USER_REQUEST>(.*?)</USER_REQUEST>", content, re.DOTALL)
                if match:
                    req_text = match.group(1).strip()
                else:
                    req_text = content.strip()

                images = re.findall(r"-\s*(/Users/[^\s]+\.(?:png|jpg|jpeg))", content)

                prompts.append({
                    "index": len(prompts) + 1,
                    "step": step,
                    "created_at": created,
                    "text": req_text,
                    "images": images
                })
    return prompts

def format_text_to_html(raw_text):
    escaped = html.escape(raw_text)

    def replace_code_block(m):
        code = m.group(1)
        return f'<pre class="code-block"><code>{code}</code></pre>'
    escaped = re.sub(r'```(?:\w+)?\n?(.*?)```', replace_code_block, escaped, flags=re.DOTALL)
    escaped = re.sub(r'`([^`\n]+)`', r'<code class="inline-code">\1</code>', escaped)
    escaped = re.sub(r'\*\*([^*]+)\*\*', r'<strong>\1</strong>', escaped)
    escaped = re.sub(r'^(?:###\s*)(.*?)$', r'<h4 class="prompt-h4">\1</h4>', escaped, flags=re.MULTILINE)
    escaped = re.sub(r'^(?:##\s*)(.*?)$', r'<h3 class="prompt-h3">\1</h3>', escaped, flags=re.MULTILINE)
    escaped = re.sub(r'^(?:#\s*)(.*?)$', r'<h2 class="prompt-h2">\1</h2>', escaped, flags=re.MULTILINE)

    parts = escaped.split('<pre class="code-block">')
    rebuilt = [parts[0].replace('\n', '<br>')]
    for p in parts[1:]:
        subparts = p.split('</pre>', 1)
        code_part = subparts[0]
        rest = subparts[1].replace('\n', '<br>') if len(subparts) > 1 else ""
        rebuilt.append('<pre class="code-block">' + code_part + '</pre>' + rest)
    escaped = "".join(rebuilt)
    return escaped

def build_markdown(prompts):
    lines = [
        "# Complete Archive of All User Prompts",
        f"**Project**: Vault Wars / Starweave (Roblox Developer Portfolio)",
        f"**Total Prompts Recorded**: {len(prompts)}",
        f"**Conversation ID**: `04107c39-f54d-4989-bea6-a001a87af3da`",
        "",
        "---",
        ""
    ]

    for p in prompts:
        idx = p["index"]
        ts = p["created_at"].replace("T", " ").replace("Z", " UTC")
        step = p["step"]
        img_info = ""
        if p["images"]:
            img_info = f"\n*Attached Images ({len(p['images'])}):*\n" + "\n".join(f"- `{img}`" for img in p["images"])

        lines.append(f"## Prompt #{idx} (Step {step} • {ts})")
        if img_info:
            lines.append(img_info)
        lines.append("")
        lines.append(p["text"])
        lines.append("")
        lines.append("---")
        lines.append("")

    return "\n".join(lines)

def build_html(prompts):
    prompts_json = json.dumps(prompts)
    cards_html = []
    options_html = []

    for p in prompts:
        idx = p["index"]
        ts = p["created_at"].replace("T", " ").replace("Z", " UTC")
        step = p["step"]
        raw_text = p["text"]
        formatted_html = format_text_to_html(raw_text)
        is_long = len(raw_text) > 600

        preview_title = raw_text[:40].replace("\n", " ")
        options_html.append(f'<option value="prompt-{idx}">#{idx} - {html.escape(preview_title)}...</option>')

        img_html = ""
        if p["images"]:
            img_items = "".join(f'<li><code>{html.escape(img)}</code></li>' for img in p["images"])
            img_html = f'<div class="img-box"><strong>Attached Images:</strong><ul>{img_items}</ul></div>'

        collapse_class = "collapsible collapsed" if is_long else ""
        expand_btn = f'<button class="expand-btn" onclick="toggleExpand({idx})">Show Full Prompt ({len(raw_text):,} chars) ▼</button>' if is_long else ""

        cards_html.append(f'''
        <article class="prompt-card" id="prompt-{idx}" data-index="{idx}" data-search="{html.escape(raw_text.lower())}">
            <div class="card-header">
                <div class="card-meta">
                    <span class="prompt-badge">Prompt #{idx}</span>
                    <span class="step-badge">Step {step}</span>
                    <span class="time-badge">{ts}</span>
                </div>
                <div class="card-actions">
                    <button class="action-btn copy-btn" onclick="copyPrompt({idx})" title="Copy prompt to clipboard">
                        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>
                        Copy
                    </button>
                    <a href="#prompt-{idx}" class="action-btn anchor-btn" title="Direct Link">#</a>
                </div>
            </div>
            {img_html}
            <div class="prompt-content {collapse_class}" id="content-{idx}">
                {formatted_html}
            </div>
            {expand_btn}
        </article>
        ''')

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>All User Prompts Archive (105 Prompts)</title>
    <style>
        :root {{
            --bg-primary: #0a0e17;
            --bg-secondary: #121826;
            --bg-card: #182234;
            --bg-card-hover: #1e2b42;
            --border-color: #2a3b5c;
            --accent-cyan: #38bdf8;
            --accent-amber: #f59e0b;
            --text-main: #f1f5f9;
            --text-muted: #94a3b8;
            --code-bg: #0b111e;
        }}
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            background: var(--bg-primary);
            color: var(--text-main);
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
            line-height: 1.6;
            padding-bottom: 80px;
        }}
        header.sticky-header {{
            position: sticky;
            top: 0;
            z-index: 1000;
            background: rgba(18, 24, 38, 0.95);
            backdrop-filter: blur(12px);
            border-bottom: 1px solid var(--border-color);
            padding: 16px 24px;
        }}
        .header-content {{
            max-width: 1000px;
            margin: 0 auto;
            display: flex;
            flex-direction: column;
            gap: 12px;
        }}
        .title-row {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            flex-wrap: wrap;
            gap: 10px;
        }}
        .title-row h1 {{
            font-size: 20px;
            font-weight: 700;
            color: #fff;
            display: flex;
            align-items: center;
            gap: 8px;
        }}
        .title-row h1 span {{ color: var(--accent-cyan); }}
        .stats-badge {{
            background: rgba(56, 189, 248, 0.15);
            color: var(--accent-cyan);
            border: 1px solid rgba(56, 189, 248, 0.3);
            border-radius: 999px;
            padding: 4px 12px;
            font-size: 13px;
            font-weight: 600;
        }}
        .controls-row {{
            display: flex;
            gap: 12px;
            flex-wrap: wrap;
        }}
        .search-box {{
            flex: 1;
            min-width: 260px;
            position: relative;
        }}
        .search-input {{
            width: 100%;
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            color: #fff;
            padding: 10px 14px 10px 38px;
            border-radius: 8px;
            font-size: 14px;
            outline: none;
            transition: all 0.2s ease;
        }}
        .search-input:focus {{
            border-color: var(--accent-cyan);
            box-shadow: 0 0 0 2px rgba(56, 189, 248, 0.2);
        }}
        .search-icon {{
            position: absolute;
            left: 12px;
            top: 50%;
            transform: translateY(-50%);
            color: var(--text-muted);
            pointer-events: none;
        }}
        .jump-select {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            color: #fff;
            padding: 10px 14px;
            border-radius: 8px;
            font-size: 14px;
            outline: none;
            max-width: 280px;
        }}
        main.container {{
            max-width: 1000px;
            margin: 24px auto;
            padding: 0 16px;
            display: flex;
            flex-direction: column;
            gap: 20px;
        }}
        .results-info {{
            font-size: 14px;
            color: var(--text-muted);
            margin-bottom: -6px;
        }}
        .prompt-card {{
            background: var(--bg-card);
            border: 1px solid var(--border-color);
            border-radius: 12px;
            padding: 20px;
            transition: transform 0.15s ease, border-color 0.2s ease;
            scroll-margin-top: 140px;
        }}
        .prompt-card:hover {{ border-color: #3b5278; }}
        .card-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 14px;
            flex-wrap: wrap;
            gap: 10px;
            border-bottom: 1px solid rgba(255, 255, 255, 0.06);
            padding-bottom: 12px;
        }}
        .card-meta {{
            display: flex;
            align-items: center;
            gap: 8px;
            flex-wrap: wrap;
        }}
        .prompt-badge {{
            background: var(--accent-cyan);
            color: #04101e;
            font-weight: 700;
            font-size: 13px;
            padding: 3px 10px;
            border-radius: 6px;
        }}
        .step-badge {{
            background: rgba(255, 255, 255, 0.08);
            color: #cbd5e1;
            font-size: 12px;
            padding: 3px 8px;
            border-radius: 6px;
        }}
        .time-badge {{ color: var(--text-muted); font-size: 12px; }}
        .card-actions {{ display: flex; align-items: center; gap: 8px; }}
        .action-btn {{
            background: rgba(255, 255, 255, 0.06);
            border: 1px solid rgba(255, 255, 255, 0.1);
            color: #cbd5e1;
            padding: 5px 10px;
            border-radius: 6px;
            font-size: 12px;
            cursor: pointer;
            display: inline-flex;
            align-items: center;
            gap: 5px;
            text-decoration: none;
            transition: all 0.15s ease;
        }}
        .action-btn:hover {{
            background: rgba(56, 189, 248, 0.15);
            color: var(--accent-cyan);
            border-color: var(--accent-cyan);
        }}
        .prompt-content {{
            font-size: 15px;
            color: #e2e8f0;
            white-space: pre-wrap;
            word-break: break-word;
            line-height: 1.65;
        }}
        .prompt-content.collapsible.collapsed {{
            max-height: 220px;
            overflow: hidden;
            position: relative;
        }}
        .prompt-content.collapsible.collapsed::after {{
            content: "";
            position: absolute;
            bottom: 0; left: 0; right: 0; height: 80px;
            background: linear-gradient(to bottom, transparent, var(--bg-card));
            pointer-events: none;
        }}
        .expand-btn {{
            background: rgba(56, 189, 248, 0.1);
            color: var(--accent-cyan);
            border: 1px dashed rgba(56, 189, 248, 0.3);
            width: 100%;
            padding: 8px;
            margin-top: 10px;
            border-radius: 6px;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s ease;
        }}
        .expand-btn:hover {{
            background: rgba(56, 189, 248, 0.2);
            border-color: var(--accent-cyan);
        }}
        .code-block {{
            background: var(--code-bg);
            border: 1px solid var(--border-color);
            padding: 12px 14px;
            border-radius: 8px;
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-size: 13px;
            overflow-x: auto;
            margin: 10px 0;
            color: #38bdf8;
        }}
        .inline-code {{
            background: rgba(255, 255, 255, 0.1);
            padding: 2px 6px;
            border-radius: 4px;
            font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
            font-size: 13px;
            color: #fca5a5;
        }}
        .prompt-h2 {{ font-size: 18px; margin: 12px 0 6px; color: #38bdf8; }}
        .prompt-h3 {{ font-size: 16px; margin: 10px 0 4px; color: #f59e0b; }}
        .prompt-h4 {{ font-size: 14px; margin: 8px 0 4px; color: #cbd5e1; }}
        .img-box {{
            background: rgba(245, 158, 11, 0.08);
            border: 1px solid rgba(245, 158, 11, 0.25);
            padding: 10px 14px;
            border-radius: 8px;
            margin-bottom: 12px;
            font-size: 13px;
        }}
        .img-box strong {{ color: var(--accent-amber); }}
        .img-box ul {{ margin-left: 20px; margin-top: 4px; }}
        .toast {{
            position: fixed;
            bottom: 24px; right: 24px;
            background: #10b981;
            color: #fff;
            padding: 10px 18px;
            border-radius: 8px;
            font-size: 14px;
            font-weight: 600;
            box-shadow: 0 4px 12px rgba(0,0,0,0.4);
            transform: translateY(100px);
            opacity: 0;
            transition: all 0.25s ease;
            z-index: 2000;
        }}
        .toast.show {{ transform: translateY(0); opacity: 1; }}
    </style>
</head>
<body>
    <header class="sticky-header">
        <div class="header-content">
            <div class="title-row">
                <h1>Vault Wars / Starweave <span>• User Prompts Archive</span></h1>
                <div class="stats-badge" id="prompt-counter">Total: {len(prompts)} Prompts</div>
            </div>
            <div class="controls-row">
                <div class="search-box">
                    <span class="search-icon">🔍</span>
                    <input type="text" id="searchInput" class="search-input" placeholder="Search prompts (e.g. nilo, glb, camera, masterplan, mint)..." oninput="filterPrompts()">
                </div>
                <select id="jumpSelect" class="jump-select" onchange="jumpToPrompt(this.value)">
                    <option value="">Jump to prompt...</option>
                    {"".join(options_html)}
                </select>
            </div>
        </div>
    </header>

    <main class="container">
        <div class="results-info" id="resultsInfo">Displaying all {len(prompts)} prompts</div>
        {"".join(cards_html)}
    </main>

    <div id="toast" class="toast">Copied to clipboard!</div>

    <script>
        const promptsData = {prompts_json};

        function filterPrompts() {{
            const query = document.getElementById('searchInput').value.toLowerCase().trim();
            const cards = document.querySelectorAll('.prompt-card');
            let visibleCount = 0;

            cards.forEach(card => {{
                const text = card.getAttribute('data-search');
                if (!query || text.includes(query)) {{
                    card.style.display = 'block';
                    visibleCount++;
                }} else {{
                    card.style.display = 'none';
                }}
            }});

            const info = document.getElementById('resultsInfo');
            if (query) {{
                info.innerText = `Found ${{visibleCount}} matching prompt${{visibleCount === 1 ? '' : 's'}} for "${{query}}"`;
            }} else {{
                info.innerText = `Displaying all ${{cards.length}} prompts`;
            }}
        }}

        function jumpToPrompt(id) {{
            if (!id) return;
            const el = document.getElementById(id);
            if (el) {{
                el.style.display = 'block';
                el.scrollIntoView({{ behavior: 'smooth' }});
                el.style.borderColor = 'var(--accent-cyan)';
                setTimeout(() => {{
                    el.style.borderColor = '';
                }}, 1500);
            }}
        }}

        function toggleExpand(idx) {{
            const content = document.getElementById('content-' + idx);
            const btn = content.nextElementSibling;
            if (content.classList.contains('collapsed')) {{
                content.classList.remove('collapsed');
                btn.innerText = 'Collapse Prompt ▲';
            }} else {{
                content.classList.add('collapsed');
                btn.innerText = 'Show Full Prompt ▼';
            }}
        }}

        function copyPrompt(idx) {{
            const prompt = promptsData.find(p => p.index === idx);
            if (!prompt) return;
            navigator.clipboard.writeText(prompt.text).then(() => {{
                showToast(`Prompt #${{idx}} copied to clipboard!`);
            }}).catch(() => {{
                const ta = document.createElement('textarea');
                ta.value = prompt.text;
                document.body.appendChild(ta);
                ta.select();
                document.execCommand('copy');
                document.body.removeChild(ta);
                showToast(`Prompt #${{idx}} copied!`);
            }});
        }}

        function showToast(msg) {{
            const toast = document.getElementById('toast');
            toast.innerText = msg;
            toast.classList.add('show');
            setTimeout(() => {{
                toast.classList.remove('show');
            }}, 2000);
        }}
    </script>
</body>
</html>
'''

def main():
    print("Extracting prompts from transcript...")
    prompts = extract_prompts()
    print(f"Extracted {len(prompts)} prompts.")

    print(f"Generating {OUT_HTML}...")
    html_data = build_html(prompts)
    with open(OUT_HTML, "w", encoding="utf-8") as f:
        f.write(html_data)

    print(f"Generating {OUT_MD}...")
    md_data = build_markdown(prompts)
    with open(OUT_MD, "w", encoding="utf-8") as f:
        f.write(md_data)

    print("SUCCESS: Both HTML and Markdown archives generated!")

if __name__ == "__main__":
    main()
