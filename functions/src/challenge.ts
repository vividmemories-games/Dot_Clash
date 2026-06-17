import {
  FieldValue,
  Timestamp,
  type DocumentReference,
  type DocumentSnapshot,
  type Transaction,
} from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { onCall } from 'firebase-functions/v2/https';

import {
  DEFAULT_CHALLENGE_PRESET_ID,
  initialGameStateForPreset,
  InvalidChallengePresetError,
  resolveChallengePreset,
  type ChallengeBoardPreset,
} from './challenge_board_presets';
import { GameRules, GameState, type GameStateJson } from './game_rules';
import { sendChallengeInvitePush } from './notifications';
import { assertAuth, callableOptions, db } from './shared';

/** Legacy default grid size (Classic preset). */
export const CHALLENGE_ROWS = 6;
export const CHALLENGE_COLS = 6;
export const TURN_TIMEOUT_SECONDS = 30;
export const WAITING_EXPIRY_MINUTES = 60;
/** Auto-abandon active matches with no activity for this long. */
export const ACTIVE_STALE_HOURS = 24;

const CODE_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
const CODE_LENGTH = 6;
const TURN_TIMEOUT_MS = TURN_TIMEOUT_SECONDS * 1000;
const CHALLENGE_PUSH_COOLDOWN_MS = 60_000;

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
  boardPresetId?: string;
  boardPresetName?: string;
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

function presetForRoom(data: ChallengeDoc): ChallengeBoardPreset {
  return resolveChallengePreset(data.boardPresetId ?? DEFAULT_CHALLENGE_PRESET_ID);
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

async function hostHasChallengeHistoryWith(
  hostUid: string,
  targetUid: string,
): Promise<boolean> {
  const snap = await profileRef(hostUid)
    .collection('matches')
    .orderBy('playedAt', 'desc')
    .limit(40)
    .get();
  return snap.docs.some((doc) => {
    const data = doc.data();
    return data.modeLabel === 'Challenge' && data.opponentUid === targetUid;
  });
}

async function trySendChallengeInvitePush(
  hostUid: string,
  targetUid: string,
  hostDisplayName: string,
  code: string,
): Promise<void> {
  const isRival = await hostHasChallengeHistoryWith(hostUid, targetUid);
  if (!isRival) {
    console.log('FCM challenge invite skipped', {
      reason: 'not_recent_rival',
      hostUid,
      targetUid,
      code,
    });
    return;
  }

  const throttleRef = db
    .collection('challenge_push_throttle')
    .doc(`${hostUid}_${targetUid}`);
  const throttleSnap = await throttleRef.get();
  const until = throttleSnap.data()?.until as number | undefined;
  if (until != null && until > Date.now()) {
    console.log('FCM challenge invite skipped', {
      reason: 'throttled',
      hostUid,
      targetUid,
      code,
    });
    return;
  }

  await sendChallengeInvitePush(targetUid, hostDisplayName, code);
  await throttleRef.set({ until: Date.now() + CHALLENGE_PUSH_COOLDOWN_MS });
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
  const { targetUid, boardPresetId } = (request.data ?? {}) as {
    targetUid?: string;
    boardPresetId?: string;
  };

  let preset: ChallengeBoardPreset;
  try {
    preset = resolveChallengePreset(boardPresetId);
  } catch (err) {
    if (err instanceof InvalidChallengePresetError) {
      throw new HttpsError('invalid-argument', err.message);
    }
    throw err;
  }

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
      boardPresetId: preset.id,
      boardPresetName: preset.name,
      rows: preset.rows,
      cols: preset.cols,
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
    await trySendChallengeInvitePush(uid, targetUid, hostDisplayName, code);
  }

  return {
    success: true,
    code,
    boardPresetId: preset.id,
    boardPresetName: preset.name,
    rows: preset.rows,
    cols: preset.cols,
  };
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

    const preset = presetForRoom(data);
    const now = Timestamp.now();
    txn.update(ref, {
      guestUid: uid,
      guestDisplayName,
      status: 'active',
      gameState: initialGameStateForPreset(preset).toJson(),
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
  if (data.status === 'finished' || data.status === 'abandoned') {
    if (!data.winnerUid) return 'tie';
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
 * Idempotent settlement: challenge match history only (no economy).
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
    const opponentLabel =
      uid === data.hostUid
        ? (data.guestDisplayName ?? 'Rival')
        : data.hostDisplayName;
    const opponentUid =
      uid === data.hostUid ? data.guestUid : data.hostUid;

    const profileSnap = await txn.get(profileRef(uid));
    if (!profileSnap.exists) {
      throw new HttpsError('not-found', 'Profile not found.');
    }

    const matchesRef = profileRef(uid).collection('matches').doc();

    txn.set(matchesRef, {
      outcome,
      modeLabel: 'Challenge',
      opponentLabel,
      challengeCode: normalized,
      playedAt: FieldValue.serverTimestamp(),
      ...(opponentUid ? { opponentUid } : {}),
    });

    txn.update(challengeRef, {
      [`settledUids.${uid}`]: true,
      lastActivityAt: FieldValue.serverTimestamp(),
    });

    return { success: true, outcome, alreadySettled: false };
  });
});
