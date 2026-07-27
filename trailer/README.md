# Dot Clash — Cinematic Launch Trailer

Premium 30-second vertical launch trailer, rendered locally with [Remotion](https://remotion.dev). Silent by design (no VO / music / SFX per spec).

**Output:** `output/dot_clash_launch_trailer.mp4` — 1080×1920, 60 fps, H.264 (CRF 16), 30 s.

## Commands

```bash
npm install

# Live preview / scrub the timeline
npm run studio

# Render the MP4
npm run render
# → output/dot_clash_launch_trailer.mp4
```

## Timeline

| Scene | Frames (60fps) | Image | Treatment |
|---|---|---|---|
| 1 Before smartphones | 0–240 | `01-before-smartphones.png` | Slow push-in, warm dust, lamp bloom |
| 2 Papa, can we play? | 240–480 | `02-papa-can-we-play.png` | Reverse dolly, warm bloom, caption |
| 3 High five | 480–660 | `07-share-the-memory.png` | Push-in, freeze at impact, bloom flash, neon burst, decaying shake |
| 4 Idea | 660–900 | `03-simple-moment-idea.png` | Pan across notebook→neon split, neon dust |
| 5 Late nights | 900–1140 | `04-late-nights-dream.png` | Pull-back, breathing monitor glow |
| 6 Gameplay | 1140–1380 | `05-childhood-reimagined.png` | Deep zoom into phone, neon pulses, 2 electric flickers, caption |
| 7 Now live | 1380–1560 | `06-is-now-live.png` | Slow rotate ±1.2°, dual blue/pink bloom |
| 8 Final hero | 1560–1800 | typography only | DOT/CLASH neon logo, tagline, URL, fade to black |

Neon **particle sweeps** ride the 3→4, 5→6 and 7→8 boundaries. Global film grain + vignette + lens breathing on every scene.

Scenes whose poster art already contains narrative text (1, 3, 4, 5, 7) get **no additional caption** — the poster carries the line. Scenes 2, 6 and 8 have animated Apple-style captions (fade + blur, no typewriter).

## Structure

```
src/
├── index.ts                  # registerRoot
├── Root.tsx                  # composition (1800 frames @ 60fps, 1080×1920)
├── Trailer.tsx               # scene sequencing + scene-specific components
└── components/
    ├── CinematicImage.tsx    # camera moves, lens breathing, focus ramp
    ├── Atmosphere.tsx        # Vignette, FilmGrain, LightBloom
    ├── Particles.tsx         # DustParticles, NeonBurst (seeded, deterministic)
    ├── Text.tsx              # FadeBlurText (Apple-style), Inter font
    ├── Transitions.tsx       # SceneFade, BloomFlash, ParticleSweep
    └── random.ts             # mulberry32 seeded RNG
```

## Fonts

[Inter](https://fonts.google.com/specimen/Inter) via `@remotion/google-fonts` (weights 300/400/600/800). SIL Open Font License.

## Audio

None — trailer is intentionally silent. To add music later, drop a file in `public/audio/` and add `<Audio src={staticFile('audio/track.mp3')} />` inside `Trailer.tsx`.

See `ASSETS.md` for the image manifest.
