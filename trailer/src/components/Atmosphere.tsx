import {AbsoluteFill, useCurrentFrame} from 'remotion';

/** Soft cinematic vignette — slightly stronger at the bottom for text legibility. */
export const Vignette: React.FC<{strength?: number}> = ({strength = 0.55}) => (
  <AbsoluteFill
    style={{
      background: `radial-gradient(ellipse 90% 75% at 50% 44%, transparent 55%, rgba(0,0,0,${strength}) 100%)`,
      pointerEvents: 'none',
    }}
  />
);

/** Animated film grain via SVG turbulence; new seed every second frame. */
export const FilmGrain: React.FC<{opacity?: number}> = ({opacity = 0.05}) => {
  const frame = useCurrentFrame();
  const seed = Math.floor(frame / 2);
  return (
    <AbsoluteFill style={{pointerEvents: 'none', opacity, mixBlendMode: 'overlay'}}>
      <svg width="100%" height="100%">
        <filter id={`grain-${seed}`}>
          <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed={seed} stitchTiles="stitch" />
          <feColorMatrix type="saturate" values="0" />
        </filter>
        <rect width="100%" height="100%" filter={`url(#grain-${seed})`} />
      </svg>
    </AbsoluteFill>
  );
};

/** Warm or neon light bloom, screen-blended, gently pulsing. */
export const LightBloom: React.FC<{
  x: string;
  y: string;
  color: string;
  size?: number;
  baseOpacity?: number;
  pulsePeriod?: number;
}> = ({x, y, color, size = 900, baseOpacity = 0.35, pulsePeriod = 90}) => {
  const frame = useCurrentFrame();
  const pulse = baseOpacity * (0.85 + 0.15 * Math.sin((frame / pulsePeriod) * Math.PI * 2));
  return (
    <AbsoluteFill style={{pointerEvents: 'none', mixBlendMode: 'screen'}}>
      <div
        style={{
          position: 'absolute',
          left: x,
          top: y,
          width: size,
          height: size,
          transform: 'translate(-50%, -50%)',
          background: `radial-gradient(circle, ${color} 0%, transparent 65%)`,
          opacity: pulse,
        }}
      />
    </AbsoluteFill>
  );
};
