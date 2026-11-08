import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../theme.dart';
import '../widgets.dart';

/// Full screen video with a panel that fades out after a few seconds without the mouse or keys.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _chrome = true;
  bool _fullScreen = false;
  bool _muted = false;
  Timer? _hide;
  final _focus = FocusNode(debugLabel: 'player');

  @override
  void initState() {
    super.initState();
    _poke();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _focus.dispose();
    if (_fullScreen) windowManager.setFullScreen(false);
    super.dispose();
  }

  Future<void> _setFullScreen(bool on) async {
    try {
      await windowManager.setFullScreen(on);
      if (mounted) setState(() => _fullScreen = on);
    } catch (_) {}
  }

  void _poke() {
    _hide?.cancel();
    if (!_chrome) setState(() => _chrome = true);
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _chrome = false);
    });
  }

  void _back() => Navigator.of(context).maybePop();

  void _toggleMute() {
    final state = AppScope.read(context);
    setState(() => _muted = !_muted);
    state.player.setVolume(_muted ? 0 : 100);
    _poke();
  }

  void _step(int delta) {
    final state = AppScope.read(context);
    state.step(delta, playNow: true);
    if (!_muted) state.player.setVolume(100);
    _poke();
  }

  Future<void> _mini() async {
    final state = AppScope.read(context);
    if (_fullScreen) setState(() => _fullScreen = false);
    await state.enterMini();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.channelUp:
        _step(-1);
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.channelDown:
        _step(1);
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.backspace:
      case LogicalKeyboardKey.goBack:
        _back();
      case LogicalKeyboardKey.keyF:
        _setFullScreen(!_fullScreen);
        _poke();
      case LogicalKeyboardKey.keyM:
        _toggleMute();
      case LogicalKeyboardKey.keyP:
        _mini();
      default:
        _poke();
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = PaletteScope.of(context);
    final ch = state.channelById(state.playingId) ?? state.selected;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: MouseRegion(
          cursor: _chrome ? SystemMouseCursors.basic : SystemMouseCursors.none,
          onHover: (_) => _poke(),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _poke,
            onDoubleTap: () => _setFullScreen(!_fullScreen),
            child: Stack(fit: StackFit.expand, children: [
              Video(controller: state.video, controls: NoVideoControls, fill: Colors.black),
              const PlaybackStatus(),
              AnimatedOpacity(
                opacity: _chrome ? 1 : 0,
                duration: const Duration(milliseconds: 220),
                child: IgnorePointer(
                  ignoring: !_chrome,
                  child: Stack(children: [
                    Positioned(
                      top: 28,
                      left: 32,
                      right: 32,
                      child: Row(children: [
                        BackPill(label: 'Guide', onPressed: _back, background: p.glass),
                        const Spacer(),
                        LiveBadge(glass: p.glass),
                        const SizedBox(width: 10),
                        const Clock(),
                      ]),
                    ),
                    if (ch != null)
                      Positioned(
                        left: 32,
                        right: 32,
                        bottom: 32,
                        child: Center(child: _Panel(
                          muted: _muted,
                          fullScreen: _fullScreen,
                          onUp: () => _step(-1),
                          onDown: () => _step(1),
                          onMute: _toggleMute,
                          onMini: _mini,
                          onFullScreen: () => _setFullScreen(!_fullScreen),
                        )),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.muted,
    required this.fullScreen,
    required this.onUp,
    required this.onDown,
    required this.onMute,
    required this.onMini,
    required this.onFullScreen,
  });
  final bool muted, fullScreen;
  final VoidCallback onUp, onDown, onMute, onMini, onFullScreen;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = PaletteScope.of(context);
    final ch = state.channelById(state.playingId) ?? state.selected!;
    state.ensureEpg(ch.id);
    return Ticker(builder: (context, now) {
      final (cur, next) = state.nowNext(ch.id, now);
      final fav = state.favorites.contains(ch.id);
      return Container(
        constraints: const BoxConstraints(maxWidth: 920),
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
        decoration: BoxDecoration(
          color: p.glass,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 48, offset: Offset(0, 24))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            ChannelLogo(channel: ch, size: 48),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text([if (ch.number != null) ch.number!, ch.name].join(' | '),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Palette.muted, fontFeatures: tabular)),
                const SizedBox(height: 4),
                Text(cur?.title.isNotEmpty == true ? cur!.title : ch.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.65, height: 1.1)),
              ]),
            ),
            const SizedBox(width: 16),
            RoundIconButton(icon: Icons.keyboard_arrow_up_rounded, tooltip: 'Previous channel  ↑', onPressed: onUp),
            const SizedBox(width: 8),
            RoundIconButton(icon: Icons.keyboard_arrow_down_rounded, tooltip: 'Next channel  ↓', onPressed: onDown),
            const SizedBox(width: 8),
            RoundIconButton(
              icon: fav ? Icons.star_rounded : Icons.star_outline_rounded,
              tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
              onPressed: () => state.toggleFavorite(ch.id),
            ),
            const SizedBox(width: 8),
            RoundIconButton(icon: muted ? Icons.volume_off_rounded : Icons.volume_up_rounded, tooltip: muted ? 'Unmute  M' : 'Mute  M', onPressed: onMute),
            const SizedBox(width: 8),
            RoundIconButton(icon: Icons.picture_in_picture_alt_rounded, tooltip: 'Mini player  P', onPressed: onMini),
            const SizedBox(width: 8),
            RoundIconButton(
              icon: fullScreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
              tooltip: fullScreen ? 'Exit full screen  F' : 'Full screen  F',
              onPressed: onFullScreen,
              filled: true,
            ),
          ]),
          const SizedBox(height: 18),
          if (cur != null)
            Row(children: [
              Text(fullTime(cur.start), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Palette.muted, fontFeatures: tabular)),
              const SizedBox(width: 12),
              Expanded(child: _Scrubber(value: now.difference(cur.start).inSeconds / cur.end.difference(cur.start).inSeconds)),
              const SizedBox(width: 12),
              Text(fullTime(cur.end), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Palette.muted, fontFeatures: tabular)),
              const SizedBox(width: 12),
              Text(timeLeft(cur.end.difference(now)), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, fontFeatures: tabular)),
            ])
          else
            Align(
              alignment: Alignment.centerLeft,
              child: Text(state.epgLoaded(ch.id) ? 'No guide data for this channel' : 'Loading guide',
                  style: const TextStyle(fontSize: 12, color: Palette.muted)),
            ),
          const SizedBox(height: 14),
          Container(height: 1, color: p.line),
          const SizedBox(height: 14),
          Row(children: [
            if (next != null) ...[
              const Text('NEXT', style: eyebrow),
              const SizedBox(width: 10),
              Flexible(child: Text(next.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Palette.textSoft))),
              const SizedBox(width: 10),
              Text(fullTime(next.start), style: const TextStyle(fontSize: 13, color: Palette.dim, fontFeatures: tabular)),
            ],
            const Spacer(),
            const KeyCap('↑↓'),
            const SizedBox(width: 8),
            const Text('Change channel', style: TextStyle(fontSize: 13, color: Palette.dim)),
            const SizedBox(width: 16),
            const KeyCap('Esc'),
            const SizedBox(width: 8),
            const Text('Guide', style: TextStyle(fontSize: 13, color: Palette.dim)),
          ]),
        ]),
      );
    });
  }
}

class _Scrubber extends StatelessWidget {
  const _Scrubber({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return LayoutBuilder(builder: (context, box) {
      final x = box.maxWidth * value.clamp(0.0, 1.0);
      return SizedBox(
        height: 10,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.centerLeft, children: [
          ThinProgress(value: value, color: p.accent, track: Colors.white.withValues(alpha: 0.1), height: 4),
          Positioned(
            left: x - 5,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: p.accent,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: p.accent.withValues(alpha: 0.25), spreadRadius: 3)],
              ),
            ),
          ),
        ]),
      );
    });
  }
}
