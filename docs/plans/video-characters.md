# Consistent characters for gen-video

Goal: the same character (face, body, clothes, style) across many clips for social media, from the AI tab
(`@video`) or the terminal. Three levels, each building on the one before. Nothing here is built yet.

Starting point (2026-11-11): `gen-video` makes text-to-video clips on Colab with `--model wan` (Wan 2.2
TI2V-5B, L4, silent, `--sound` adds MMAudio) or `--model ltx` (LTX-2.5 distilled with audio, H100/A100).
Scripts live in `dotfiles/.local/bin/gen-video` and `dotfiles/.local/share/gen-video/`.

## Character folder (shared by all levels)

```
~/characters/NAME/
  description.txt   one paragraph: look, age, hair, clothes, style; added to every prompt
  ref.png           main reference image (front, neutral light, plain background)
  sheet/            extra views made in level 2 (side, back, close-up, poses)
  lora/             trained LoRA files from level 3, one per model (wan.safetensors, ltx.safetensors)
  voice.txt         optional: gen-voice voice name or LTX speech description
```

New CLI: `gen-character new NAME "description"` makes `ref.png` with `gen-image` (FLUX on NVIDIA) and
writes `description.txt`; the user picks or regenerates until it looks right. `gen-character list`.

## Level 1: reference image + image-to-video (easiest)

- `gen-video --character NAME "scene"`: uploads `ref.png`, prepends `description.txt` to the prompt, and
  runs image-to-video instead of text-to-video.
  - Wan: `WanImageToVideoPipeline` with `Wan-AI/Wan2.2-TI2V-5B-Diffusers` (the same model takes an image).
  - LTX: `LTX2ImageToVideoPipeline` with `Lightricks/LTX-2.5-Diffusers`.
- The first frame is the reference, so the scene must start from it; for other settings, make a new start
  frame in level 2 first.
- `@video` learns `--character NAME` and lists `~/characters` when the user names someone.
- Test: same character, three different scene prompts, compare faces frame by frame.
- Limit: faces drift in long or busy shots; every clip starts from the same pose.

## Level 2: character sheet with an image editor (more control)

- `gen-character pose NAME "riding a bike in the rain"` makes a new still of the same character in a new
  scene/pose with an editing model, saved to `sheet/`, then `gen-video --character NAME --from sheet/X.png`.
  - Models: Qwen-Image-Edit (good identity keeping, Apache 2.0) on an A100/H100, or FLUX.1 Kontext dev
    (non-commercial license, check before Photon use).
- `gen-character sheet NAME` makes a fixed set: front, 3/4, side, back, close-up, full body.
- The sheet also becomes the training set for level 3.
- Test: 6 sheet images, identity check by eye; reject and regenerate bad ones.

## Level 3: LoRA per character (most consistent)

- `gen-character train NAME [--model wan|ltx]` on an A100/H100 Colab VM: 20-30 images from `sheet/`
  (plus real photos if the character is a real, consenting person), captions with a trigger word
  (`<NAME>`), LoRA training, download to `lora/`. Expected 1-2 h of GPU.
  - Wan 2.2: diffusion-pipe or musubi-tuner LoRA trainers; LTX: Lightricks' LTX-2 trainer.
  - Also an image LoRA (FLUX or Qwen-Image) so stills match.
- `gen-video --character NAME` then loads the LoRA (`pipe.load_lora_weights`) and uses the trigger word, so
  any scene works without a start frame; level 1 stays as a fallback.
- Cost check before the first run: read `colab usage` on the training GPU.
- Test: 5 prompts the training set never showed; the character must stay recognisable.

## Open questions

- Commercial use: Wan 2.2 and Qwen-Image-Edit are Apache 2.0; LTX-2 is free below ~$10M revenue;
  FLUX Kontext dev and MMAudio are non-commercial.
- Real people: only with their consent; never train on someone else's photos.
- Flow (Veo) has "Ingredients to video" with reference images; use it by hand for top-quality clips.

## Still unverified from the 2026-11-11 session

- `gen-video --sound` (MMAudio): the test on a T4 never produced audio (cloned, then stalled for 10+ min;
  `colab exec` also hung once with the kernel idle). Run `mmaudio_add.py` over `colab ssh` and read the
  error before relying on it.
- `gen-video --model ltx`: written from the diffusers docs, never run. Check H100 availability and its
  compute-unit rate (`colab new -s probe --gpu H100`, `colab usage`, `colab stop -s probe`); if it runs out
  of memory, switch to `enable_sequential_cpu_offload()`.
- `@video` and `@transcribe` have not been called from the AI tab yet.
