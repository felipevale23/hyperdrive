"""Runs on the Colab VM. Adds sound to a silent video with MMAudio (video-to-audio).

Environment: IN (silent .mp4), OUT (.mp4 with sound), PROMPT (what the scene sounds like).
MMAudio weights are CC-BY-NC 4.0: non-commercial use only.
"""
import glob, os, shutil, subprocess, sys, time

src = os.environ.get("IN", "/content/out.mp4")
dst = os.environ.get("OUT", "/content/out_sound.mp4")
prompt = os.environ.get("PROMPT", "")
repo = "/content/MMAudio"

t = time.time()
if not os.path.isdir(repo):
    subprocess.run(["git", "clone", "--depth", "1", "https://github.com/hkchengrex/MMAudio.git", repo], check=True)
    subprocess.run([sys.executable, "-m", "pip", "install", "-q", "-e", repo], check=True)
duration = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", src],
                                capture_output=True, text=True, check=True).stdout)
print(f"MMAudio ready in {time.time()-t:.0f}s; adding {duration:.1f}s of sound", flush=True)

t = time.time()
subprocess.run([sys.executable, "demo.py", f"--duration={duration:.2f}", f"--video={src}", "--prompt", prompt],
               cwd=repo, check=True)
made = sorted(glob.glob(f"{repo}/output/**/*.mp4", recursive=True), key=os.path.getmtime)
if not made:
    raise SystemExit("MMAudio wrote no .mp4")
shutil.copy(made[-1], dst)
print(f"sound done in {time.time()-t:.0f}s -> {dst}", flush=True)
