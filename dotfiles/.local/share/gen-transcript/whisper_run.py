"""Runs on the Colab VM. Speech to text with Whisper large-v3-turbo.

Environment: IN (audio file), OUT (base path, writes OUT.txt and OUT.srt), LANG (optional, e.g. pt, en; empty = detect),
MODEL (optional, default openai/whisper-large-v3-turbo).
"""
import os, time, torch
from transformers import pipeline

src = os.environ.get("IN", "/content/in.flac")
out = os.environ.get("OUT", "/content/out")
lang = os.environ.get("LANG_CODE", "").strip()
model = os.environ.get("MODEL", "openai/whisper-large-v3-turbo")

t = time.time()
asr = pipeline("automatic-speech-recognition", model=model, torch_dtype=torch.float16, device="cuda")
print(f"loaded {model} in {time.time()-t:.0f}s", flush=True)

t = time.time()
kwargs = {"task": "transcribe"}
if lang:
    kwargs["language"] = lang
result = asr(src, chunk_length_s=30, batch_size=16, return_timestamps=True, generate_kwargs=kwargs)


def stamp(s):
    s = max(0.0, s or 0.0)
    h, rem = divmod(int(s * 1000), 3600_000)
    m, rem = divmod(rem, 60_000)
    sec, ms = divmod(rem, 1000)
    return f"{h:02}:{m:02}:{sec:02},{ms:03}"


chunks = [c for c in result.get("chunks", []) if c["text"].strip()]
with open(out + ".txt", "w") as f:
    f.write(result["text"].strip() + "\n")
with open(out + ".srt", "w") as f:
    last = 0.0
    for i, c in enumerate(chunks, 1):
        start, end = c["timestamp"]
        start = last if start is None else start
        end = start + 2 if end is None else end
        last = end
        f.write(f"{i}\n{stamp(start)} --> {stamp(end)}\n{c['text'].strip()}\n\n")
print(f"done in {time.time()-t:.0f}s, {len(chunks)} segments -> {out}.txt / .srt", flush=True)
