import 'challenge_board_preset.dart';

/// Response from the `createChallenge` callable (server-authoritative geometry).
class CreateChallengeResult {
  const CreateChallengeResult({
    required this.code,
    required this.boardPresetId,
    required this.boardPresetName,
    required this.rows,
    required this.cols,
  });

  final String code;
  final String boardPresetId;
  final String boardPresetName;
  final int rows;
  final int cols;

  factory CreateChallengeResult.fromCallable(Map<String, dynamic> json) {
    final code = json['code'] as String?;
    if (code == null || code.trim().isEmpty) {
      throw FormatException('createChallenge response missing code');
    }

    final presetId =
        json['boardPresetId'] as String? ?? ChallengeBoardPreset.defaultPresetId;
    final preset = ChallengeBoardPreset.byId(presetId);

    return CreateChallengeResult(
      code: code.trim().toUpperCase(),
      boardPresetId: presetId,
      boardPresetName:
          json['boardPresetName'] as String? ?? preset?.name ?? 'Classic',
      rows: (json['rows'] as num?)?.toInt() ?? preset?.rows ?? 6,
      cols: (json['cols'] as num?)?.toInt() ?? preset?.cols ?? 6,
    );
  }
}

/// Parameters for [createChallengeProvider].
class CreateChallengeRequest {
  const CreateChallengeRequest({
    this.targetUid,
    this.boardPresetId,
  });

  final String? targetUid;
  final String? boardPresetId;
}
