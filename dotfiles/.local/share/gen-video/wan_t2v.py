"""Runs on the Colab VM. Reads PROMPT, OUT and optional NEGATIVE/FRAMES/SEED from the environment."""
import os, time, torch
from diffusers import AutoencoderKLWan, WanPipeline
from diffusers.utils import export_to_video

prompt = os.environ["PROMPT"]
out = os.environ.get("OUT", "/content/out.mp4")
negative = os.environ.get("NEGATIVE", "blurry, low quality, distorted, static, watermark, text, oversaturated")
frames = int(os.environ.get("FRAMES", "81"))  # 81 frames at 16 fps is about 5 s
seed = int(os.environ.get("SEED", str(int(time.time()) % 2**32)))

t = time.time()
model_id = "Wan-AI/Wan2.1-T2V-1.3B-Diffusers"
vae = AutoencoderKLWan.from_pretrained(model_id, subfolder="vae", torch_dtype=torch.float32)
pipe = WanPipeline.from_pretrained(model_id, vae=vae, torch_dtype=torch.bfloat16).to("cuda")
print(f"loaded in {time.time()-t:.0f}s", flush=True)

t = time.time()
video = pipe(prompt=prompt, negative_prompt=negative, height=480, width=832, num_frames=frames,
             guidance_scale=5.0, num_inference_steps=30,
             generator=torch.Generator("cuda").manual_seed(seed)).frames[0]
export_to_video(video, out, fps=16)
print(f"done in {time.time()-t:.0f}s, seed {seed} -> {out}", flush=True)
