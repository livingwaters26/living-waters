import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../services/settings_service.dart';

/// The player screens' backlight - the colour every lit element on the deck
/// glows (knob arc and needle, the illuminated transport keys, and the glow
/// spilling out between the faceplate modules).
///
/// Held in a global ValueNotifier rather than passed down, because BOTH
/// player screens and every lit widget inside them need it and it can change
/// at any moment from the switch at the bottom of the screen - threading it
/// through every constructor would be a lot of plumbing for one colour.
/// Persisted by index via SettingsService so it survives app restarts.
class StereoBacklight {
  StereoBacklight._();

  /// Classic hi-fi backlight colours. Order matters - the stored setting is
  /// an index into this list (see SettingsService.getBacklightIndex).
  static const List<({String name, Color color})> presets = [
    (name: 'Ice Blue', color: Color(0xFF9FC9FF)),
    (name: 'Amber', color: Color(0xFFFFB74D)),
    (name: 'Green', color: Color(0xFF69F0AE)),
    (name: 'Red', color: Color(0xFFFF6E6E)),
    (name: 'Violet', color: Color(0xFFCE93D8)),
    (name: 'White', color: Color(0xFFE8E8EC)),
  ];

  static final ValueNotifier<int> indexNotifier = ValueNotifier<int>(0);

  static Color get color => presets[indexNotifier.value.clamp(0, presets.length - 1)].color;

  static bool _loaded = false;

  /// Reads the saved choice once per app run. Safe to call from every
  /// screen's initState - later calls are no-ops.
  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      indexNotifier.value = await SettingsService().getBacklightIndex();
    } catch (_) {
      // Non-critical - a missing/unreadable settings file just means the
      // default colour, never a broken screen.
    }
  }

  static Future<void> select(int index) async {
    indexNotifier.value = index.clamp(0, presets.length - 1);
    try {
      await SettingsService().setBacklightIndex(indexNotifier.value);
    } catch (_) {}
  }
}

/// Rebuilds [builder] whenever the backlight colour changes.
class BacklightBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, Color glow) builder;
  const BacklightBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: StereoBacklight.indexNotifier,
      builder: (context, _, __) => builder(context, StereoBacklight.color),
    );
  }
}

/// The light spilling out of the seam between two faceplate modules - a
/// narrow vertical bar of the backlight colour with a wide soft bloom, like
/// the glow leaking around a real component's edges.
class StereoSeamGlow extends StatelessWidget {
  final double width;
  const StereoSeamGlow({super.key, this.width = 26});

  @override
  Widget build(BuildContext context) {
    return BacklightBuilder(
      builder: (context, glow) => SizedBox(
        width: width,
        child: Center(
          child: Container(
            width: 3,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(2),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  glow.withOpacity(0.0),
                  glow.withOpacity(0.85),
                  glow.withOpacity(0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(color: glow.withOpacity(0.55), blurRadius: 18, spreadRadius: 1),
                BoxShadow(color: glow.withOpacity(0.28), blurRadius: 34, spreadRadius: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single lit bulb on the faceplate - tap it and the colour list drops
/// down. The always-visible row of six dots this replaces took up a chunk
/// of the panel to expose a setting that gets changed once and then left
/// alone; a bulb that glows in the current colour says the same thing in
/// one glyph and keeps the choices one tap away.
class StereoBacklightSwitch extends StatelessWidget {
  const StereoBacklightSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<int>(
      valueListenable: StereoBacklight.indexNotifier,
      builder: (context, selected, _) {
        final glow = StereoBacklight.color;
        return PopupMenuButton<int>(
          tooltip: 'Backlight colour',
          onSelected: StereoBacklight.select,
          position: PopupMenuPosition.under,
          itemBuilder: (context) => [
            for (var i = 0; i < StereoBacklight.presets.length; i++)
              PopupMenuItem<int>(
                value: i,
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: StereoBacklight.presets[i].color,
                        boxShadow: [
                          BoxShadow(
                            color: StereoBacklight.presets[i].color.withOpacity(0.75),
                            blurRadius: 9,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(StereoBacklight.presets[i].name),
                    if (i == selected) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    ],
                  ],
                ),
              ),
          ],
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.lerp(theme.colorScheme.surface, Colors.black, 0.3),
              border: Border.all(color: glow.withOpacity(0.7), width: 1.4),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 6, offset: const Offset(0, 3)),
                BoxShadow(color: glow.withOpacity(0.45), blurRadius: 14, spreadRadius: -2),
              ],
            ),
            child: Icon(Icons.lightbulb, size: 24, color: glow),
          ),
        );
      },
    );
  }
}

/// Shared "stereo faceplate" visual language (round 33).
///
/// Both player screens (the MP3 player and the Read Scripture TTS player)
/// paint their controls the same way: dark keys with a machined bevel,
/// mounted on a lighter brushed-metal panel that catches light along its top
/// edge. Before this, each screen carried its own private copy of the button
/// helper and there was no panel at all, so the two drifted apart and the
/// screens read as flat dark app UI rather than a physical deck.
///
/// This file holds ONLY the look. It deliberately does not decide which
/// buttons a screen has - the MP3 player's 15-second REVERSE/FORWARD keys
/// and its caption-nudge module have no meaning on the TTS screen (which
/// moves a whole verse at a time and generates its own timing), so those
/// stay where they belong.

/// A real woven carbon-fibre faceplate.
///
/// The weave is painted ONCE into a small tile image and then repeated
/// across the panel with an ImageShader. Drawing the individual cells every
/// frame would mean thousands of draw calls on a surface that rebuilds
/// constantly (the player position stream ticks several times a second), so
/// the tile is built lazily and cached for the life of the app.
class _CarbonTile {
  static ui.Image? _image;

  /// One 16x16 patch: a 2x2 arrangement of 8px cells, each hatched with fine
  /// diagonal strands, with the diagonal flipping per cell. That alternation
  /// is what reads as an over/under weave rather than plain hatching.
  static ui.Image get image {
    final cached = _image;
    if (cached != null) return cached;

    const cell = 8.0;
    const size = cell * 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, size, size));

    const base = Color(0xFF17171A);
    const lighter = Color(0xFF232329);
    const strand = Color(0xFF34343C);

    canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), Paint()..color = base);

    for (var cx = 0; cx < 2; cx++) {
      for (var cy = 0; cy < 2; cy++) {
        final left = cx * cell;
        final top = cy * cell;
        final rect = Rect.fromLTWH(left, top, cell, cell);
        // Alternating cells sit slightly proud, like the tow passing over.
        final overUnder = (cx + cy) % 2 == 0;
        canvas.drawRect(rect, Paint()..color = overUnder ? lighter : base);

        canvas.save();
        canvas.clipRect(rect);
        final strandPaint = Paint()
          ..color = strand.withOpacity(overUnder ? 0.85 : 0.45)
          ..strokeWidth = 1.1;
        // +45 degrees on the "over" cells, -45 on the "under" ones.
        for (var o = -cell; o < cell * 2; o += 2.6) {
          if (overUnder) {
            canvas.drawLine(Offset(left + o, top), Offset(left + o + cell, top + cell), strandPaint);
          } else {
            canvas.drawLine(Offset(left + o, top + cell), Offset(left + o + cell, top), strandPaint);
          }
        }
        canvas.restore();
      }
    }

    final img = recorder.endRecording().toImageSync(size.toInt(), size.toInt());
    _image = img;
    return img;
  }
}

class _CarbonPainter extends CustomPainter {
  final Color sheen;
  const _CarbonPainter(this.sheen);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ImageShader(
          _CarbonTile.image,
          TileMode.repeated,
          TileMode.repeated,
          Matrix4.identity().storage,
        ),
    );
    // Lit top edge / darker bottom, so the plate still catches light the way
    // the brushed version did - carbon panels aren't flat matte either.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            sheen.withOpacity(0.16),
            sheen.withOpacity(0.03),
            Colors.black.withOpacity(0.28),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _CarbonPainter oldDelegate) => oldDelegate.sheen != sheen;
}

/// A carbon-fibre faceplate panel - the surface every control on the player
/// screens is mounted on. Replaces the plain brushed-gradient [stereoPanel]
/// decoration at the call sites that want real texture.
class CarbonPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  const CarbonPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(0.13)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: CustomPaint(
        painter: const _CarbonPainter(Colors.white),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// The brushed faceplate the controls sit on: a light-to-dark vertical
/// gradient with a lit top edge and a drop shadow. Kept for anywhere that
/// wants the plain plate rather than the carbon weave (e.g. small trim
/// pieces where a texture would just look noisy).
BoxDecoration stereoPanel(ThemeData theme) {
  final base = Color.lerp(theme.colorScheme.surfaceContainerHighest, Colors.white, 0.06)!;
  return BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(base, Colors.white, 0.14)!,
        base,
        Color.lerp(base, Colors.black, 0.22)!,
      ],
      stops: const [0.0, 0.45, 1.0],
    ),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: Color.lerp(base, Colors.white, 0.16)!),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 12, offset: const Offset(0, 4)),
    ],
  );
}

/// A dark recessed area sitting ON the faceplate - used for sub-modules
/// (like the caption-nudge box) that should read as a separate component
/// slotted into the deck rather than being flush with the panel.
BoxDecoration stereoInset(ThemeData theme) {
  return BoxDecoration(
    color: Color.lerp(theme.colorScheme.surface, Colors.black, 0.35)!,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.black.withOpacity(0.55)),
  );
}

/// A dark BACKLIT rectangular key - filled (not merely outlined, which reads
/// as a hole cut in the faceplate) with a glowing accent edge and a soft
/// outer bloom.
BoxDecoration stereoLitKey(ThemeData theme, {required bool enabled}) {
  final glow = StereoBacklight.color;
  final face = Color.lerp(theme.colorScheme.surface, Colors.black, 0.35)!;
  return BoxDecoration(
    // Bevelled like the round keys rather than a flat fill: a top-lit
    // vertical gradient across the face plus the glowing edge is what makes
    // these read as raised keys you could press, not lit rectangles printed
    // on the panel.
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(face, Colors.white, 0.16)!,
        face,
        Color.lerp(face, Colors.black, 0.35)!,
      ],
      stops: const [0.0, 0.5, 1.0],
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: enabled ? glow.withOpacity(0.85) : theme.colorScheme.onSurface.withOpacity(0.12),
      width: enabled ? 1.6 : 1,
    ),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 6, offset: const Offset(0, 3)),
      if (enabled) BoxShadow(color: glow.withOpacity(0.35), blurRadius: 12, spreadRadius: -2),
    ],
  );
}

/// A bevelled round transport key with a label underneath.
///
/// The bevel is what makes it read as pressable rather than as an icon
/// printed on the panel: a dark moulded surround around the cap, a top-lit
/// vertical gradient across the cap face, a bright hairline along its upper
/// edge, and a hard drop shadow beneath.
///
/// [onPressed] null disables the key AND desaturates the cap, so a disabled
/// button doesn't look active.
Widget stereoKey({
  required ThemeData theme,
  required IconData icon,
  required String label,
  required VoidCallback? onPressed,
  required Color background,
  required Color foreground,
  double size = 84,
  double iconSize = 34,
  Widget? iconOverride,
  /// Optional small glyph shown beside the label underneath - used to hint
  /// at a secondary effect (e.g. a mic beside PAUSE, since pausing also
  /// starts recording a note) WITHOUT cramming two icons onto the cap face,
  /// which looked cluttered.
  IconData? labelIcon,
}) {
  final enabled = onPressed != null;
  final cap = enabled ? background : Color.lerp(background, theme.colorScheme.surface, 0.6)!;
  final fg = enabled ? foreground : theme.disabledColor;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(cap, Colors.black, 0.55),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.55), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.055),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(cap, Colors.white, 0.26)!,
                  cap,
                  Color.lerp(cap, Colors.black, 0.32)!,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              border: Border.all(color: Colors.white.withOpacity(enabled ? 0.20 : 0.07)),
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onPressed,
                child: Center(
                  child: IconTheme(
                    data: IconThemeData(size: iconSize, color: fg),
                    child: iconOverride ?? Icon(icon),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (labelIcon != null) ...[
            const SizedBox(width: 4),
            Icon(labelIcon, size: 15, color: theme.colorScheme.onSurface.withOpacity(0.7)),
          ],
        ],
      ),
    ],
  );
}
