#!/usr/bin/env python3
import asyncio
import base64
import datetime
import glob
import http.client
import json
import logging
import os
import shutil
import sys
import urllib.request
import uuid

try:
    import discord
except ImportError:
    sys.exit("Run:  python -m pip install discord.py")

MANGA_CHANNEL_ID = 1490123914997666075
MEDIA_DIR        = r"C:\Users\amd\Downloads\LemonadeDemo\images_logs"
LOG_PATH         = r"C:\Users\amd\Downloads\LemonadeDemo\logs\manga_pipeline.log"
STORY_LOG_PATH   = r"C:\Users\amd\Downloads\LemonadeDemo\logs\manga_story.json"
SENTINEL_PATH    = os.path.join(MEDIA_DIR, "manga_latest.png")
LEMONADE_BASE    = "http://localhost:13305/api/v1"
FLUX_MODEL       = "Flux-2-Klein-9B-GGUF"
LLM_MODEL        = "Qwen3-8B-Hybrid"
MANGA_PREFIX     = "manga panel, black and white ink, screentone shading, bold outlines"
DISCORD_TOKEN    = os.environ.get("DISCORD_BOT_TOKEN", "")
STORY_MAX        = 10

os.makedirs(os.path.dirname(LOG_PATH), exist_ok=True)
os.makedirs(MEDIA_DIR, exist_ok=True)
logging.basicConfig(
    filename=LOG_PATH,
    level=logging.INFO,
    format="%(asctime)s %(message)s",
)
log = logging.getLogger(__name__)
log.addHandler(logging.StreamHandler(sys.stdout))

def load_prompts() -> list[str]:
    if not os.path.exists(STORY_LOG_PATH):
        return []
    try:
        with open(STORY_LOG_PATH, encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return []

def save_prompts(prompts: list[str]) -> None:
    with open(STORY_LOG_PATH, "w", encoding="utf-8") as f:
        json.dump(prompts[-STORY_MAX:], f, indent=2)

def save_image(b64_data: str) -> str:
    ts = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    out_path = os.path.join(MEDIA_DIR, f"image-1---manga-{ts}.png")
    with open(out_path, "wb") as f:
        f.write(base64.b64decode(b64_data))
    shutil.copy2(out_path, SENTINEL_PATH)
    return out_path

def flux_generate(prompt: str) -> str:
    log.info("flux → GENERATE")
    payload = json.dumps({
        "model": FLUX_MODEL,
        "prompt": prompt,
        "n": 1,
        "size": "512x512",
        "width": 512,
        "height": 512,
        "steps": 6,
        "cfg_scale": 3.5,
    }).encode()
    req = urllib.request.Request(
        f"{LEMONADE_BASE}/images/generations",
        data=payload,
        headers={"Content-Type": "application/json", "Authorization": "Bearer lemonade"},
    )
    with urllib.request.urlopen(req, timeout=300) as resp:
        data = json.loads(resp.read())
    log.info("flux → GENERATE complete")
    return data["data"][0]["b64_json"]


def flux_edit(prompt: str, image_path: str) -> str:
    log.info("flux → EDIT")
    boundary = uuid.uuid4().hex
    with open(image_path, "rb") as f:
        image_data = f.read()

    def field(name: str, value: str) -> bytes:
        return (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="{name}"\r\n\r\n'
            f"{value}\r\n"
        ).encode()

    body = b"".join([
        field("model", FLUX_MODEL),
        field("prompt", prompt),
        field("n", "1"),
        field("size", "512x512"),
        field("steps", "6"),
        field("cfg_scale", "3.5"),
        (
            f"--{boundary}\r\n"
            f'Content-Disposition: form-data; name="image"; filename="image.png"\r\n'
            f"Content-Type: image/png\r\n\r\n"
        ).encode() + image_data + b"\r\n",
        f"--{boundary}--\r\n".encode(),
    ])

    conn = http.client.HTTPConnection("localhost", 13305, timeout=300)
    conn.request(
        "POST", "/api/v1/images/edits",
        body=body,
        headers={
            "Content-Type": f"multipart/form-data; boundary={boundary}",
            "Authorization": "Bearer lemonade",
        },
    )
    resp = conn.getresponse()
    data = json.loads(resp.read())
    conn.close()
    log.info("flux → EDIT complete")
    return data["data"][0]["b64_json"]


_SYSTEM_PROMPT = """\
You are MangaBot, a Flux image prompt writer for an ongoing manga story.

You will receive the scene prompts used so far, in order. Your job is to suggest \
the next Flux image generation prompt that advances the story.

Write 3 to 5 sentences of flowing novelist prose — never keyword lists. \
Cover all five elements in order:
1. Subject: front-loaded and specific — who/what and what they are doing (must be a new action)
2. Setting: where the scene takes place with physical detail
3. Details: clothing, objects, expression, body language
4. Lighting: at least one full sentence — source, quality, direction, temperature, \
how it interacts with surfaces (this is the most important element)
5. End with exactly:  Style: [descriptor]. Mood: [descriptor].

Rules:
- Keep the scenes joyful without negative or harmful prompts
- Write flowing prose, never comma-separated tags
- The scene MUST advance the story — something changes, happens, or is revealed
- Do NOT restate the previous scene with minor variations
- Output only the prompt. No preamble, no explanation.\
"""

def llm_next_prompt(prompts: list[str]) -> str:
    log.info("llm → NEXT PROMPT")
    numbered = "\n".join(f"{i+1}. {p}" for i, p in enumerate(prompts))
    user_content = f"Scene prompts so far:\n{numbered}\n\nSuggest the next scene prompt."

    payload = json.dumps({
        "model": LLM_MODEL,
        "messages": [
            {"role": "system", "content": _SYSTEM_PROMPT},
            {"role": "user",   "content": user_content},
        ],
        "max_tokens": 300,
    }).encode()
    req = urllib.request.Request(
        f"{LEMONADE_BASE}/chat/completions",
        data=payload,
        headers={"Content-Type": "application/json", "Authorization": "Bearer lemonade"},
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.loads(resp.read())
    suggestion = data["choices"][0]["message"]["content"].strip()
    log.info(f"llm → NEXT PROMPT: {suggestion!r}")
    return suggestion

intents = discord.Intents.default()
intents.message_content = True
client = discord.Client(intents=intents)

SEEN_IDS_PATH = os.path.join(os.path.dirname(LOG_PATH), "manga_seen_ids.json")
_MAX_SEEN = 500


def _load_seen() -> set[int]:
    try:
        with open(SEEN_IDS_PATH, encoding="utf-8") as f:
            return set(json.load(f))
    except Exception:
        return set()


def _save_seen(ids: set[int]) -> None:
    trimmed = sorted(ids)[-_MAX_SEEN:]
    with open(SEEN_IDS_PATH, "w", encoding="utf-8") as f:
        json.dump(trimmed, f)


_processed_ids: set[int] = _load_seen()


@client.event
async def on_ready():
    log.info(f"manga bot online as {client.user}")


@client.event
async def on_message(message: discord.Message):
    if message.author.bot:
        return
    if message.channel.id != MANGA_CHANNEL_ID:
        return
    if message.id in _processed_ids:
        log.info(f"skipping already-processed message {message.id}")
        return
    _processed_ids.add(message.id)
    _save_seen(_processed_ids)

    user_text = message.content.strip()
    if not user_text:
        return

    log.info(f'message: "{user_text}"')
    prompt = f"{MANGA_PREFIX}, {user_text}"

    async with message.channel.typing():
        try:
            # Generate or edit
            if os.path.exists(SENTINEL_PATH):
                b64 = await asyncio.to_thread(flux_edit, prompt, SENTINEL_PATH)
            else:
                b64 = await asyncio.to_thread(flux_generate, prompt)

            out_path = save_image(b64)
            await message.channel.send(file=discord.File(out_path, filename="manga.png"))

            # Save prompt to story log
            prompts = load_prompts()
            prompts.append(user_text)
            save_prompts(prompts)

            # Suggest next prompt based on full history
            suggestion = await asyncio.to_thread(llm_next_prompt, prompts)
            await message.channel.send(f"**Suggested next prompt:** {suggestion}")

        except Exception as e:
            log.error(f"pipeline failed: {e}")
            await message.channel.send(f"Generation failed: {e}")


if __name__ == "__main__":
    if not DISCORD_TOKEN:
        sys.exit("DISCORD_BOT_TOKEN not found — check C:\\Users\\amd\\.openclaw\\.env")
    client.run(DISCORD_TOKEN)
