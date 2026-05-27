# quest_run GIF source

Generates [`../quest_run.gif`](../quest_run.gif) (2400×1350, retina) and
[`../quest_run_1200.gif`](../quest_run_1200.gif) (1200×675) — an animated
walkthrough of one real Mind2Web 2 research run by QUEST-35B-RL
(task_idx_95, RAG repo discovery).

## Files

- **scene.html** — single static page with all 5 scenes baked in and a
  `window.__renderAt(ms)` function that snaps the DOM to any time offset.
- **capture.js** — Puppeteer driver: opens scene.html with `?capture=1`,
  walks `t = 0 .. __TOTAL` at 18 fps, screenshots each frame to
  `/tmp/gif_build/frames/`.
- **build.sh** — wrapper: installs `puppeteer-core` if `/tmp` was wiped,
  loads the ffmpeg module, captures frames, encodes both GIFs via the
  two-pass palette method (`palettegen` → `paletteuse` with Floyd-Steinberg
  dithering), copies output back up to the project root.

## Rebuild

    cd gif_src
    ./build.sh           # full rebuild (~90s on a login node)
    ./build.sh encode    # skip puppeteer, just re-encode existing frames

## What to edit in scene.html

| To change | Edit |
|---|---|
| Total length / per-phase pacing | `const P = [...]` near line 280 |
| First-think / tool-call text in phase 1 | `tt1Steps` array |
| Tool calls in phase 3 | `tt2Steps` array |
| How long each step lingers | `tt1Weights` (non-linear pacing) |
| Final answer table | `<div id="ar1">` … `<div id="ar10">` |
| Condenser stat cards (8 / 21 / 11 / 1) | `cdS0` … `cdS3` |
| Trusted-fact rows | `cdF0` … `cdF3` |
| Token budget threshold | search for `80000` |
| Phase labels in the top ribbon | `<div class="label">…</div>` blocks |

## Data source

All counts come from the real trace at
`/fs/ess/PAA0201/zilu/QUEST_inference/m2w2_results/Quest-35B-RL/Quest-35B-RL_16k-output-80k-memory-400turns_no_cache/memory_logs/task_idx_95/iter1/`:

- `trajectories.jsonl` — two snapshots (round 62 pre-condenser at 80,824
  tokens / 122 msgs; round 87 final at 41,721 tokens / 51 msgs).
- `condenser_call_1_*.json` — 8 search queries, 21 visited sources,
  11 trusted facts, 1 uncertain.

The first-round THINK block is paraphrased from the real ~1180-char
reasoning in `messages[0]` of the pre-condenser snapshot.

## Dependencies

- Node 16+ (uses ESM dynamic `import()`)
- `/usr/bin/google-chrome`
- `ffmpeg/6.1.1` (`module load ffmpeg/6.1.1` on OSC)
- `puppeteer-core@21` (auto-installed to `/tmp/node_modules` by `build.sh`)
