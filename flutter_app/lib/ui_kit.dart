import 'dart:math';
import 'package:flutter/material.dart';
import 'theme.dart';

/// The signature motif: a speech-shaped amplitude envelope. Deterministic so
/// it's stable across rebuilds. These are stylised syllable clusters with
/// breath gaps — not decoded MP3 amplitudes — which is honest for a preview,
/// while the playhead below tracks the *real* playback position.
final List<double> kEnvelope = _buildEnvelope();

List<double> _buildEnvelope() {
  const words = [4, 5, 3, 6, 2, 5, 4, 3, 6, 5, 4, 2, 5, 3, 4, 6, 3, 5, 4, 3];
  final rnd = Random(7);
  final out = <double>[];
  for (final n in words) {
    for (var i = 0; i < n; i++) {
      final body =
          0.35 + 0.6 * sin((i + 1) / (n + 1) * pi); // rise/fall in a word
      out.add((body * (0.72 + 0.28 * rnd.nextDouble())).clamp(0.08, 1.0));
    }
    out.add(0.07); // breath gap
    out.add(0.06);
  }
  return out;
}

bool _reduceMotion(BuildContext context) =>
    MediaQuery.of(context).disableAnimations;

/// Playback waveform: bars split at the playhead, tap-to-seek.
class Waveform extends StatelessWidget {
  const Waveform({
    super.key,
    required this.fraction,
    this.onSeek,
    this.height = 82,
    this.playedColor = AppColors.azure,
    this.restColor = const Color(0xFF3A5A60),
    this.playhead = AppColors.paper0,
  });

  final double fraction; // 0..1 played
  final ValueChanged<double>? onSeek;
  final double height;
  final Color playedColor;
  final Color restColor;
  final Color playhead;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      const minBarWidth = 2.0;
      const gap = 2.0;
      final availableWidth = c.maxWidth.isFinite ? c.maxWidth : 320.0;
      // A fixed bar count overflows on narrow phones. Downsample the visual
      // envelope while preserving the full playback fraction for seeking.
      final maxBars =
          max(1, ((availableWidth + gap) / (minBarWidth + gap)).floor())
              .toInt();
      final barCount = min(kEnvelope.length, maxBars).toInt();
      final barWidth =
          max(1.0, (availableWidth - gap * (barCount - 1)) / barCount)
              .toDouble();
      final headIndex = (fraction.clamp(0, 1) * barCount).floor();
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: onSeek == null
            ? null
            : (d) => onSeek!((d.localPosition.dx / availableWidth).clamp(0, 1)),
        onHorizontalDragUpdate: onSeek == null
            ? null
            : (d) => onSeek!((d.localPosition.dx / availableWidth).clamp(0, 1)),
        child: SizedBox(
          width: availableWidth,
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < barCount; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Builder(builder: (context) {
                  final sourceIndex = barCount == 1
                      ? 0
                      : (i * (kEnvelope.length - 1) / (barCount - 1)).round();
                  return Container(
                    width: barWidth,
                    height: max(3, kEnvelope[sourceIndex] * (height - 10)),
                    decoration: BoxDecoration(
                      color: i == headIndex
                          ? playhead
                          : (i < headIndex ? playedColor : restColor),
                      borderRadius: BorderRadius.circular(barWidth),
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      );
    });
  }
}

/// A static mini version of the motif — voice-card previews, script underline.
class MiniWave extends StatelessWidget {
  const MiniWave({
    super.key,
    required this.color,
    this.bars = 6,
    this.height = 22,
    this.seed = 3,
  });

  final Color color;
  final int bars;
  final double height;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final rnd = Random(seed);
    return SizedBox(
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < bars; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.2),
              child: Container(
                width: 2.6,
                height: (0.35 + 0.65 * rnd.nextDouble()) * height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The animated ribbon — the app "listening" (intake) or "recording" (generating).
/// Same DNA as the waveform. Honours reduced-motion.
class Ribbon extends StatefulWidget {
  const Ribbon({
    super.key,
    this.color = AppColors.azure,
    this.bars = 5,
    this.barWidth = 3,
    this.maxHeight = 18,
    this.glow = false,
  });

  final Color color;
  final int bars;
  final double barWidth;
  final double maxHeight;
  final bool glow;

  @override
  State<Ribbon> createState() => _RibbonState();
}

class _RibbonState extends State<Ribbon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion(context);
    return SizedBox(
      height: widget.maxHeight,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.bars; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1.5),
                  child: _bar(i, reduce),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _bar(int i, bool reduce) {
    final phase = i / widget.bars;
    final t = reduce ? 0.5 : (0.5 + 0.5 * sin((_c.value + phase) * 2 * pi));
    final h = (0.28 + 0.72 * t) * widget.maxHeight;
    return Container(
      width: widget.barWidth,
      height: h,
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(widget.barWidth),
        boxShadow: widget.glow
            ? [
                BoxShadow(
                    color: widget.color.withValues(alpha: 0.6), blurRadius: 14)
              ]
            : null,
      ),
    );
  }
}

/// Step header: back affordance + 3-segment progress + step label.
class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.step, // 1..3
    this.onBack,
    this.dark = false,
  });

  final int step;
  final VoidCallback? onBack;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          if (onBack != null) ...[
            _BackButton(onTap: onBack!, dark: dark),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Row(
              children: [
                for (var i = 1; i <= 3; i++) ...[
                  if (i > 1) const SizedBox(width: 5),
                  Expanded(
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: i == step
                            ? AppColors.azure
                            : i < step
                                ? AppColors.teal
                                : (dark
                                    ? AppColors.studioLine
                                    : AppColors.line),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text('Step $step / 3',
              style:
                  micro(color: dark ? AppColors.studioMeta : AppColors.ink400)),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap, required this.dark});
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: dark ? AppColors.studio1 : AppColors.paper1,
            border:
                Border.all(color: dark ? AppColors.studioLine : AppColors.line),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(Icons.arrow_back_ios_new,
              size: 14, color: dark ? AppColors.paper0 : AppColors.ink800),
        ),
      ),
    );
  }
}

/// One of the four contract fields. Status is never colour-only: captured =
/// sage fill + check icon + darker label.
class FieldChip extends StatelessWidget {
  const FieldChip({super.key, required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
      decoration: BoxDecoration(
        color: done ? AppColors.sageSoft : AppColors.paper1,
        border: Border.all(
          color: done ? AppColors.sage : AppColors.line,
          style: done ? BorderStyle.solid : BorderStyle.solid,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? AppColors.sage : Colors.transparent,
              border:
                  done ? null : Border.all(color: AppColors.ink400, width: 1.5),
            ),
            child: done
                ? const Icon(Icons.check, size: 10, color: AppColors.paper0)
                : null,
          ),
          const SizedBox(width: 6),
          Text(label,
              style: sans(
                  size: 11,
                  weight: FontWeight.w600,
                  color: done ? AppColors.ink800 : AppColors.ink400,
                  height: 1)),
        ],
      ),
    );
  }
}

/// Primary CTA — the one azure decision per screen.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: AppColors.azure,
        borderRadius: BorderRadius.circular(16),
        elevation: 0,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          focusColor: AppColors.ink950.withValues(alpha: 0.12),
          child: Container(
            height: 54,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: enabled
                  ? [
                      BoxShadow(
                        color: AppColors.azure.withValues(alpha: 0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      )
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: AppColors.ink950))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label,
                          style: sans(
                              size: 15.5,
                              weight: FontWeight.w600,
                              color: AppColors.ink950)),
                      if (icon != null) ...[
                        const SizedBox(width: 9),
                        Icon(icon, size: 18, color: AppColors.ink950),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Secondary / ghost action.
class GhostButton extends StatelessWidget {
  const GhostButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.paper1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 50,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label,
              style: sans(
                  size: 15, weight: FontWeight.w600, color: AppColors.ink800)),
        ),
      ),
    );
  }
}
