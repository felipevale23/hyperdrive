"""Runs on the Colab VM. Text to video with Wan 2.2 TI2V-5B (720p, 24 fps).

Environment: PROMPT (required), OUT, VERTICAL=1 for 9:16, NEGATIVE, SECONDS, STEPS, SEED.
"""
import os, time, torch
os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")
from diffusers import AutoencoderKLWan, WanPipeline
from diffusers.utils import export_to_video

prompt = os.environ["PROMPT"]
out = os.environ.get("OUT", "/content/out.mp4")
negative = os.environ.get("NEGATIVE", "blurry, low quality, distorted, static, watermark, text, oversaturated, "
                          "deformed hands, extra fingers, jpeg artifacts")
vertical = os.environ.get("VERTICAL") == "1"
width, height = (704, 1280) if vertical else (1280, 704)  # 9:16 or 16:9 at 720p, multiples of 32
fps = 24
seconds = float(os.environ.get("SECONDS", "5"))
frames = int(seconds * fps) // 4 * 4 + 1  # Wan needs 4k+1 frames: 5 s -> 121
steps = int(os.environ.get("STEPS", "40"))
seed = int(os.environ.get("SEED", str(int(time.time()) % 2**32)))

t = time.time()
model_id = "Wan-AI/Wan2.2-TI2V-5B-Diffusers"
vae = AutoencoderKLWan.from_pretrained(model_id, subfolder="vae", torch_dtype=torch.float32)
pipe = WanPipeline.from_pretrained(model_id, vae=vae, torch_dtype=torch.bfloat16)
# Keep only the active part on the GPU: the transformer leaves before the VAE decodes all frames
pipe.enable_model_cpu_offload()
if hasattr(pipe.vae, "enable_tiling"):
    pipe.vae.enable_tiling()
print(f"loaded in {time.time()-t:.0f}s; {width}x{height}, {frames} frames, {steps} steps, seed {seed}", flush=True)

t = time.time()
video = pipe(prompt=prompt, negative_prompt=negative, height=height, width=width, num_frames=frames,
             guidance_scale=5.0, num_inference_steps=steps,
             generator=torch.Generator("cuda").manual_seed(seed)).frames[0]
export_to_video(video, out, fps=fps)
print(f"done in {time.time()-t:.0f}s -> {out}", flush=True)
