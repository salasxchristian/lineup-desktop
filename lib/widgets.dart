import 'dart:async';

import 'package:flutter/material.dart';

import 'state.dart';
import 'theme.dart';
import 'xtream.dart';

/// The app state, from anywhere below the app. Rebuilds dependents when it changes.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

String clockTime(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')}';
}

String meridiem(DateTime t) => t.hour < 12 ? 'AM' : 'PM';

String fullTime(DateTime t) => '${clockTime(t)} ${meridiem(t)}';

String timeLeft(Duration d) {
  final m = d.inMinutes.clamp(0, 100000);
  if (m < 60) return '$m min left';
  final h = m ~/ 60, r = m % 60;
  return '$h hr${r > 0 ? ' $r min' : ''} left';
}

/// Rebuilds every few seconds with the current time, so progress and the now line move.
class Ticker extends StatefulWidget {
  const Ticker({super.key, required this.builder, this.every = const Duration(seconds: 15)});
  final Widget Function(BuildContext context, DateTime now) builder;
  final Duration every;

  @override
  State<Ticker> createState() => _TickerState();
}

class _TickerState extends State<Ticker> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.every, (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _now);
}

class Clock extends StatelessWidget {
  const Clock({super.key});

  @override
  Widget build(BuildContext context) => Ticker(
        builder: (context, now) => Text.rich(
          TextSpan(children: [
            TextSpan(text: '${clockTime(now)} '),
            TextSpan(text: meridiem(now), style: const TextStyle(color: Palette.dim, fontWeight: FontWeight.w500)),
          ]),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.15, fontFeatures: tabular),
        ),
      );
}

/// The red (or lilac, or blue) square with a dot: the app's mark.
/// The app's mark: the old school TV from the app icon (tool/make_icon.py), its body in the theme's accent.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return CustomPaint(size: Size.square(size), painter: _TvPainter(accent: p.accent, dark: p.bg));
  }
}

class _TvPainter extends CustomPainter {
  _TvPainter({required this.accent, required this.dark});
  final Color accent, dark;

  // The TV's bounds on the icon's 1024 grid: body edges left and right, ear tips to feet top to bottom.
  static const _left = 226.0, _top = 168.0, _w = 572.0, _h = 662.0;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.height / _h;
    canvas.save();
    canvas.translate((size.width - _w * k) / 2, 0);
    canvas.scale(k);
    canvas.translate(-_left, -_top);

    final shade = Color.lerp(accent, Colors.black, 0.25)!;
    const ears = Color(0xFFE6E7EA);
    RRect r(double l, double t, double w, double h, double rad) => RRect.fromLTRBR(l, t, l + w, t + h, Radius.circular(rad));

    final ear = Paint()
      ..color = ears
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    for (final tip in const [Offset(372, 212), Offset(660, 190)]) {
      canvas.drawLine(const Offset(512, 348), tip, ear);
      canvas.drawCircle(tip, 22, Paint()..color = ears);
    }
    canvas.drawOval(Rect.fromCenter(center: const Offset(512, 370), width: 132, height: 80), Paint()..color = shade);
    for (final x in const [296.0, 676.0]) {
      canvas.drawRRect(r(x, 768, 52, 62, 16), Paint()..color = shade);
    }
    canvas.drawRRect(r(226, 370, 572, 424, 92), Paint()..color = accent);
    canvas.drawRRect(r(262, 406, 380, 352, 76), Paint()..color = shade);
    final glass = Rect.fromLTWH(274, 418, 356, 328);
    canvas.drawRRect(
      RRect.fromRectAndRadius(glass, const Radius.circular(66)),
      Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2E36), Color(0xFF14161A)]).createShader(glass),
    );
    canvas.drawArc(
      Rect.fromLTWH(310, 450, 250, 258),
      192 * 3.14159265 / 180,
      66 * 3.14159265 / 180,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.27)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round,
    );
    final pointer = Paint()
      ..color = ears
      ..strokeWidth = 8;
    canvas.drawCircle(const Offset(716, 492), 40, Paint()..color = dark);
    canvas.drawLine(const Offset(716, 492), const Offset(716, 467), pointer);
    canvas.drawCircle(const Offset(716, 596), 30, Paint()..color = dark);
    canvas.drawLine(const Offset(716, 596), const Offset(729, 583), pointer);
    for (final y in const [670.0, 700.0, 730.0]) {
      canvas.drawRRect(r(684, y, 64, 12, 6), Paint()..color = shade);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TvPainter old) => old.accent != accent || old.dark != dark;
}

class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.glass});
  final Color? glass;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: glass ?? Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(6),
        border: glass != null ? Border.all(color: Colors.white.withValues(alpha: 0.06)) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        const Text('LIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: Palette.text)),
      ]),
    );
  }
}

/// Behind channel logos: a soft white, so it doesn't glare against the dark guide.
const logoTile = Color(0xFFF2F2F3);

/// A channel's logo, or its two letters on a tile tinted by category.
class ChannelLogo extends StatelessWidget {
  const ChannelLogo({super.key, required this.channel, this.size = 34});
  final Channel channel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (bg, ink) = tintFor(channel.categoryIds.isEmpty ? channel.name : channel.categoryIds.first);
    final radius = BorderRadius.circular(size * 0.26);
    final letters = Center(
      child: Text(channel.monogram,
          style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w700, color: ink, height: 1)),
    );
    // Letters on the category tint until a logo loads; a loaded logo sits on white, which is what
    // most broadcaster logos are drawn for.
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: bg, borderRadius: radius),
      clipBehavior: Clip.antiAlias,
      child: channel.icon == null
          ? letters
          : Stack(fit: StackFit.expand, children: [
              letters,
              Image.network(
                channel.icon!,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                cacheWidth: (size * 3).round(),
                frameBuilder: (context, child, frame, sync) => frame == null && !sync
                    ? const SizedBox.shrink()
                    : ColoredBox(
                        color: logoTile,
                        child: Padding(padding: EdgeInsets.all(size * 0.14), child: child),
                      ),
                errorBuilder: (context, _, _) => const SizedBox.shrink(),
              ),
            ]),
    );
  }
}

/// A round icon button (44 px) on the surface color, or on the primary color when [filled].
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.tooltip, required this.onPressed, this.filled = false, this.size = 44, this.background});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;
  final double size;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background ?? (filled ? p.primary : p.surface),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, size: size < 40 ? 16 : 19, color: filled ? p.onPrimary : Palette.text),
          ),
        ),
      ),
    );
  }
}

/// The main call to action: a white (or accent) pill.
class PrimaryPill extends StatelessWidget {
  const PrimaryPill({super.key, required this.label, required this.onPressed, this.icon, this.trailingIcon, this.height = 44, this.busy = false, this.expand = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final IconData? trailingIcon;
  final double height;
  final bool busy;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    final content = busy
        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.onPrimary))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: p.onPrimary), const SizedBox(width: 6)],
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: p.onPrimary)),
            if (trailingIcon != null) ...[const SizedBox(width: 8), Icon(trailingIcon, size: 17, color: p.onPrimary)],
          ]);
    return Material(
      color: p.primary,
      borderRadius: BorderRadius.circular(height / 2),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onPressed,
        child: Container(
          height: height,
          width: expand ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Center(widthFactor: expand ? null : 1, child: content),
        ),
      ),
    );
  }
}

/// A rounded "< Guide" style pill.
class BackPill extends StatelessWidget {
  const BackPill({super.key, required this.label, required this.onPressed, this.background});
  final String label;
  final VoidCallback onPressed;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Material(
      color: background ?? p.surface,
      shape: StadiumBorder(side: background != null ? BorderSide(color: Colors.white.withValues(alpha: 0.06)) : BorderSide.none),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          height: 40,
          padding: const EdgeInsets.only(left: 10, right: 16),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.chevron_left_rounded, size: 20, color: Palette.text),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

/// A thin progress bar.
class ThinProgress extends StatelessWidget {
  const ThinProgress({super.key, required this.value, required this.color, this.track = const Color(0x1FFFFFFF), this.height = 3});
  final double value;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(children: [
            Positioned.fill(child: ColoredBox(color: track)),
            FractionallySizedBox(widthFactor: value.clamp(0, 1), child: ColoredBox(color: color)),
          ]),
        ),
      );
}

/// A small outlined tag ("News", "HD").
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        height: 20,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(border: Border.all(color: Palette.outline), borderRadius: BorderRadius.circular(5)),
        child: Center(widthFactor: 1, child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Palette.muted))),
      );
}

/// A key cap for the keyboard hints.
class KeyCap extends StatelessWidget {
  const KeyCap(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        height: 20,
        constraints: const BoxConstraints(minWidth: 20),
        padding: const EdgeInsets.symmetric(horizontal: 5),
        decoration: BoxDecoration(border: Border.all(color: Palette.outline), borderRadius: BorderRadius.circular(5)),
        child: Center(widthFactor: 1, child: Text(text, style: const TextStyle(fontSize: 11, color: Palette.muted))),
      );
}

const eyebrow = TextStyle(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.9, color: Palette.dim);

/// Over the video: a spinner while it buffers, "Reconnecting" while a dropped stream is being reopened,
/// and a Try again button once reconnecting gives up. [compact] is for the guide preview and mini player.
class PlaybackStatus extends StatelessWidget {
  const PlaybackStatus({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final spinner = SizedBox(
      width: compact ? 22 : 28,
      height: compact ? 22 : 28,
      child: CircularProgressIndicator(strokeWidth: compact ? 2 : 2.5, color: Colors.white60),
    );
    final label = TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: compact ? 12 : 14, fontWeight: FontWeight.w500);
    if (state.playbackFailed) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Can’t play this channel right now.', style: label),
          SizedBox(height: compact ? 8 : 14),
          PrimaryPill(label: 'Try again', icon: Icons.refresh_rounded, height: compact ? 32 : 44, onPressed: state.retryPlayback),
        ]),
      );
    }
    if (state.reconnecting) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          spinner,
          SizedBox(height: compact ? 8 : 12),
          Text('Reconnecting', style: label),
        ]),
      );
    }
    return StreamBuilder<bool>(
      stream: state.player.stream.buffering,
      initialData: state.player.state.buffering,
      builder: (context, snap) => snap.data == true ? Center(child: spinner) : const SizedBox.shrink(),
    );
  }
}
