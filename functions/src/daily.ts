import type { DocumentData } from 'firebase-admin/firestore';

/** UTC calendar day key (yyyy-MM-dd). */
export function todayUtc(): string {
  return new Date().toISOString().slice(0, 10);
}

export function yesterdayUtc(): string {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().slice(0, 10);
}

export interface DailyMissionProgress {
  date: string;
  wins: number;
  games: number;
  boxes: number;
  claimed: Record<string, boolean>;
}

export function freshDailyMissionProgress(date: string): DailyMissionProgress {
  return { date, wins: 0, games: 0, boxes: 0, claimed: {} };
}

export function readDailyMissionProgress(profile: DocumentData): DailyMissionProgress {
  const today = todayUtc();
  const raw = profile.dailyMissions as Record<string, unknown> | undefined;
  if (!raw || raw.date !== today) {
    return freshDailyMissionProgress(today);
  }
  return {
    date: today,
    wins: Number(raw.wins ?? 0),
    games: Number(raw.games ?? 0),
    boxes: Number(raw.boxes ?? 0),
    claimed: (raw.claimed as Record<string, boolean>) ?? {},
  };
}

export const MISSION_TARGETS: Record<string, { target: number; coins: number }> = {
  win_matches: { target: 3, coins: 45 },
  play_games: { target: 4, coins: 60 },
  capture_boxes: { target: 15, coins: 35 },
};

export function missionProgressForId(id: string, progress: DailyMissionProgress): number {
  switch (id) {
    case 'win_matches':
      return progress.wins;
    case 'play_games':
      return progress.games;
    case 'capture_boxes':
      return progress.boxes;
    default:
      return 0;
  }
}
