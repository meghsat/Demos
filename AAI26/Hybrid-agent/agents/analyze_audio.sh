#!/usr/bin/env python3
import base64, json, sys, urllib.request

audio_path = sys.argv[1]
prompt = sys.argv[2] if len(sys.argv) > 2 else "Summarize this audio."

data = base64.b64encode(open(audio_path, "rb").read()).decode()
payload = json.dumps({
    "model": "gemma4-e4b-qat-gguf-NoThinking",
    "messages": [{"role": "user", "content": [
        {"type": "input_audio", "input_audio": {"data": data, "format": "mp3"}},
        {"type": "text", "text": prompt}
    ]}]
}).encode()

req = urllib.request.Request(
    "http://localhost:13305/v1/chat/completions",
    data=payload,
    headers={"Content-Type": "application/json"}
)
print(json.loads(urllib.request.urlopen(req).read())["choices"][0]["message"]["content"])
