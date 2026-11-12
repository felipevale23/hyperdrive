"""Runs on the Colab VM. Text to video WITH synced audio, LTX-2.5 distilled (Lightricks/LTX-2.5-Diffusers).

Environment: PROMPT (required; long single-paragraph prompts that also describe the sound work best),
OUT, VERTICAL=1 for 9:16, SECONDS, SEED.
Needs diffusers from git main and about 40+ GB of GPU memory: run it on an H100 or A100 80 GB.
License: LTX-2 Community License, free commercial use below about $10M yearly revenue.
"""
import os, time, torch
os.environ.setdefault("PYTORCH_CUDA_ALLOC_CONF", "expandable_segments:True")
from diffusers import LTX2Pipeline
from diffusers.utils import encode_video
from diffusers.pipelines.ltx2.utils import DISTILLED_SIGMA_VALUES, DEFAULT_NEGATIVE_PROMPT

prompt = os.environ["PROMPT"]
out = os.environ.get("OUT", "/content/out.mp4")
vertical = os.environ.get("VERTICAL") == "1"
width, height = (704, 1280) if vertical else (1280, 704)  # multiples of 64
fps = 24.0
seconds = float(os.environ.get("SECONDS", "5"))
frames = round(seconds * fps / 8) * 8 + 1  # 8k+1 frames: 5 s -> 121
seed = int(os.environ.get("SEED", str(int(time.time()) % 2**32)))

t = time.time()
pipe = LTX2Pipeline.from_pretrained("Lightricks/LTX-2.5-Diffusers", dtype=torch.bfloat16)
pipe.enable_model_cpu_offload()
pipe.vae.enable_tiling()
print(f"loaded in {time.time()-t:.0f}s; {width}x{height}, {frames} frames, seed {seed}", flush=True)

t = time.time()
video, audio = pipe(
    prompt=prompt, negative_prompt=DEFAULT_NEGATIVE_PROMPT,
    width=width, height=height, num_frames=frames, frame_rate=fps,
    sigmas=DISTILLED_SIGMA_VALUES, guidance_scale=1.0, audio_guidance_scale=1.0,
    stg_scale=0.0, audio_stg_scale=0.0, modality_scale=1.0, audio_modality_scale=1.0,
    generator=torch.Generator("cuda").manual_seed(seed), output_type="np", return_dict=False)
encode_video(video[0], fps=fps, audio=audio[0].float().cpu(),
             audio_sample_rate=pipe.vocoder.config.output_sampling_rate, output_path=out)
print(f"done in {time.time()-t:.0f}s -> {out}", flush=True)
