import React from 'react';
import {
  AbsoluteFill,
  Sequence,
  interpolate,
  useCurrentFrame,
  Easing,
  Img,
  staticFile,
} from 'remotion';
import {CinematicImage} from './components/CinematicImage';
import {Vignette, FilmGrain, LightBloom} from './components/Atmosphere';
import {DustParticles, NeonBurst} from './components/Particles';
import {FadeBlurText, INTER} from './components/Text';
import {SceneFade, BloomFlash, ParticleSweep} from './components/Transitions';

export const FPS = 60;
export const WIDTH = 1080;
export const HEIGHT = 1920;
export const TRAILER_DURATION = 1800; // 30s

// ── Scene boundaries (frames) ────────────────────────────────────────────────
const S1 = {from: 0, dur: 240};
const S2 = {from: 240, dur: 240};
const S3 = {from: 480, dur: 180};
const S4 = {from: 660, dur: 240};
const S5 = {from: 900, dur: 240};
const S6 = {from: 1140, dur: 240};
const S7 = {from: 1380, dur: 180};
const S8 = {from: 1560, dur: 240};

// ── Scene 3: high five with freeze + impact shake ────────────────────────────
const HighFiveScene: React.FC<{dur: number}> = ({dur}) => {
  const frame = useCurrentFrame();
  const IMPACT = 58;

  // Push in, hold a beat at impact (the freeze), then drift on.
  const scale = interpolate(frame, [0, IMPACT, IMPACT + 20, dur], [1.05, 1.16, 1.16, 1.21], {
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.32, 0, 0.18, 1),
  });

  // Soft decaying shake after impact.
  const sinceImpact = Math.max(0, frame - IMPACT);
  const decay = Math.exp(-sinceImpact / 14);
  const shakeX = Math.sin(sinceImpact * 1.9) * 9 * decay;
  const shakeY = Math.cos(sinceImpact * 2.4) * 7 * decay;

  const blur = interpolate(frame, [0, 16], [7, 0], {
    extrapolateRight: 'clamp',
    easing: Easing.out(Easing.quad),
  });

  return (
    <AbsoluteFill style={{overflow: 'hidden', backgroundColor: '#000'}}>
      <Img
        src={staticFile('images/07-share-the-memory.png')}
        style={{
          width: '100%',
          height: '100%',
          objectFit: 'cover',
          transform: `translate(${shakeX}px, ${shakeY}px) scale(${scale})`,
          transformOrigin: '52% 30%',
          filter: `blur(${blur}px)`,
        }}
      />
      <BloomFlash peakFrame={IMPACT} color="rgba(255,250,235,1)" maxOpacity={0.7} />
      <NeonBurst impactFrame={IMPACT} originX={WIDTH * 0.52} originY={HEIGHT * 0.3} />
      <LightBloom x="30%" y="80%" color="rgba(255,178,102,0.5)" size={1100} baseOpacity={0.28} />
      <Vignette />
      {/* Poster carries its own narrative text — impact flash + burst only. */}
    </AbsoluteFill>
  );
};

// ── Scene 6: gameplay zoom with neon pulses ──────────────────────────────────
const GameplayScene: React.FC<{dur: number}> = ({dur}) => {
  const frame = useCurrentFrame();
  // Two restrained electric flickers, not a strobe.
  const flicker =
    interpolate(frame, [70, 74, 82], [0, 0.35, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'}) +
    interpolate(frame, [150, 154, 164], [0, 0.3, 0], {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'});

  return (
    <AbsoluteFill>
      <CinematicImage
        src="images/05-childhood-reimagined.png"
        durationInFrames={dur}
        move={{scaleFrom: 1.02, scaleTo: 1.48, origin: '58% 54%', yFrom: 0, yTo: -20}}
        brightnessTo={1.08}
      />
      <LightBloom x="62%" y="44%" color="rgba(53,214,255,0.55)" size={1000} baseOpacity={0.3} pulsePeriod={55} />
      <LightBloom x="40%" y="60%" color="rgba(255,79,216,0.5)" size={900} baseOpacity={0.26} pulsePeriod={70} />
      <AbsoluteFill
        style={{
          pointerEvents: 'none',
          mixBlendMode: 'screen',
          background: 'radial-gradient(circle at 58% 45%, rgba(160,240,255,0.9) 0%, transparent 55%)',
          opacity: flicker,
        }}
      />
      <DustParticles palette="neon" count={22} seed={6} opacity={0.8} />
      <Vignette />
      <FadeBlurText
        lines={['Challenge friends.', 'Beat the AI.', 'Every move matters.']}
        inAt={90}
        outAt={dur - 12}
        size={52}
        weight={600}
        bottom="5%"
      />
    </AbsoluteFill>
  );
};

// ── Scene 8: final hero card ─────────────────────────────────────────────────
const FinalHeroScene: React.FC<{dur: number}> = ({dur}) => {
  const frame = useCurrentFrame();
  const ease = Easing.bezier(0.25, 0.1, 0.25, 1);

  const logoIn = interpolate(frame, [10, 42], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: ease,
  });
  const tagIn = interpolate(frame, [48, 82], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: ease,
  });
  const urlIn = interpolate(frame, [88, 118], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: ease,
  });
  // Fade everything to black at the very end.
  const fadeOut = interpolate(frame, [dur - 42, dur - 6], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const logoScale = 0.96 + logoIn * 0.04;

  return (
    <AbsoluteFill
      style={{
        background: 'radial-gradient(ellipse 120% 80% at 50% 42%, #0c1226 0%, #05060f 70%)',
        justifyContent: 'center',
        alignItems: 'center',
        fontFamily: INTER,
      }}
    >
      <DustParticles palette="neon" count={30} seed={9} opacity={0.5 * fadeOut} />
      <LightBloom x="50%" y="38%" color="rgba(53,214,255,0.22)" size={1400} baseOpacity={0.5} />
      <AbsoluteFill style={{justifyContent: 'center', alignItems: 'center', opacity: fadeOut}}>
        <div
          style={{
            textAlign: 'center',
            transform: `translateY(-9%) scale(${logoScale})`,
          }}
        >
          <div
            style={{
              fontSize: 150,
              fontWeight: 800,
              letterSpacing: '0.02em',
              lineHeight: 1.04,
              opacity: logoIn,
              filter: `blur(${(1 - logoIn) * 12}px)`,
            }}
          >
            <span style={{color: '#35d6ff', textShadow: '0 0 60px rgba(53,214,255,0.75)'}}>DOT</span>
            <br />
            <span style={{color: '#ff4fd8', textShadow: '0 0 60px rgba(255,79,216,0.75)'}}>CLASH</span>
          </div>
          <div
            style={{
              marginTop: 90,
              fontSize: 52,
              fontWeight: 300,
              color: 'rgba(255,255,255,0.95)',
              lineHeight: 1.45,
              letterSpacing: '-0.01em',
              opacity: tagIn,
              filter: `blur(${(1 - tagIn) * 8}px)`,
              transform: `translateY(${(1 - tagIn) * 16}px)`,
            }}
          >
            Some games never get old.
            <br />
            They just evolve.
          </div>
          <div
            style={{
              marginTop: 110,
              fontSize: 34,
              fontWeight: 400,
              color: 'rgba(160,220,255,0.85)',
              letterSpacing: '0.01em',
              opacity: urlIn,
              filter: `blur(${(1 - urlIn) * 8}px)`,
            }}
          >
            vividmemories-games.github.io/download
          </div>
        </div>
      </AbsoluteFill>
      <Vignette strength={0.4} />
      <FilmGrain opacity={0.04} />
    </AbsoluteFill>
  );
};

// ── Main timeline ────────────────────────────────────────────────────────────
export const Trailer: React.FC = () => {
  return (
    <AbsoluteFill style={{backgroundColor: '#000'}}>
      {/* Scene 1 — Before smartphones */}
      <Sequence from={S1.from} durationInFrames={S1.dur}>
        <SceneFade durationInFrames={S1.dur}>
          <CinematicImage
            src="images/01-before-smartphones.png"
            durationInFrames={S1.dur}
            move={{scaleFrom: 1.04, scaleTo: 1.17, origin: '50% 58%', yFrom: 10, yTo: -14}}
            focusRamp={26}
          />
          <LightBloom x="78%" y="14%" color="rgba(255,190,120,0.55)" size={1000} baseOpacity={0.32} />
          <DustParticles palette="warm" count={30} seed={1} />
          <Vignette />
          {/* Poster carries the line "Before smartphones… we had imagination." */}
        </SceneFade>
      </Sequence>

      {/* Scene 2 — Papa, can we play? */}
      <Sequence from={S2.from} durationInFrames={S2.dur}>
        <SceneFade durationInFrames={S2.dur}>
          <CinematicImage
            src="images/02-papa-can-we-play.png"
            durationInFrames={S2.dur}
            move={{scaleFrom: 1.16, scaleTo: 1.05, origin: '44% 55%', xFrom: -18, xTo: 12}}
          />
          <LightBloom x="16%" y="42%" color="rgba(255,196,130,0.5)" size={950} baseOpacity={0.3} pulsePeriod={120} />
          <DustParticles palette="warm" count={22} seed={2} opacity={0.85} />
          <Vignette />
          <FadeBlurText lines={['Some memories…', 'never leave us.']} inAt={36} outAt={S2.dur - 14} />
        </SceneFade>
      </Sequence>

      {/* Scene 3 — High five */}
      <Sequence from={S3.from} durationInFrames={S3.dur}>
        <SceneFade durationInFrames={S3.dur}>
          <HighFiveScene dur={S3.dur} />
        </SceneFade>
      </Sequence>

      {/* Scene 4 — Notebook becomes neon */}
      <Sequence from={S4.from} durationInFrames={S4.dur}>
        <SceneFade durationInFrames={S4.dur}>
          <CinematicImage
            src="images/03-simple-moment-idea.png"
            durationInFrames={S4.dur}
            move={{scaleFrom: 1.05, scaleTo: 1.2, origin: '62% 45%', xFrom: 24, xTo: -30}}
            brightnessTo={1.1}
          />
          <LightBloom x="72%" y="46%" color="rgba(53,214,255,0.45)" size={1100} baseOpacity={0.3} pulsePeriod={80} />
          <LightBloom x="80%" y="65%" color="rgba(255,79,216,0.4)" size={900} baseOpacity={0.26} pulsePeriod={95} />
          <DustParticles palette="neon" count={26} seed={3} opacity={0.9} />
          <Vignette />
          {/* Poster carries the line "That simple moment became an idea." */}
        </SceneFade>
      </Sequence>

      {/* Scene 5 — Late nights */}
      <Sequence from={S5.from} durationInFrames={S5.dur}>
        <SceneFade durationInFrames={S5.dur}>
          <CinematicImage
            src="images/04-late-nights-dream.png"
            durationInFrames={S5.dur}
            move={{scaleFrom: 1.18, scaleTo: 1.06, origin: '55% 40%', yFrom: -20, yTo: 16}}
          />
          {/* Monitor glow breathing */}
          <LightBloom x="55%" y="38%" color="rgba(120,180,255,0.5)" size={1050} baseOpacity={0.34} pulsePeriod={100} />
          <LightBloom x="24%" y="20%" color="rgba(53,214,255,0.35)" size={700} baseOpacity={0.25} pulsePeriod={75} />
          <DustParticles palette="warm" count={18} seed={4} opacity={0.7} />
          <Vignette />
          {/* Poster carries the line "Hundreds of late nights. One dream." */}
        </SceneFade>
      </Sequence>

      {/* Scene 6 — Gameplay */}
      <Sequence from={S6.from} durationInFrames={S6.dur}>
        <SceneFade durationInFrames={S6.dur}>
          <GameplayScene dur={S6.dur} />
        </SceneFade>
      </Sequence>

      {/* Scene 7 — Reimagined */}
      <Sequence from={S7.from} durationInFrames={S7.dur}>
        <SceneFade durationInFrames={S7.dur}>
          <CinematicImage
            src="images/06-is-now-live.png"
            durationInFrames={S7.dur}
            move={{scaleFrom: 1.06, scaleTo: 1.16, origin: '50% 42%'}}
            rotateDeg={[-1.2, 1.2]}
            brightnessTo={1.05}
          />
          <LightBloom x="30%" y="30%" color="rgba(53,214,255,0.4)" size={950} baseOpacity={0.3} pulsePeriod={65} />
          <LightBloom x="72%" y="60%" color="rgba(255,79,216,0.4)" size={950} baseOpacity={0.3} pulsePeriod={85} />
          <DustParticles palette="neon" count={30} seed={7} />
          <Vignette />
          {/* Poster carries "DOT CLASH IS NOW LIVE!" — no extra caption. */}
        </SceneFade>
      </Sequence>

      {/* Scene 8 — Final hero */}
      <Sequence from={S8.from} durationInFrames={S8.dur}>
        <SceneFade durationInFrames={S8.dur} fadeOut={4}>
          <FinalHeroScene dur={S8.dur} />
        </SceneFade>
      </Sequence>

      {/* Boundary particle sweeps: memory → idea → game */}
      <ParticleSweep startFrame={S4.from - 26} duration={52} seed={21} />
      <ParticleSweep startFrame={S6.from - 26} duration={52} seed={22} />
      <ParticleSweep startFrame={S8.from - 26} duration={52} seed={23} count={50} />

      {/* Global film treatment */}
      <FilmGrain opacity={0.05} />
    </AbsoluteFill>
  );
};
