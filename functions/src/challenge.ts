import {
  FieldValue,
  Timestamp,
  type DocumentReference,
  type DocumentSnapshot,
  type Transaction,
} from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from 'firebase-functions/v2/https';

import { GameRules, GameState, type GameStateJson } from './game_rules';
import { resolveLives } from './lives';
import { sendChallengeInvitePush } from './notifications';
import {
  coinsForMatch,
  levelForXp,
  xpForMatch,
} from './progression';
import { assertAuth, callableOptions, db } from './shared';

export const CHALLENGE_ROWS = 6;
export const CHALLENGE_COLS = 6;
export const TURN_TIMEOUT_SECONDS = 30;
export const WAITING_EXPIRY_MINUTES = 60;

const CODE_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const CODE_LENGTH = 6;
const TURN_TIMEOUT_MS = TURN_TIMEOUT_SECONDS * 1000;

export type ChallengeStatus =
  | 'waiting'
  | 'active'
  | 'finished'
  | 'expired'
  | 'abandoned';

export interface ChallengeDoc {
  code: string;
  hostUid: string;
  hostDisplayName: string;
  guestUid: string | null;
  guestDisplayName: string | null;
  status: ChallengeStatus;
  rows: number;
  cols: number;
  hostPlayerId: 'A';
  guestPlayerId: 'B';
  gameState: GameStateJson | null;
  version: number;
  turnStartedAt: Timestamp | null;
  winnerUid: string | null;
  createdAt: Timestamp;
  expiresAt: Timestamp;
  lastActivityAt: Timestamp;
  /** Uids that already ran [recordChallengeMatch] (idempotency). */
  settledUids?: Record<string, boolean>;
}

export interface CommitMoveResult {
  applied: boolean;
  reason?: string;
  version?: number;
  isOver?: boolean;
}

function challengesRef(code: string): DocumentReference {
  return db.collection('challenges').doc(code);
}

function randomChallengeCode(): string {
  let code = '';
  for (let i = 0; i < CODE_LENGTH; i++) {
    code += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
  }
  return code;
}

async function loadDisplayName(uid: string): Promise<string> {
  const snap = await db.collection('profiles').doc(uid).get();
  if (!snap.exists) {
    throw new HttpsError('not-found', 'Profile not found.');
  }
  const name = snap.data()?.displayName as string | undefined;
  return name?.trim() || 'Player';
}

function initialChallengeGameState(): GameState {
  return GameState.initial({
    rows: CHALLENGE_ROWS,
    cols: CHALLENGE_COLS,
    playerIds: ['A', 'B'],
    disabledCells: new Set(),
  });
}

function parseChallengeDoc(snap: DocumentSnapshot): ChallengeDoc {
  return snap.data() as ChallengeDoc;
}

function playerIdForUid(data: ChallengeDoc, uid: string): string | null {
  if (uid === data.hostUid) return data.hostPlayerId;
  if (uid === data.guestUid) return data.guestPlayerId;
  return null;
}

function uidForPlayerId(data: ChallengeDoc, playerId: string): string | null {
  if (playerId === 'A') return data.hostUid;
  if (playerId === 'B') return data.guestUid;
  return null;
}

function winnerUidFromState(data: ChallengeDoc, state: GameState): string | null {
  if (!state.isOver || !state.winnerId) return null;
  return uidForPlayerId(data, state.winnerId);
}

function pickRandomLegalEdge(state: GameState): string | null {
  const moves = GameRules.legalMoves(state);
  if (moves.length === 0) return null;
  return moves[Math.floor(Math.random() * moves.length)];
}

/**
 * Shared transactional move commit for user moves and scheduler timeouts.
 */
export async function commitChallengeMoveInTransaction(
  txn: Transaction,
  challengeRef: DocumentReference,
  opts: {
    edgeKey?: string;
    callerUid?: string;
    isTimeout?: boolean;
  },
): Promise<CommitMoveResult> {
  const snap = await txn.get(challengeRef);
  if (!snap.exists) {
    if (opts.isTimeout) return { applied: false, reason: 'not_found' };
    throw new HttpsError('not-found', 'Challenge not found.');
  }

  const data = parseChallengeDoc(snap);
  if (data.status !== 'active' || !data.gameState) {
    if (opts.isTimeout) return { applied: false, reason: 'not_active' };
    throw new HttpsError('failed-precondition', 'Challenge is not active.');
  }

  if (opts.isTimeout) {
    const turnStartedAt = data.turnStartedAt;
    if (!turnStartedAt) return { applied: false, reason: 'no_turn_started' };
    const deadline = turnStartedAt.toMillis() + TURN_TIMEOUT_MS;
    if (Date.now() < deadline) return { applied: false, reason: 'not_timed_out' };
  } else {
    if (!opts.callerUid) {
      throw new HttpsError('invalid-argument', 'Missing caller.');
    }
    const playerId = playerIdForUid(data, opts.callerUid);
    if (!playerId) {
      throw new HttpsError('permission-denied', 'Not in this challenge.');
    }
    const state = GameState.fromJson(data.gameState);
    if (state.currentPlayerId !== playerId) {
      throw new HttpsError('failed-precondition', 'Not your turn.');
    }
    if (!opts.edgeKey || !GameRules.isLegalMove(state, opts.edgeKey)) {
      throw new HttpsError('invalid-argument', 'Illegal move.');
    }
  }

  const state = GameState.fromJson(data.gameState);
  const edgeKey = opts.isTimeout
    ? pickRandomLegalEdge(state)
    : opts.edgeKey;

  if (!edgeKey) {
    if (opts.isTimeout) return { applied: false, reason: 'no_legal_moves' };
    throw new HttpsError('invalid-argument', 'Illegal move.');
  }

  const newState = GameRules.applyMove(state, edgeKey);
  const now = Timestamp.now();
  const newVersion = (data.version ?? 0) + 1;

  const update: Record<string, unknown> = {
    gameState: newState.toJson(),
    version: newVersion,
    turnStartedAt: now,
    lastActivityAt: now,
  };

  if (newState.isOver) {
    update.status = 'finished';
    update.winnerUid = winnerUidFromState(data, newState);
  }

  txn.update(challengeRef, update);

  return {
    applied: true,
    version: newVersion,
    isOver: newState.isOver,
  };
}

export const createChallenge = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const { targetUid } = (request.data ?? {}) as { targetUid?: string };

  const hostDisplayName = await loadDisplayName(uid);
  const now = Timestamp.now();
  const expiresAt = Timestamp.fromMillis(
    now.toMillis() + WAITING_EXPIRY_MINUTES * 60 * 1000,
  );

  let code = '';
  let created = false;

  for (let attempt = 0; attempt < 8; attempt++) {
    code = randomChallengeCode();
    const ref = challengesRef(code);
    const existing = await ref.get();
    if (existing.exists) continue;

    const doc: Omit<ChallengeDoc, 'createdAt' | 'lastActivityAt'> & {
      createdAt: ReturnType<typeof FieldValue.serverTimestamp>;
      lastActivityAt: ReturnType<typeof FieldValue.serverTimestamp>;
    } = {
      code,
      hostUid: uid,
      hostDisplayName,
      guestUid: null,
      guestDisplayName: null,
      status: 'waiting',
      rows: CHALLENGE_ROWS,
      cols: CHALLENGE_COLS,
      hostPlayerId: 'A',
      guestPlayerId: 'B',
      gameState: null,
      version: 0,
      turnStartedAt: null,
      winnerUid: null,
      expiresAt,
      createdAt: FieldValue.serverTimestamp(),
      lastActivityAt: FieldValue.serverTimestamp(),
    };

    await ref.set(doc);
    created = true;
    break;
  }

  if (!created) {
    throw new HttpsError('resource-exhausted', 'Could not allocate challenge code.');
  }

  if (targetUid && typeof targetUid === 'string' && targetUid !== uid) {
    await sendChallengeInvitePush(targetUid, hostDisplayName, code);
  }

  return { success: true, code };
});

export const joinChallenge = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const { code } = request.data as { code?: string };
  if (!code || typeof code !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing code.');
  }

  const normalized = code.trim().toUpperCase();
  const guestDisplayName = await loadDisplayName(uid);
  const ref = challengesRef(normalized);

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Challenge not found.');
    }

    const data = parseChallengeDoc(snap);

    if (data.status !== 'waiting') {
      throw new HttpsError('failed-precondition', 'Challenge is not joinable.');
    }
    if (data.guestUid) {
      throw new HttpsError('failed-precondition', 'Challenge is full.');
    }
    if (data.hostUid === uid) {
      throw new HttpsError('invalid-argument', 'Cannot join your own challenge.');
    }
    if (data.expiresAt.toMillis() <= Date.now()) {
      txn.update(ref, {
        status: 'expired',
        lastActivityAt: FieldValue.serverTimestamp(),
      });
      throw new HttpsError('failed-precondition', 'Challenge expired.');
    }

    const now = Timestamp.now();
    txn.update(ref, {
      guestUid: uid,
      guestDisplayName,
      status: 'active',
      gameState: initialChallengeGameState().toJson(),
      version: 0,
      turnStartedAt: now,
      lastActivityAt: now,
    });
  });

  return { success: true, code: normalized };
});

export const submitChallengeMove = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const { code, edgeKey } = request.data as { code?: string; edgeKey?: string };
  if (!code || typeof code !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing code.');
  }
  if (!edgeKey || typeof edgeKey !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing edgeKey.');
  }

  const normalized = code.trim().toUpperCase();
  const ref = challengesRef(normalized);

  const result = await db.runTransaction((txn) =>
    commitChallengeMoveInTransaction(txn, ref, {
      callerUid: uid,
      edgeKey: edgeKey.trim(),
    }),
  );

  return {
    success: result.applied,
    version: result.version,
    isOver: result.isOver ?? false,
  };
});

export const abandonChallenge = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const { code } = request.data as { code?: string };
  if (!code || typeof code !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing code.');
  }

  const normalized = code.trim().toUpperCase();
  const ref = challengesRef(normalized);

  await db.runTransaction(async (txn) => {
    const snap = await txn.get(ref);
    if (!snap.exists) {
      throw new HttpsError('not-found', 'Challenge not found.');
    }

    const data = parseChallengeDoc(snap);
    const isHost = uid === data.hostUid;
    const isGuest = uid === data.guestUid;
    if (!isHost && !isGuest) {
      throw new HttpsError('permission-denied', 'Not in this challenge.');
    }

    if (data.status === 'finished' || data.status === 'abandoned' || data.status === 'expired') {
      return;
    }

    const update: Record<string, unknown> = {
      status: 'abandoned',
      lastActivityAt: FieldValue.serverTimestamp(),
    };

    if (data.status === 'active') {
      update.winnerUid = isHost ? data.guestUid : data.hostUid;
    }

    txn.update(ref, update);
  });

  return { success: true };
});

function profileRef(uid: string): DocumentReference {
  return db.collection('profiles').doc(uid);
}

function outcomeForUid(data: ChallengeDoc, uid: string): 'win' | 'loss' | 'tie' {
  if (data.status === 'abandoned') {
    return data.winnerUid === uid ? 'win' : 'loss';
  }
  if (!data.gameState) {
    throw new HttpsError('failed-precondition', 'Challenge has no game state.');
  }
  const state = GameState.fromJson(data.gameState);
  if (state.isOver && state.winnerId == null) return 'tie';
  const playerId = playerIdForUid(data, uid);
  if (!playerId || !state.winnerId) return 'loss';
  return state.winnerId === playerId ? 'win' : 'loss';
}

/**
 * Idempotent settlement: profile stats + `profiles/{uid}/matches` entry.
 * Client calls once when the room reaches a terminal state.
 */
export const recordChallengeMatch = onCall(callableOptions, async (request) => {
  const uid = assertAuth(request);
  const { code } = request.data as { code?: string };
  if (!code || typeof code !== 'string') {
    throw new HttpsError('invalid-argument', 'Missing code.');
  }

  const normalized = code.trim().toUpperCase();
  const challengeRef = challengesRef(normalized);
  const nowMs = Date.now();

  return db.runTransaction(async (txn) => {
    const challengeSnap = await txn.get(challengeRef);
    if (!challengeSnap.exists) {
      throw new HttpsError('not-found', 'Challenge not found.');
    }

    const data = parseChallengeDoc(challengeSnap);
    const playerId = playerIdForUid(data, uid);
    if (!playerId) {
      throw new HttpsError('permission-denied', 'Not in this challenge.');
    }

    if (data.status !== 'finished' && data.status !== 'abandoned') {
      throw new HttpsError('failed-precondition', 'Challenge is not finished.');
    }

    if (data.settledUids?.[uid]) {
      return { success: true, alreadySettled: true };
    }

    const outcome = outcomeForUid(data, uid);
    const win = outcome === 'win';
    const tie = outcome === 'tie';
    const opponentLabel =
      uid === data.hostUid
        ? (data.guestDisplayName ?? 'Rival')
        : data.hostDisplayName;

    const profileSnap = await txn.get(profileRef(uid));
    if (!profileSnap.exists) {
      throw new HttpsError('not-found', 'Profile not found.');
    }
    const profile = profileSnap.data()!;

    const deltaCoins = coinsForMatch(win, tie);
    const deltaXp = xpForMatch(win, tie);
    const newXp = Number(profile.xp ?? 0) + deltaXp;

    let rating = Number(profile.rating ?? 1000);
    if (win) rating += 18;
    else if (tie) rating += 2;
    else rating -= 18;
    if (rating < 800) rating = 800;

    const seasonBest = Math.max(Number(profile.seasonBestRating ?? 1000), rating);

    const resolved = resolveLives(
      Number(profile.lives ?? 5),
      profile.nextLifeAt as Timestamp | null | undefined,
      nowMs,
    );

    const newStreak = win
      ? Number(profile.winStreak ?? 0) + 1
      : tie
        ? Number(profile.winStreak ?? 0)
        : 0;
    const bestStreak = Math.max(Number(profile.bestWinStreak ?? 0), newStreak);

    const matchesRef = profileRef(uid).collection('matches').doc();

    txn.set(matchesRef, {
      outcome,
      modeLabel: 'Challenge',
      opponentLabel,
      challengeCode: normalized,
      playedAt: FieldValue.serverTimestamp(),
    });

    txn.update(profileRef(uid), {
      coins: Number(profile.coins ?? 0) + deltaCoins,
      xp: newXp,
      level: levelForXp(newXp),
      wins: Number(profile.wins ?? 0) + (win ? 1 : 0),
      losses: Number(profile.losses ?? 0) + (outcome === 'loss' ? 1 : 0),
      ties: Number(profile.ties ?? 0) + (tie ? 1 : 0),
      gamesPlayed: Number(profile.gamesPlayed ?? 0) + 1,
      winStreak: newStreak,
      bestWinStreak: bestStreak,
      rating,
      seasonBestRating: seasonBest,
      seasonWins: Number(profile.seasonWins ?? 0) + (win ? 1 : 0),
      seasonLosses: Number(profile.seasonLosses ?? 0) + (outcome === 'loss' ? 1 : 0),
      seasonTies: Number(profile.seasonTies ?? 0) + (tie ? 1 : 0),
      lives: resolved.lives,
      nextLifeAt: resolved.nextLifeAt,
      updatedAt: FieldValue.serverTimestamp(),
    });

    txn.update(challengeRef, {
      [`settledUids.${uid}`]: true,
      lastActivityAt: FieldValue.serverTimestamp(),
    });

    return { success: true, outcome, alreadySettled: false };
  });
});
