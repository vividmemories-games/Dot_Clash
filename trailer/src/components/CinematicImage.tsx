import {AbsoluteFill, Img, interpolate, staticFile, useCurrentFrame, Easing} from 'remotion';

const filmEase = Easing.bezier(0.32, 0, 0.18, 1);

export type CameraMove = {
  /** Scale at scene start / end (1 = fit). */
  scaleFrom: number;
  scaleTo: number;
  /** Translation in px at start / end (positive x moves image right). */
  xFrom?: number;
  xTo?: number;
  yFrom?: number;
  yTo?: number;
  /** CSS transform-origin, e.g. '60% 45%' to push toward a subject. */
  origin?: string;
};

/**
 * Full-frame image with a slow cinematic camera move, lens breathing and a
 * defocus ramp-in. All motion uses film easing — no linear pans.
 */
export const CinematicImage: React.FC<{
  src: string;
  durationInFrames: number;
  move: CameraMove;
  /** Frames of blur→sharp ramp at the start (depth-of-field settle). */
  focusRamp?: number;
  /** Extra brightness multiplier ramp, e.g. glow-up scenes. */
  brightnessTo?: number;
  rotateDeg?: [number, number];
}> = ({src, durationInFrames, move, focusRamp = 18, brightnessTo = 1, rotateDeg}) => {
  const frame = useCurrentFrame();
  const t = interpolate(frame, [0, durationInFrames], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: filmEase,
  });

  const scale = move.scaleFrom + (move.scaleTo - move.scaleFrom) * t;
  const x = (move.xFrom ?? 0) + ((move.xTo ?? 0) - (move.xFrom ?? 0)) * t;
  const y = (move.yFrom ?? 0) + ((move.yTo ?? 0) - (move.yFrom ?? 0)) * t;

  // Lens breathing: barely-visible sinusoidal scale drift.
  const breathe = 1 + Math.sin(frame / 47) * 0.0035;

  const blur = interpolate(frame, [0, focusRamp], [7, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.quad),
  });

  const brightness = 1 + (brightnessTo - 1) * t;
  const rot = rotateDeg
    ? interpolate(frame, [0, durationInFrames], rotateDeg, {
        extrapolateRight: 'clamp',
        easing: filmEase,
      })
    : 0;

  return (
    <AbsoluteFill style={{overflow: 'hidden', backgroundColor: '#000'}}>
      <Img
        src={staticFile(src)}
        style={{
          width: '100%',
          height: '100%',
          objectFit: 'cover',
          transform: `translate(${x}px, ${y}px) scale(${scale * breathe}) rotate(${rot}deg)`,
          transformOrigin: move.origin ?? '50% 50%',
          filter: `blur(${blur}px) brightness(${brightness})`,
        }}
      />
    </AbsoluteFill>
  );
};
