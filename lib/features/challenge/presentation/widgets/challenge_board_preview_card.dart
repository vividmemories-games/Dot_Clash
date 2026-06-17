import 'package:flutter/material.dart';

import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../../../shared/layout/app_spacing.dart';
import '../../domain/challenge_board_preset.dart';

/// Read-only board layout card for preset picker and challenge lobby.
class ChallengeBoardPreviewCard extends StatelessWidget {
  const ChallengeBoardPreviewCard({
    super.key,
    required this.preset,
    this.eyebrow,
    this.showFairnessLine = false,
    this.selected = false,
    this.onTap,
    this.showThumbnail = true,
  });

  final ChallengeBoardPreset preset;
  final String? eyebrow;
  final bool showFairnessLine;
  final bool selected;
  final VoidCallback? onTap;
  final bool showThumbnail;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    final t = context.txt;
    final borderColor = selected ? v.playerA : v.cardBorder;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.roundedLG,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: v.surfaceElevated,
            borderRadius: AppSpacing.roundedLG,
            border: Border.all(
              color: selected
                  ? v.playerA.withValues(alpha: 0.85)
                  : borderColor,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: v.playerA.withValues(alpha: 0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!,
                  style: t.scoreLabel.copyWith(
                    fontSize: 10,
                    color: v.textSecondary,
                  ),
                ),
                AppSpacing.vGapSM,
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preset.name,
                          style: t.playerName.copyWith(fontSize: 18),
                        ),
                        AppSpacing.vGapXS,
                        Text(
                          preset.tagline,
                          style: t.bodySmall.copyWith(color: v.textSecondary),
                        ),
                        AppSpacing.vGapSM,
                        _DurationChip(label: preset.estimatedMinutes, v: v, t: t),
                      ],
                    ),
                  ),
                  if (showThumbnail) ...[
                    AppSpacing.hGapMD,
                    _MiniBoardThumbnail(
                      rows: preset.rows,
                      cols: preset.cols,
                      disabledCells: preset.disabledCells.toSet(),
                      accent: selected ? v.playerA : v.textSecondary,
                    ),
                  ],
                ],
              ),
              if (showFairnessLine) ...[
                AppSpacing.vGapSM,
                Text(
                  'You\'ll both play on this layout.',
                  style: t.bodySmall.copyWith(color: v.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.v,
    required this.t,
  });

  final String label;
  final DotClashVisuals v;
  final AppTextStyles t;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: v.gold.withValues(alpha: 0.12),
        borderRadius: AppSpacing.roundedFull,
        border: Border.all(color: v.gold.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: t.scoreLabel.copyWith(fontSize: 9, color: v.gold),
      ),
    );
  }
}

class _MiniBoardThumbnail extends StatelessWidget {
  const _MiniBoardThumbnail({
    required this.rows,
    required this.cols,
    required this.disabledCells,
    required this.accent,
  });

  final int rows;
  final int cols;
  final Set<String> disabledCells;
  final Color accent;

  static const _size = 72.0;

  @override
  Widget build(BuildContext context) {
    final v = context.dc;
    return SizedBox(
      width: _size,
      height: _size,
      child: CustomPaint(
        painter: _MiniBoardPainter(
          rows: rows,
          cols: cols,
          disabledCells: disabledCells,
          dotColor: accent,
          voidColor: v.scaffold.withValues(alpha: 0.85),
          edgeColor: v.cardBorder,
        ),
      ),
    );
  }
}

class _MiniBoardPainter extends CustomPainter {
  _MiniBoardPainter({
    required this.rows,
    required this.cols,
    required this.disabledCells,
    required this.dotColor,
    required this.voidColor,
    required this.edgeColor,
  });

  final int rows;
  final int cols;
  final Set<String> disabledCells;
  final Color dotColor;
  final Color voidColor;
  final Color edgeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final pad = size.width * 0.08;
    final inner = size.width - pad * 2;
    final cell = inner / (cols > rows ? cols - 1 : rows - 1).clamp(1, 99);

    Offset dot(int r, int c) => Offset(
          pad + c * cell,
          pad + r * cell,
        );

    for (final key in disabledCells) {
      final parts = key.split('_');
      if (parts.length != 2) continue;
      final r = int.tryParse(parts[0]);
      final c = int.tryParse(parts[1]);
      if (r == null || c == null) continue;
      final tl = dot(r, c);
      final br = dot(r + 1, c + 1);
      canvas.drawRect(
        Rect.fromLTRB(tl.dx, tl.dy, br.dx, br.dy),
        Paint()..color = voidColor,
      );
    }

    final edgePaint = Paint()
      ..color = edgeColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols - 1; c++) {
        canvas.drawLine(dot(r, c), dot(r, c + 1), edgePaint);
      }
    }
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawLine(dot(r, c), dot(r + 1, c), edgePaint);
      }
    }

    final dotPaint = Paint()..color = dotColor;
    final radius = cell * 0.09;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        canvas.drawCircle(dot(r, c), radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniBoardPainter oldDelegate) {
    return oldDelegate.rows != rows ||
        oldDelegate.cols != cols ||
        oldDelegate.disabledCells != disabledCells;
  }
}
