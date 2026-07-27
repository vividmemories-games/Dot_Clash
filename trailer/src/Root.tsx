import {Composition} from 'remotion';
import {Trailer, TRAILER_DURATION, FPS, WIDTH, HEIGHT} from './Trailer';

export const RemotionRoot: React.FC = () => {
  return (
    <Composition
      id="Trailer"
      component={Trailer}
      durationInFrames={TRAILER_DURATION}
      fps={FPS}
      width={WIDTH}
      height={HEIGHT}
    />
  );
};
