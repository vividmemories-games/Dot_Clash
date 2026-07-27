import React, {useMemo} from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame, Easing} from 'remotion';
import {seeded} from './random';

const W = 1080;
const H = 1920;

/**
 * Scene fade envelope. Every scene eases in from black-ish and out again so
 * cuts never pop; overlay transitions ride on top of the boundary.
 */
export const SceneFade: React.FC<{
  durationInFrames: number;
  fadeIn?: number;
  fadeOut?: number;
  children: React.ReactNode;
}> = ({durationInFrames, fadeIn = 14, fadeOut = 14, children}) => {
  const frame = useCurrentFrame();
  const opacity = Math.min(
    interpolate(frame, [0, fadeIn], [0, 1], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}),
    interpolate(frame, [durationInFrames - fadeOut, durationInFrames], [1, 0], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    })
  );
  return <AbsoluteFill style={{opacity}}>{children}</AbsoluteFill>;
};

/** Soft white/neon bloom flash — peak at `peakFrame` (used at the high-five). */
export const BloomFlash: React.FC<{peakFrame: number; color?: string; maxOpacity?: number}> = ({
  peakFrame,
  color = 'rgba(255,255,255,1)',
  maxOpacity = 0.85,
}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(
    frame,
    [peakFrame - 6, peakFrame, peakFrame + 22],
    [0, maxOpacity, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp', easing: Easing.out(Easing.quad)}
  );
  if (opacity <= 0) return null;
  return (
    <AbsoluteFill
      style={{
        pointerEvents: 'none',
        mixBlendMode: 'screen',
        background: `radial-gradient(circle at 50% 38%, ${color} 0%, transparent 75%)`,
        opacity,
      }}
    />
  );
};

/**
 * Neon particle sweep that rides scene boundaries: a band of blue/pink
 * particles crosses the frame bottom→top while the scenes crossfade under it,
 * reading as "the memory turns into the game".
 */
export const ParticleSweep: React.FC<{
  startFrame: number;
  duration?: number;
  seed?: number;
  count?: number;
}> = ({startFrame, duration = 50, seed = 11, count = 70}) => {
  const frame = useCurrentFrame();
  const particles = useMemo(() => {
    const rnd = seeded(seed * 15485863);
    return Array.from({length: count}, () => ({
      x: rnd() * W,
      lag: rnd() * 0.35,
      size: 2.5 + rnd() * 6,
      color: rnd() < 0.5 ? '#35d6ff' : '#ff4fd8',
      sway: (rnd() - 0.5) * 90,
    }));
  }, [count, seed]);

  const t = frame - startFrame;
  if (t < 0 || t > duration) return null;

  return (
    <AbsoluteFill style={{pointerEvents: 'none', mixBlendMode: 'screen'}}>
      {particles.map((p, i) => {
        const progress = interpolate(t, [duration * p.lag, duration], [0, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
          easing: Easing.inOut(Easing.cubic),
        });
        const y = H + 60 - progress * (H + 160);
        const x = p.x + Math.sin(progress * Math.PI * 2) * p.sway;
        const fade = Math.sin(progress * Math.PI);
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
