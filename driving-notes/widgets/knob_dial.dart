import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A rotary "knob" control for picking one value out of an ordered list -
/// tap or drag anywhere on the dial and it snaps to the nearest value,
/// like a real volume/tone knob. Sweeps 270 degrees (lower-left, up over
/// the top, to lower-right) with a gap at the bottom so there's an obvious
/// start/end stop, with tick marks and numbers printed around the rim and
/// the current value shown big in the middle.
///
/// Deliberately snap-to-nearest-tick rather than free/continuous rotation -
/// simpler to reason about (and to build without being able to preview it
/// live), and it matches how the rest of the app already picks from a
/// fixed step list (see the old speed Slider this replaces).
class KnobDial extends StatelessWidget {
  final List<double> values;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  /// Short text for the rim tick marks (a subset is shown, not one per
  /// value, to avoid clutter on longer lists).
  final String Function(double value) labelForTick;
  /// Text for the big readout in the middle of the dial.
  final String Function(double value) labelForCenter;
  final double size;
  final Color? accentColor;

  const KnobDial({
    super.key,
    required this.values,
    required this.selectedIndex,
    required this.onChanged,
    required this.labelForTick,
    required this.labelForCenter,
    this.size = 172,
    this.accentColor,
  });

  static const double _minAngle = -3 * math.pi / 4; // -135°, lower-left
  static const double _maxAngle = 3 * math.pi / 4; // +135°, lower-right

  double _angleForIndex(int index) {
    if (values.length <= 1) return 0;
    final fraction = index / (values.length - 1);
    return _minAngle + (_maxAngle - _minAngle) * fraction;
  }

  void _handleTouch(Offset localPosition) {
    final center = Offset(size / 2, size / 2);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;
    if (dx == 0 && dy == 0) return;
    // atan2(dx, -dy) gives an angle where 0 = straight up and positive =
    // clockwise, matching the point-placement formula in the painter below
    // - see its comment for the derivation. Values outside the dial's
    // sweep (i.e. the gap at the bottom) clamp to whichever end is nearer,
    // which feels like a natural hard stop instead of jumping around.
    final angle = math.atan2(dx, -dy).clamp(_minAngle, _maxAngle);
    final fraction = (angle - _minAngle) / (_maxAngle - _minAngle);
    final index = (fraction * (values.length - 1)).round().clamp(0, values.length - 1);
    if (index != selectedIndex) onChanged(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = accentColor ?? theme.colorScheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _handleTouch(d.localPosition),
        onPanStart: (d) => _handleTouch(d.localPosition),
        onPanUpdate: (d) => _handleTouch(d.localPosition),
        child: CustomPaint(
          painter: _KnobPainter(
            values: values,
            selectedIndex: selectedIndex,
            selectedAngle: _angleForIndex(selectedIndex),
            minAngle: _minAngle,
            maxAngle: _maxAngle,
            trackColor: theme.colorScheme.outlineVariant,
            knobColor: theme.colorScheme.surfaceContainerHighest,
            accentColor: accent,
            tickLabelColor: theme.colorScheme.onSurface.withOpacity(0.65),
            labelForTick: labelForTick,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              // Big and bright: the knob face beneath it is deliberately
              // near-black (see the painter), so full-strength white reads
              // crisply here rather than washing into a lit grey face the
              // way it did when the face was lighter. Scaled off `size` so
              // it stays proportional on a smaller dial.
              child: Text(
                labelForCenter(values[selectedIndex]),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: size * 0.145,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  shadows: [
                    Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 5, offset: const Offset(0, 1)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  final List<double> values;
  final int selectedIndex;
  final double selectedAngle;
  final double minAngle;
  final double maxAngle;
  final Color trackColor;
  final Color knobColor;
  final Color accentColor;
  final Color tickLabelColor;
  final String Function(double value) labelForTick;

  _KnobPainter({
    required this.values,
    required this.selectedIndex,
    required this.selectedAngle,
    required this.minAngle,
    required this.maxAngle,
    required this.trackColor,
    required this.knobColor,
    required this.accentColor,
    required this.tickLabelColor,
    required this.labelForTick,
  });

  /// A point at [radius] from [center], at knob-angle [angle] where 0 is
  /// straight up and positive angles go clockwise. Used for every tick,
  /// label and the needle, so they all stay in agreement with each other
  /// and with the gesture-handling math in KnobDial._handleTouch.
  Offset _pointAt(Offset center, double radius, double angle) {
    return Offset(center.dx + radius * math.sin(angle), center.dy - radius * math.cos(angle));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final knobRadius = r * 0.60;
    final arcRadius = r * 0.755;
    final tickInner = r * 0.685;
    final tickOuter = r * 0.775;
    final labelRadius = r * 0.92;

    // Round 33 (second pass): a real stereo knob reads as a MACHINED METAL
    // PART sitting on a panel, which needs more than one gradient - the
    // layers below, outside-in, are: a wide soft drop shadow on the panel; a
    // dark recessed well the knob sits in; a swept metallic bezel ring (a
    // SweepGradient, so the "brushed" ring catches light at the top-left and
    // goes dark at the bottom-right like real turned aluminium); the knob
    // face itself as an off-center radial gradient lit from the upper left;
    // a blurred elliptical gloss across the top of the face; and a bright
    // rim highlight arc along the lit edge. First pass had only a single
    // face gradient and a flat darker ring, which still read as "a painted
    // circle" rather than a physical object.

    // 1. Panel shadow - wide and soft, offset down, so the knob looks like
    //    it's standing off the surface rather than printed onto it.
    canvas.drawCircle(
      center.translate(0, knobRadius * 0.10),
      knobRadius * 1.12,
      Paint()
        ..color = Colors.black.withOpacity(0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, knobRadius * 0.22),
    );

    // 2. Metallic bezel ring, swept so it's lit top-left / dark bottom-right.
    final bezelRect = Rect.fromCircle(center: center, radius: knobRadius * 1.12);
    canvas.drawCircle(
      center,
      knobRadius * 1.12,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi * 2,
          transform: const GradientRotation(-math.pi * 0.75),
          colors: [
            Color.lerp(knobColor, Colors.white, 0.30)!,
            Color.lerp(knobColor, Colors.black, 0.55)!,
            Color.lerp(knobColor, Colors.white, 0.16)!,
            Color.lerp(knobColor, Colors.black, 0.60)!,
            Color.lerp(knobColor, Colors.white, 0.30)!,
          ],
          stops: const [0.0, 0.28, 0.52, 0.78, 1.0],
        ).createShader(bezelRect),
    );

    // 3. Knob face - radial gradient lit from the upper left, and kept DARK
    //    on purpose. An earlier pass had a mid-grey face, which forced the
    //    white centre readout and tick marks to compete with it and made
    //    them look soft; a near-black face lets both read crisply, and it's
    //    what a real machined knob looks like anyway.
    final faceRect = Rect.fromCircle(center: center, radius: knobRadius);
    canvas.drawCircle(
      center,
      knobRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.55),
          radius: 1.25,
          colors: [
            Color.lerp(knobColor, Colors.white, 0.16)!,
            Color.lerp(knobColor, Colors.black, 0.38)!,
            Color.lerp(knobColor, Colors.black, 0.74)!,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(faceRect),
    );

    // 4 & 5. Gloss across the top of the face, then a bright rim highlight
    //        along the lit (upper-left) edge - both clipped to the face.
    canvas.save();
    canvas.clipPath(Path()..addOval(faceRect));
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-knobRadius * 0.22, -knobRadius * 0.52),
        width: knobRadius * 1.35,
        height: knobRadius * 0.75,
      ),
      Paint()
        // Very subtle - the face is deliberately dark so the centre readout
        // stays crisp, and a strong gloss would undo exactly that.
        ..color = Colors.white.withOpacity(0.07)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, knobRadius * 0.30),
    );
    canvas.drawArc(
      faceRect.deflate(1),
      -math.pi * 0.95,
      math.pi * 0.75,
      false,
      Paint()
        ..color = Colors.white.withOpacity(0.38)
        ..style = PaintingStyle.stroke
        ..strokeWidth = knobRadius * 0.055
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, knobRadius * 0.035),
    );
    canvas.restore();

    // 6. Value arc around the rim - a dark recessed track across the full
    //    sweep with a bright accent arc filled in up to the current value.
    //    This is the "lit indicator ring" a real stereo knob has, and the
    //    single biggest thing the flat version was missing.
    final arcRect = Rect.fromCircle(center: center, radius: arcRadius);
    final arcStart = minAngle - math.pi / 2; // canvas 0 = 3 o'clock, ours = 12
    canvas.drawArc(
      arcRect,
      arcStart,
      maxAngle - minAngle,
      false,
      Paint()
        ..color = Colors.black.withOpacity(0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.055
        ..strokeCap = StrokeCap.round,
    );
    // The lit part of the ring is a SHORT segment centred on the current
    // value, not a fill running all the way back to the minimum - a fill
    // reads as a progress bar (and floods most of the dial in blue), while
    // a short lit arc reads as the indicator band on a real stereo knob,
    // which is what the reference design shows.
    const arcHalfSpan = math.pi / 9; // 20 degrees either side
    var lit = selectedAngle - arcHalfSpan;
    var litSweep = arcHalfSpan * 2;
    if (lit < minAngle) {
      litSweep -= minAngle - lit;
      lit = minAngle;
    }
    if (lit + litSweep > maxAngle) litSweep = maxAngle - lit;
    canvas.drawArc(
      arcRect,
      lit - math.pi / 2,
      litSweep,
      false,
      Paint()
        ..color = accentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.055
        ..strokeCap = StrokeCap.round,
    );

    for (var i = 0; i < values.length; i++) {
      final fraction = values.length <= 1 ? 0.0 : i / (values.length - 1);
      final angle = minAngle + (maxAngle - minAngle) * fraction;
      final isSelected = i == selectedIndex;
      final tickPaint = Paint()
        ..color = isSelected ? accentColor : Colors.white.withOpacity(0.62)
        ..strokeWidth = isSelected ? 3.5 : 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(_pointAt(center, tickInner, angle), _pointAt(center, tickOuter, angle), tickPaint);
    }

    // Print numbers at a handful of evenly-spaced ticks (always including
    // the first and last) rather than every one, so a long list of values
    // doesn't turn into an unreadable ring of overlapping text. Round 31:
    // the CURRENTLY SELECTED value is always added to that set too, even
    // if it doesn't land on one of the even-spacing sample points - before
    // this, the number you were actually on (e.g. the 1.00x default) could
    // be missing from the rim entirely, which read as confusing/"crude".
    // That label is drawn bigger and in the accent color so it's obvious
    // at a glance which tick you're on.
    final labelCount = math.min(values.length, 7);
    final labelIndices = <int>{};
    for (var l = 0; l < labelCount; l++) {
      labelIndices.add(labelCount <= 1 ? 0 : (l * (values.length - 1) / (labelCount - 1)).round());
    }
    labelIndices.add(selectedIndex);
    for (final valueIndex in labelIndices) {
      final fraction = values.length <= 1 ? 0.0 : valueIndex / (values.length - 1);
      final angle = minAngle + (maxAngle - minAngle) * fraction;
      final pos = _pointAt(center, labelRadius, angle);
      final isSelectedLabel = valueIndex == selectedIndex;
      final tp = TextPainter(
        text: TextSpan(
          text: labelForTick(values[valueIndex]),
          style: TextStyle(
            fontSize: isSelectedLabel ? 12.5 : 11,
            color: isSelectedLabel ? accentColor : Colors.white.withOpacity(0.80),
            fontWeight: isSelectedLabel ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }

    // Needle thickened from the first pass (was 3/4px hub) so it's easier
    // to read the pointed-at angle at a glance, especially at a distance.
    final needlePaint = Paint()
      ..color = accentColor
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center, _pointAt(center, knobRadius * 0.82, selectedAngle), needlePaint);
    canvas.drawCircle(center, 5.5, Paint()..color = accentColor);
  }

  @override
  bool shouldRepaint(covariant _KnobPainter oldDelegate) {
    return oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.values != values ||
        oldDelegate.accentColor != accentColor;
  }
}
