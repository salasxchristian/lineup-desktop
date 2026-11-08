import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:window_manager/window_manager.dart';

import '../theme.dart';
import '../widgets.dart';

/// The mini player: video only, with controls on hover. Every button sits in the bottom row: on macOS the
/// top edge still belongs to the window's hidden title bar and doesn't pass clicks through. Drag anywhere to move the window,
/// double-click or Esc to go back to the full window.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  bool _hover = false;
  final _focus = FocusNode(debugLabel: 'mini');
  FocusNode? _previousFocus;

  @override
  void initState() {
    super.initState();
    _previousFocus = FocusManager.instance.primaryFocus;
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.dispose();
    // Hand the keys back to the guide or player underneath.
    if (_previousFocus?.context != null) _previousFocus!.requestFocus();
    super.dispose();
  }

  bool get _muted => AppScope.read(context).player.state.volume == 0;

  void _toggleMute() {
    final player = AppScope.read(context).player;
    player.setVolume(_muted ? 100 : 0);
    setState(() {});
  }

  Future<void> _step(int delta) async {
    final state = AppScope.read(context);
    final muted = _muted;
    state.step(delta, playNow: true);
    // play() turns the sound up; keep it off if it was muted here.
    if (muted) await state.player.setVolume(0);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final state = AppScope.read(context);
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
      case LogicalKeyboardKey.channelUp:
        _step(-1);
      case LogicalKeyboardKey.arrowDown:
      case LogicalKeyboardKey.channelDown:
        _step(1);
      case LogicalKeyboardKey.keyM:
        _toggleMute();
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.keyP:
      case LogicalKeyboardKey.enter:
        state.exitMini();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = PaletteScope.of(context);
    final ch = state.channelById(state.playingId);
    if (ch != null) state.ensureEpg(ch.id);
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => windowManager.startDragging(),
          onDoubleTap: state.exitMini,
          // A Material, not a ColoredBox: the mini player sits outside any Scaffold, and text needs one for its style.
          child: Material(
            color: Colors.black,
            child: Stack(fit: StackFit.expand, children: [
              Video(controller: state.video, controls: NoVideoControls, fill: Colors.black),
              const PlaybackStatus(compact: true),
              AnimatedOpacity(
                opacity: _hover ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                // Stays clickable while faded out, so a click on a button's spot works even before a hover shows it.
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xB3000000), Color(0x00000000), Color(0x00000000), Color(0xB3000000)],
                      stops: [0, 0.4, 0.6, 1],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (ch != null)
                          Expanded(
                            child: Ticker(builder: (context, now) {
                              final (cur, _) = state.nowNext(ch.id, now);
                              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(cur?.title.isNotEmpty == true ? cur!.title : ch.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text([if (ch.number != null) ch.number!, ch.name].join(' | '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11, color: Palette.muted, fontFeatures: tabular)),
                              ]);
                            }),
                          )
                      ]),
                      const Spacer(),
                      Row(children: [
                        RoundIconButton(icon: Icons.keyboard_arrow_up_rounded, tooltip: 'Previous channel  ↑', size: 30, background: p.glass, onPressed: () => _step(-1)),
                        const SizedBox(width: 6),
                        RoundIconButton(icon: Icons.keyboard_arrow_down_rounded, tooltip: 'Next channel  ↓', size: 30, background: p.glass, onPressed: () => _step(1)),
                        const Spacer(),
                        RoundIconButton(
                          icon: _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                          tooltip: _muted ? 'Unmute  M' : 'Mute  M',
                          size: 30,
                          background: p.glass,
                          onPressed: _toggleMute,
                        ),
                        const SizedBox(width: 6),
                        RoundIconButton(
                          icon: Icons.open_in_full_rounded,
                          tooltip: 'Back to full window  Esc',
                          size: 30,
                          background: p.glass,
                          onPressed: state.exitMini,
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
