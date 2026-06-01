import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/feedback/app_haptics.dart';
import '../../../../core/theme/dot_clash_visuals.dart';
import '../../domain/models/game_state.dart';
import '../../domain/rules/game_rules.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public API
// ─────────────────────────────────────────────────────────────────────────────

class BoardWidget extends StatefulWidget {
  const BoardWidget({
    super.key,
    required this.state,
    required this.onEdgeTap,
    this.isInteractive = true,
    this.hintEdge,
    this.opponentHighlightEdge,
    this.playerInitials = const {},
  });

  final GameState state;
  final void Function(String edgeKey) onEdgeTap;
  final bool isInteractive;

  /// When set, this edge is highlighted with a pulsing gold glow.
  final String? hintEdge;

  /// Opponent's most recent edge — pulsing rival color for readability.
  final String? opponentHighlightEdge;

  /// Maps playerId -> single-letter initial to render inside claimed squares.
  /// If not present, the painter falls back to the playerId's first character.
  final Map<String, String> playerInitials;

  @override
  State<BoardWidget> createState() => _BoardWidgetState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State — manages all animation controllers
// ─────────────────────────────────────────────────────────────────────────────

class _BoardWidgetState extends State<BoardWidget>
    with TickerProviderStateMixin {
  // Ambient pulse: 0 → 1 → 0, drives dot glow and hint edge breathing.
  late final AnimationController _pulseCtrl;

  // Per-edge draw animation (line draws in from one dot to the other).
  final Map<String, AnimationController> _edgeAnims = {};

  // Per-box fill animation (rect blooms in from the center).
  final Map<String, AnimationController> _claimAnims = {};

  // Riposte rewind: briefly show removed edges/boxes fading out.
  AnimationController? _rewindCtrl;
  Set<String> _rewindFadeEdges = {};
  Map<String, String> _rewindFadeBoxes = {};
  Map<String, String> _rewindFadeOwnership = {};

  // Edge → player who drew it (from GameState.edgeOwners).
  Map<String, String> _edgeOwnership = {};

  // Touch state for immediate visual feedback.
  String? _hoveredEdge;
  String? _pressedEdge;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _edgeOwnership = Map<String, String>.from(widget.state.edgeOwners);
  }

  @override
  void didUpdateWidget(BoardWidget old) {
    super.didUpdateWidget(old);
    if (identical(widget.state, old.state)) return;

    _edgeOwnership = Map<String, String>.from(widget.state.edgeOwners);

    if (widget.state.moveHistory.length < old.state.moveHistory.length) {
      _rewindFadeEdges =
          old.state.drawnEdges.difference(widget.state.drawnEdges);
      _rewindFadeBoxes = {
        for (final key in old.state.claimedBoxes.keys)
          if (!widget.state.claimedBoxes.containsKey(key))
            key: old.state.claimedBoxes[key]!,
      };
      _rewindFadeOwnership = Map<String, String>.from(old.state.edgeOwners);
      _rewindCtrl?.dispose();
      _rewindCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 580),
      )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            setState(() {
              _rewindFadeEdges = {};
              _rewindFadeBoxes = {};
              _rewindFadeOwnership = {};
              _rewindCtrl?.dispose();
              _rewindCtrl = null;
            });
          }
        });
      setState(() {});
      _rewindCtrl!.forward();
    }

    // Start a draw animation for every newly placed edge.
    final newEdges =
        widget.state.drawnEdges.difference(old.state.drawnEdges);
    for (final edge in newEdges) {
      if (_edgeAnims.containsKey(edge)) continue;
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 320),
      );
      ctrl.addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          // Remove from map; parent build triggered by setState below
          setState(() {
            _edgeAnims.remove(edge)?.dispose();
          });
        }
      });
      setState(() {
        _edgeAnims[edge] = ctrl;
      });
      ctrl.forward();
    }

    // Start a bloom animation for every newly claimed box.
    final newBoxes = widget.state.claimedBoxes.keys
        .where((k) => !old.state.claimedBoxes.containsKey(k));
    for (final box in newBoxes) {
      if (_claimAnims.containsKey(box)) continue;
      final ctrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 420),
      );
      ctrl.addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() {
            _claimAnims.remove(box)?.dispose();
          });
        }
      });
      setState(() {
        _claimAnims[box] = ctrl;
      });
      ctrl.forward();
    }
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rewindCtrl?.dispose();
    for (final c in _edgeAnims.values) c.dispose();
    for (final c in _claimAnims.values) c.dispose();
    super.dispose();
  }

  // ── Gesture helpers ────────────────────────────────────────────────────────

  bool get _canInteract => widget.isInteractive && !widget.state.isOver;

  String? _hitTest(Offset position, _BoardLayout layout) {
    final edge = layout.hitTest(position);
    if (edge == null) return null;
    if (widget.state.drawnEdges.contains(edge)) return null;
    return edge;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final visuals = context.dc;
    return LayoutBuilder(builder: (context, constraints) {
      final layout = _BoardLayout.compute(
        constraints.maxWidth,
        constraints.maxHeight,
        widget.state,
      );

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _canInteract
            ? (d) {
                final edge = _hitTest(d.localPosition, layout);
                if (edge != null) {
                  AppHaptics.lightImpact();
                  setState(() => _pressedEdge = edge);
                }
              }
            : null,
        onTapUp: _canInteract
            ? (d) {
                final edge = _hitTest(d.localPosition, layout);
                if (edge != null && edge == _pressedEdge) {
                  widget.onEdgeTap(edge);
                }
                setState(() {
                  _pressedEdge = null;
                  _hoveredEdge = null;
                });
              }
            : null,
        onTapCancel: () => setState(() {
          _pressedEdge = null;
          _hoveredEdge = null;
        }),
        onPanUpdate: _canInteract
            ? (d) {
                final edge = _hitTest(d.localPosition, layout);
                if (edge != _hoveredEdge) {
                  setState(() => _hoveredEdge = edge);
                }
              }
            : null,
        onPanEnd: (_) => setState(() {
          _hoveredEdge = null;
          _pressedEdge = null;
        }),
        child: RepaintBoundary(
          child: AnimatedBuilder(
            // Listen to all live animation controllers in a single frame pump.
            animation: Listenable.merge([
              _pulseCtrl,
              if (_rewindCtrl != null) _rewindCtrl!,
              ..._edgeAnims.values,
              ..._claimAnims.values,
            ]),
            builder: (_, __) {
              final rewindFadeT = _rewindCtrl == null
                  ? 0.0
                  : (1.0 - Curves.easeInCubic.transform(_rewindCtrl!.value))
                      .clamp(0.0, 1.0);
              return CustomPaint(
                size: Size(constraints.maxWidth, constraints.maxHeight),
                isComplex: true,
                willChange: _edgeAnims.isNotEmpty ||
                    _claimAnims.isNotEmpty ||
                    _rewindCtrl != null,
                painter: _BoardPainter(
                  state: widget.state,
                  layout: layout,
                  visuals: visuals,
                  ownership: _edgeOwnership,
                  playerInitials: widget.playerInitials,
                  edgeProgress: {
                    for (final e in _edgeAnims.entries)
                      e.key: Curves.easeOutCubic.transform(e.value.value),
                  },
                  claimProgress: {
                    for (final e in _claimAnims.entries)
                      e.key: Curves.easeOutCubic.transform(e.value.value),
                  },
                  pulseValue: _pulseCtrl.value,
                  hoveredEdge: _hoveredEdge,
                  pressedEdge: _pressedEdge,
                  hintEdge: widget.hintEdge,
                  opponentHighlightEdge: widget.opponentHighlightEdge,
                  rewindFadeEdges: _rewindFadeEdges,
                  rewindFadeBoxes: _rewindFadeBoxes,
                  rewindFadeOwnership: _rewindFadeOwnership,
                  rewindFadeT: rewindFadeT,
                ),
              );
            },
          ),
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout math
// ─────────────────────────────────────────────────────────────────────────────

class _BoardLayout {
  _BoardLayout._({
    required this.cellSize,
    required this.offsetX,
    required this.offsetY,
    required this.rows,
    required this.cols,
  });

  final double cellSize;
  final double offsetX;
  final double offsetY;
  final int rows;
  final int cols;

  factory _BoardLayout.compute(
    double width,
    double height,
    GameState state,
  ) {
    const margin = 0.09;
    final usableW = width * (1 - 2 * margin);
    final usableH = height * (1 - 2 * margin);
    final cellW = usableW / max(state.cols - 1, 1);
    final cellH = usableH / max(state.rows - 1, 1);
    final cell = min(cellW, cellH);

    final boardW = cell * (state.cols - 1);
    final boardH = cell * (state.rows - 1);

    return _BoardLayout._(
      cellSize: cell,
      offsetX: (width - boardW) / 2,
      offsetY: (height - boardH) / 2,
      rows: state.rows,
      cols: state.cols,
    );
  }

  Offset dot(int row, int col) => Offset(
        offsetX + col * cellSize,
        offsetY + row * cellSize,
      );

  Offset hCenter(int row, int col) => Offset(
        offsetX + (col + 0.5) * cellSize,
        offsetY + row * cellSize,
      );

  Offset vCenter(int row, int col) => Offset(
        offsetX + col * cellSize,
        offsetY + (row + 0.5) * cellSize,
      );

  (Offset, Offset) edgeEndpoints(String key) {
    final (:isH, :row, :col) = GameRules.parseEdge(key);
    if (isH) {
      return (dot(row, col), dot(row, col + 1));
    } else {
      return (dot(row, col), dot(row + 1, col));
    }
  }

  /// Nearest undrawn edge to [tap], within cellSize * 0.44 threshold.
  String? hitTest(Offset tap) {
    String? best;
    double bestDist = cellSize * 0.44;

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final d = (tap - hCenter(r, c)).distance;
        if (d < bestDist) {
          bestDist = d;
          best = GameRules.hEdge(r, c);
        }
      }
    }
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols; c++) {
        final d = (tap - vCenter(r, c)).distance;
        if (d < bestDist) {
          bestDist = d;
          best = GameRules.vEdge(r, c);
        }
      }
    }
    return best;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter
// ─────────────────────────────────────────────────────────────────────────────

class _BoardPainter extends CustomPainter {
  const _BoardPainter({
    required this.state,
    required this.layout,
    required this.visuals,
    required this.ownership,
    required this.playerInitials,
    required this.edgeProgress,
    required this.claimProgress,
    required this.pulseValue,
    required this.hoveredEdge,
    required this.pressedEdge,
    required this.hintEdge,
    this.opponentHighlightEdge,
    this.rewindFadeEdges = const {},
    this.rewindFadeBoxes = const {},
    this.rewindFadeOwnership = const {},
    this.rewindFadeT = 0,
  });

  final GameState state;
  final _BoardLayout layout;
  final DotClashVisuals visuals;
  final Map<String, String> ownership;
  final Map<String, String> playerInitials;

  /// 0–1 per in-flight edge draw animation. Missing = fully drawn.
  final Map<String, double> edgeProgress;

  /// 0–1 per in-flight box claim animation. Missing = fully claimed.
  final Map<String, double> claimProgress;

  /// 0–1 ambient pulse (drives dots + hint edge breathing).
  final double pulseValue;

  final String? hoveredEdge;
  final String? pressedEdge;
  final String? hintEdge;
  final String? opponentHighlightEdge;
  final Set<String> rewindFadeEdges;
  final Map<String, String> rewindFadeBoxes;
  final Map<String, String> rewindFadeOwnership;
  final double rewindFadeT;

  // ── Sizing constants ───────────────────────────────────────────────────────

  double get _dotR => layout.cellSize * 0.048;
  double get _edgeW => layout.cellSize * 0.052;

  // ── Paint entry point ──────────────────────────────────────────────────────

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawBoxFills(canvas);
    _drawInactiveEdges(canvas);
    _drawActiveEdges(canvas);
    _drawRewindFade(canvas);
    _drawDots(canvas);
    _drawBoxLabels(canvas);
  }

  // ── Board background ───────────────────────────────────────────────────────

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = visuals.scaffold,
    );
  }

  // ── Box fills ──────────────────────────────────────────────────────────────

  // Returns true if every adjacent box of an edge key is disabled.
  bool _isEdgeInDisabledRegion(String edgeKey) {
    final adjacent = GameRules.adjacentBoxes(state.rows, state.cols, edgeKey);
    if (adjacent.isEmpty) return false;
    return adjacent.every(
      (rc) => state.disabledCells.contains(GameRules.boxKey(rc.$1, rc.$2)),
    );
  }

  void _drawBoxFills(Canvas canvas) {
    // Draw a hatched "void" pattern over disabled cells
    if (state.disabledCells.isNotEmpty) {
      for (final bKey in state.disabledCells) {
        final parts = bKey.split('_');
        if (parts.length != 2) continue;
        final r = int.tryParse(parts[0]);
        final c = int.tryParse(parts[1]);
        if (r == null || c == null) continue;
        final tl = layout.dot(r, c);
        final br = layout.dot(r + 1, c + 1);
        canvas.drawRect(
          Rect.fromLTRB(tl.dx, tl.dy, br.dx, br.dy),
          Paint()..color = visuals.scaffold.withOpacity(0.7),
        );
      }
    }

    for (final entry in state.claimedBoxes.entries) {
      final bKey = entry.key;
      if (state.disabledCells.contains(bKey)) continue;
      final pid = entry.value;
      final parts = bKey.split('_');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);

      final tl = layout.dot(r, c);
      final br = layout.dot(r + 1, c + 1);
      final inset = layout.cellSize * 0.04;

      final base = Rect.fromLTRB(
          tl.dx + inset, tl.dy + inset, br.dx - inset, br.dy - inset);

      final rawT = claimProgress[bKey] ?? 1.0;
      final t = rawT.clamp(0.0, 1.0);

      // Scale in from centre
      final rect = Rect.fromCenter(
        center: base.center,
        width: base.width * t,
        height: base.height * t,
      );
      if (rect.isEmpty) continue;

      final col = visuals.playerColor(pid);
      final opacity = t;

      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              col.withOpacity(0.42 * opacity),
              col.withOpacity(0.18 * opacity),
            ],
          ).createShader(rect),
      );

    }
  }

  // ── Inactive (undrawn) edges ───────────────────────────────────────────────

  void _drawInactiveEdges(Canvas canvas) {
    _forEachInactiveEdge((key, p1, p2) {
      final isHint = key == hintEdge;
      final isHover = key == hoveredEdge;
      final isPress = key == pressedEdge;

      final pressColor = visuals.onAccent.withOpacity(0.55);
      final hoverColor = visuals.onAccent.withOpacity(0.32);

      if (isPress) {
        _strokeLine(canvas, p1, p2, pressColor,
            width: _edgeW, glow: true);
      } else if (isHint) {
        final pulse = 0.55 + pulseValue * 0.45;
        _strokeLine(canvas, p1, p2,
            visuals.gold.withOpacity(pulse),
            width: _edgeW * 0.9,
            glow: true);
      } else if (isHover) {
        _strokeLine(canvas, p1, p2, hoverColor,
            width: _edgeW * 0.75, glow: false);
      } else {
        _strokeLine(canvas, p1, p2, visuals.edgeInactive,
            width: 1.0, glow: false);
      }
    });
  }

  void _forEachInactiveEdge(
      void Function(String key, Offset p1, Offset p2) fn) {
    for (var r = 0; r < state.rows; r++) {
      for (var c = 0; c < state.cols - 1; c++) {
        final k = GameRules.hEdge(r, c);
        if (!state.drawnEdges.contains(k) && !_isEdgeInDisabledRegion(k)) {
          fn(k, layout.dot(r, c), layout.dot(r, c + 1));
        }
      }
    }
    for (var r = 0; r < state.rows - 1; r++) {
      for (var c = 0; c < state.cols; c++) {
        final k = GameRules.vEdge(r, c);
        if (!state.drawnEdges.contains(k) && !_isEdgeInDisabledRegion(k)) {
          fn(k, layout.dot(r, c), layout.dot(r + 1, c));
        }
      }
    }
  }

  // ── Active (drawn) edges ───────────────────────────────────────────────────

  void _drawActiveEdges(Canvas canvas) {
    for (final key in state.drawnEdges) {
      final (p1, p2) = layout.edgeEndpoints(key);
      final pid = ownership[key] ?? state.playerIds[0];
      final color = visuals.playerColor(pid);
      final progress = edgeProgress[key] ?? 1.0;
      final endpoint =
          progress >= 1.0 ? p2 : Offset.lerp(p1, p2, progress)!;

      _strokeLine(canvas, p1, endpoint, color, width: _edgeW, glow: false);

      if (key == opponentHighlightEdge) {
        final pulse = 0.55 + pulseValue * 0.45;
        _strokeLine(
          canvas,
          p1,
          endpoint,
          color.withOpacity(pulse),
          width: _edgeW * 1.45,
          glow: true,
        );
      }
    }
  }

  void _drawRewindFade(Canvas canvas) {
    if (rewindFadeT <= 0 ||
        (rewindFadeEdges.isEmpty && rewindFadeBoxes.isEmpty)) {
      return;
    }

    final tl = layout.dot(0, 0);
    final br = layout.dot(layout.rows - 1, layout.cols - 1);
    final pad = layout.cellSize * 0.22;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
            tl.dx - pad, tl.dy - pad, br.dx + pad, br.dy + pad),
        const Radius.circular(18),
      ),
      Paint()..color = visuals.red.withOpacity(0.12 * rewindFadeT),
    );

    for (final entry in rewindFadeBoxes.entries) {
      final parts = entry.key.split('_');
      if (parts.length != 2) continue;
      final r = int.tryParse(parts[0]);
      final c = int.tryParse(parts[1]);
      if (r == null || c == null) continue;

      final tlBox = layout.dot(r, c);
      final brBox = layout.dot(r + 1, c + 1);
      final inset = layout.cellSize * 0.04;
      final rect = Rect.fromLTRB(
        tlBox.dx + inset,
        tlBox.dy + inset,
        brBox.dx - inset,
        brBox.dy - inset,
      );
      final col = visuals.playerColor(entry.value);
      canvas.drawRect(
        rect,
        Paint()..color = col.withOpacity(0.55 * rewindFadeT),
      );
    }

    for (final key in rewindFadeEdges) {
      final (p1, p2) = layout.edgeEndpoints(key);
      final pid = rewindFadeOwnership[key] ?? state.playerIds[1];
      final color = Color.lerp(visuals.red, visuals.playerColor(pid), 0.35)!;
      _strokeLine(
        canvas,
        p1,
        p2,
        color.withOpacity(rewindFadeT),
        width: _edgeW * 1.1,
        glow: false,
      );
    }
  }

  // ── Dots ───────────────────────────────────────────────────────────────────

  void _drawDots(Canvas canvas) {
    final baseR = _dotR;
    final core = visuals.dotActive;

    for (var r = 0; r < state.rows; r++) {
      for (var c = 0; c < state.cols; c++) {
        final pos = layout.dot(r, c);

        if (visuals.useGlow) {
          final haloOpacity = 0.12 + pulseValue * 0.08;
          canvas.drawCircle(
            pos,
            baseR * 1.8,
            Paint()
              ..color = visuals.dotGlow.withOpacity(haloOpacity)
              ..maskFilter = MaskFilter.blur(BlurStyle.normal, baseR * 0.9),
          );
          canvas.drawCircle(pos, baseR, Paint()..color = core);
        } else {
          canvas.drawCircle(pos, baseR, Paint()..color = core);
        }
      }
    }
  }

  // ── Box labels (letter + crown) ────────────────────────────────────────────

  void _drawBoxLabels(Canvas canvas) {
    for (final entry in state.claimedBoxes.entries) {
      final bKey = entry.key;
      if (state.disabledCells.contains(bKey)) continue;
      final pid = entry.value;
      final parts = bKey.split('_');
      final r = int.parse(parts[0]);
      final c = int.parse(parts[1]);

      final rawT = claimProgress[bKey] ?? 1.0;
      // Fade in text only in the second half of the claim animation
      final textT = ((rawT - 0.45) / 0.55).clamp(0.0, 1.0);
      if (textT <= 0) continue;

      final col = visuals.playerColor(pid).withOpacity(textT);
      final center = Offset(
        layout.offsetX + (c + 0.5) * layout.cellSize,
        layout.offsetY + (r + 0.5) * layout.cellSize,
      );

      // Crown
      final crownSize = layout.cellSize * 0.17;
      _drawText(
        canvas,
        '♛',
        center.translate(0, -layout.cellSize * 0.16),
        TextStyle(
          fontSize: crownSize,
          color: col.withOpacity(textT * 0.55),
        ),
      );

      // Player letter
      _drawText(
        canvas,
        (playerInitials[pid] ?? (pid.isNotEmpty ? pid[0] : '?'))
            .toUpperCase(),
        center.translate(0, layout.cellSize * 0.05),
        TextStyle(
          fontSize: layout.cellSize * 0.35,
          fontWeight: FontWeight.w900,
          color: col,
        ),
      );
    }
  }

  void _drawText(Canvas canvas, String text, Offset center,
      TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas,
        center - Offset(tp.width / 2, tp.height / 2));
  }

  // ── Drawing primitives ─────────────────────────────────────────────────────

  /// Edge stroke. Glow reserved for hint / press feedback only.
  void _strokeLine(
    Canvas canvas,
    Offset p1,
    Offset p2,
    Color color, {
    required double width,
    bool glow = false,
  }) {
    if (glow && visuals.useGlow) {
      canvas.drawLine(
        p1,
        p2,
        Paint()
          ..color = color.withOpacity(0.35)
          ..strokeWidth = width + 4
          ..strokeCap = StrokeCap.round
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3),
      );
    }

    canvas.drawLine(
      p1,
      p2,
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  // ── shouldRepaint ──────────────────────────────────────────────────────────

  @override
  bool shouldRepaint(_BoardPainter old) =>
      old.pulseValue != pulseValue ||
      old.hoveredEdge != hoveredEdge ||
      old.pressedEdge != pressedEdge ||
      old.hintEdge != hintEdge ||
      old.opponentHighlightEdge != opponentHighlightEdge ||
      old.state != state ||
      old.visuals != visuals ||
      old.edgeProgress != edgeProgress ||
      old.claimProgress != claimProgress;
}
