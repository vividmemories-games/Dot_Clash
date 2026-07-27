import React, {useMemo} from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame, Easing} from 'remotion';
import {seeded} from './random';

const W = 1080;
const H = 1920;

type Palette = 'warm' | 'neon';

const pickColor = (palette: Palette, r: number): string => {
  if (palette === 'warm') {
    return r < 0.5 ? 'rgba(255,214,150,0.9)' : 'rgba(255,240,214,0.85)';
  }
  return r < 0.5 ? 'rgba(53,214,255,0.9)' : 'rgba(255,79,216,0.9)';
};

/**
 * Slow floating dust / ember field. Drifts upward with sinusoidal sway and a
 * gentle twinkle. Moves slightly faster than the backplate for parallax.
 */
export const DustParticles: React.FC<{
  count?: number;
  palette?: Palette;
  seed?: number;
  opacity?: number;
}> = ({count = 26, palette = 'warm', seed = 1, opacity = 1}) => {
  const frame = useCurrentFrame();
  const particles = useMemo(() => {
    const rnd = seeded(seed * 7919);
    return Array.from({length: count}, () => ({
      x: rnd() * W,
      y: rnd() * H,
      size: 2 + rnd() * 5,
      speed: 0.14 + rnd() * 0.4,
      swayPhase: rnd() * Math.PI * 2,
      swayAmp: 8 + rnd() * 26,
      twinklePhase: rnd() * Math.PI * 2,
      color: pickColor(palette, rnd()),
      blur: rnd() < 0.4 ? 2 : 0,
    }));
  }, [count, palette, seed]);

  return (
    <AbsoluteFill style={{pointerEvents: 'none', opacity}}>
      {particles.map((p, i) => {
        const y = ((p.y - frame * p.speed) % (H + 40) + H + 40) % (H + 40) - 20;
        const x = p.x + Math.sin(frame / 90 + p.swayPhase) * p.swayAmp;
        const tw = 0.35 + 0.65 * (0.5 + 0.5 * Math.sin(frame / 38 + p.twinklePhase));
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x,
              top: y,
              width: p.size,
              height: p.size,
              borderRadius: '50%',
              background: p.color,
              opacity: tw,
              filter: p.blur ? `blur(${p.blur}px)` : undefined,
              boxShadow: `0 0 ${p.size * 3}px ${p.color}`,
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
};

/**
 * Radial neon burst — used for the high-five impact. Particles accelerate out
 * from an origin then decelerate and fade (film easing, no bounce).
 */
export const NeonBurst: React.FC<{
  impactFrame: number;
  originX?: number;
  originY?: number;
  count?: number;
  seed?: number;
}> = ({impactFrame, originX = W * 0.52, originY = H * 0.33, count = 42, seed = 5}) => {
  const frame = useCurrentFrame();
  const particles = useMemo(() => {
    const rnd = seeded(seed * 104729);
    return Array.from({length: count}, () => {
      const angle = rnd() * Math.PI * 2;
      return {
        angle,
        dist: 180 + rnd() * 620,
        size: 3 + rnd() * 7,
        color: rnd() < 0.5 ? '#35d6ff' : '#ff4fd8',
        drag: 0.85 + rnd() * 0.3,
      };
    });
  }, [count, seed]);

  const life = 60;
  const t = frame - impactFrame;
  if (t < 0 || t > life) return null;

  const progress = interpolate(t, [0, life], [0, 1], {easing: Easing.out(Easing.cubic)});
  const fade = interpolate(t, [0, life * 0.55, life], [1, 0.9, 0]);

  return (
    <AbsoluteFill style={{pointerEvents: 'none', mixBlendMode: 'screen'}}>
      {particles.map((p, i) => {
        const d = p.dist * progress * p.drag;
        const x = originX + Math.cos(p.angle) * d;
        const y = originY + Math.sin(p.angle) * d * 0.85;
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x,
              top: y,
              width: p.size,
              height: p.size,
              borderRadius: '50%',
              background: p.color,
              opacity: fade,
              boxShadow: `0 0 ${p.size * 4}px ${p.color}`,
            }}
          />
        );
      })}
    </AbsoluteFill>
  );
};
