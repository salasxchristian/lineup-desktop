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
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 22});
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(size * 0.28)),
      alignment: Alignment.center,
      child: Container(
        width: size * 0.27,
        height: size * 0.27,
        decoration: BoxDecoration(color: p.bg, shape: BoxShape.circle),
      ),
    );
  }
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
            child: Icon(icon, size: 19, color: filled ? p.onPrimary : Palette.text),
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
