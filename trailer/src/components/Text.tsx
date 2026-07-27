import React from 'react';
import {AbsoluteFill, interpolate, useCurrentFrame, Easing} from 'remotion';
import {loadFont} from '@remotion/google-fonts/Inter';

const {fontFamily} = loadFont('normal', {weights: ['300', '400', '600', '800']});

export const INTER = fontFamily;

const softEase = Easing.bezier(0.25, 0.1, 0.25, 1);

/**
 * Apple-style caption: fades in with a blur→sharp settle, holds, then fades
 * out with a slight blur. Lines animate as one block (no typewriter).
 */
export const FadeBlurText: React.FC<{
  lines: string[];
  inAt: number;
  outAt: number;
  bottom?: string;
  size?: number;
  weight?: number;
  maxWidth?: string;
}> = ({lines, inAt, outAt, bottom = '16%', size = 58, weight = 400, maxWidth = '84%'}) => {
  const frame = useCurrentFrame();
  const FADE = 22;

  const inP = interpolate(frame, [inAt, inAt + FADE], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: softEase,
  });
  const outP = interpolate(frame, [outAt - FADE, outAt], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: softEase,
  });
  const opacity = Math.min(inP, outP);
  const blur = (1 - inP) * 10 + (1 - outP) * 6;
  const rise = (1 - inP) * 18;

  if (opacity <= 0) return null;

  return (
    <AbsoluteFill style={{pointerEvents: 'none', justifyContent: 'flex-end', alignItems: 'center'}}>
      <div
        style={{
          position: 'absolute',
          bottom,
          maxWidth,
          textAlign: 'center',
          fontFamily: INTER,
          fontWeight: weight,
          fontSize: size,
          lineHeight: 1.32,
          letterSpacing: '-0.01em',
          color: 'rgba(255,255,255,0.96)',
          textShadow: '0 2px 30px rgba(0,0,0,0.85), 0 0 60px rgba(0,0,0,0.5)',
          opacity,
          filter: `blur(${blur}px)`,
          transform: `translateY(${rise}px)`,
        }}
      >
        {lines.map((l, i) => (
          <div key={i}>{l}</div>
        ))}
      </div>
    </AbsoluteFill>
  );
};
