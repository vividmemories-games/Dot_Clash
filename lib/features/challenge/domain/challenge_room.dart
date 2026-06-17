import 'package:cloud_firestore/cloud_firestore.dart';

import '../../game/domain/models/game_state.dart';
import 'challenge_board_preset.dart';
import 'challenge_status.dart';

/// Live challenge room mirrored from `challenges/{code}`.
class ChallengeRoom {
  const ChallengeRoom({
    required this.code,
    required this.hostUid,
    required this.hostDisplayName,
    required this.guestUid,
    required this.guestDisplayName,
    required this.status,
    this.boardPresetId = ChallengeBoardPreset.defaultPresetId,
    this.boardPresetName = 'Classic',
    required this.rows,
    required this.cols,
    required this.version,
    required this.winnerUid,
    required this.expiresAt,
    required this.lastActivityAt,
    required this.gameState,
    required this.turnStartedAt,
  });

  final String code;
  final String hostUid;
  final String hostDisplayName;
  final String? guestUid;
  final String? guestDisplayName;
  final ChallengeStatus status;
  final String boardPresetId;
  final String boardPresetName;
  final int rows;
  final int cols;
  final int version;
  final String? winnerUid;
  final DateTime? expiresAt;
  final DateTime? lastActivityAt;
  final GameState? gameState;
  final DateTime? turnStartedAt;

  /// Resolved preset metadata for lobby / share (falls back to Classic).
  ChallengeBoardPreset get boardPreset =>
      ChallengeBoardPreset.byId(boardPresetId) ??
      ChallengeBoardPreset.defaultPreset;

  bool get isWaiting => status == ChallengeStatus.waiting;
  bool get isActive => status == ChallengeStatus.active;
  bool get isTerminal => status.isTerminal;

  /// True when the play route should keep [GameScreen] mounted (including after
  /// `finished` / `abandoned` so the result dialog can show).
  bool get hasPlayableBoard =>
      gameState != null &&
      (isActive ||
          status == ChallengeStatus.finished ||
          status == ChallengeStatus.abandoned);

  String opponentDisplayNameFor(String myUid) {
    if (myUid == hostUid) return guestDisplayName ?? 'Waiting…';
    return hostDisplayName;
  }

  /// Server player id for [uid] (`A` = host, `B` = guest).
  String? playerIdForUid(String uid) {
    if (uid == hostUid) return 'A';
    if (uid == guestUid) return 'B';
    return null;
  }

  /// Opponent Firebase uid for [myUid], when the room has both players.
  String? opponentUidFor(String myUid) {
    if (myUid == hostUid) return guestUid;
    if (myUid == guestUid) return hostUid;
    return null;
  }

  factory ChallengeRoom.fromFirestore(
    String code,
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data()!;
    return ChallengeRoom(
      code: code,
      hostUid: data['hostUid'] as String,
      hostDisplayName: (data['hostDisplayName'] as String?) ?? 'Player',
      guestUid: data['guestUid'] as String?,
      guestDisplayName: data['guestDisplayName'] as String?,
      status: ChallengeStatus.parse(data['status'] as String? ?? 'expired'),
      boardPresetId: data['boardPresetId'] as String? ??
          ChallengeBoardPreset.defaultPresetId,
      boardPresetName: data['boardPresetName'] as String? ??
          ChallengeBoardPreset.defaultPreset.name,
      rows: (data['rows'] as num?)?.toInt() ?? 6,
      cols: (data['cols'] as num?)?.toInt() ?? 6,
      version: (data['version'] as num?)?.toInt() ?? 0,
      winnerUid: data['winnerUid'] as String?,
      expiresAt: _timestampToDateTime(data['expiresAt']),
      lastActivityAt: _timestampToDateTime(data['lastActivityAt']),
      gameState: _parseGameState(data['gameState']),
      turnStartedAt: _timestampToDateTime(data['turnStartedAt']),
    );
  }

  static GameState? _parseGameState(Object? raw) {
    if (raw is! Map) return null;
    return GameState.fromJson(Map<String, dynamic>.from(raw));
  }

  static DateTime? _timestampToDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
