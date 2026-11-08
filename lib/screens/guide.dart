import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../guide_layout.dart';
import '../state.dart';
import '../updater.dart';
import '../theme.dart';
import '../widgets.dart';
import '../xtream.dart';
import 'appearance.dart';
import 'player.dart';

const _rowHeight = 64.0;
const _channelColumn = 232.0;
const _edge = 28.0;
const _sidebarWidth = 248.0;

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'guide');
  final _searchFocus = FocusNode(debugLabel: 'search');
  final _searchText = TextEditingController();

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    _searchFocus.dispose();
    _searchText.dispose();
    super.dispose();
  }

  Future<void> _watch() async {
    final state = AppScope.read(context);
    if (state.selectedId == null) return;
    await state.watch();
    if (!mounted) return;
    await Navigator.of(context).push(PageRouteBuilder(
      pageBuilder: (_, _, _) => const PlayerScreen(),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 180),
    ));
    await state.leavePlayer();
    _focus.requestFocus();
    _scrollToSelected();
  }

  Future<void> _openSettings({SettingsSection section = SettingsSection.appearance}) async {
    await showSettings(context, section: section);
    if (mounted) _focus.requestFocus();
  }

  void _scrollToSelected() {
    final state = AppScope.read(context);
    final i = state.visibleChannels.indexWhere((ch) => ch.id == state.selectedId);
    if (i < 0 || !_scroll.hasClients) return;
    final top = i * _rowHeight, bottom = top + _rowHeight;
    final view = _scroll.position;
    if (top < view.pixels) {
      _scroll.jumpTo(top);
    } else if (bottom > view.pixels + view.viewportDimension) {
      _scroll.jumpTo(bottom - view.viewportDimension);
    }
  }

  void _cycleCategory(int delta) {
    final state = AppScope.read(context);
    final ids = [allCategory, favoritesCategory, ...state.categories.map((c) => c.id)];
    final i = ids.indexOf(state.category);
    state.setCategory(ids[(i + delta).clamp(0, ids.length - 1)]);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final state = AppScope.read(context);
    switch (e.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        state.step(1);
        _scrollToSelected();
      case LogicalKeyboardKey.arrowUp:
        state.step(-1);
        _scrollToSelected();
      case LogicalKeyboardKey.pageDown:
        state.step(8);
        _scrollToSelected();
      case LogicalKeyboardKey.pageUp:
        state.step(-8);
        _scrollToSelected();
      case LogicalKeyboardKey.arrowRight:
        _cycleCategory(1);
      case LogicalKeyboardKey.arrowLeft:
        _cycleCategory(-1);
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _watch();
      case LogicalKeyboardKey.slash:
        _searchFocus.requestFocus();
      // Letters typed into search reach this handler too.
      case LogicalKeyboardKey.keyP when !_searchFocus.hasFocus:
        state.enterMini();
      default:
        return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _clearSearch() {
    _searchText.clear();
    AppScope.read(context).setSearch('');
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = PaletteScope.of(context);
    return Scaffold(
      body: Focus(
        focusNode: _focus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _sidebar(state, p),
          Expanded(
            child: Column(children: [
              _topBar(state, p),
              if (state.channels.isEmpty)
                Expanded(child: _emptyState(state))
              else ...[
                _Hero(onWatch: _watch),
                Container(height: 1, color: p.line),
                Expanded(child: _GuideGrid(scroll: _scroll, onWatch: _watch)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState(AppState state) {
    if (state.loadingLists) {
      return const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Palette.muted)));
    }
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(state.listError ?? 'No channels on this line.', style: const TextStyle(fontSize: 15, color: Palette.muted)),
        const SizedBox(height: 16),
        Row(mainAxisSize: MainAxisSize.min, children: [
          PrimaryPill(label: 'Try again', onPressed: state.reload),
          const SizedBox(width: 10),
          TextButton(
            onPressed: state.signOut,
            style: TextButton.styleFrom(
              foregroundColor: Palette.text,
              backgroundColor: PaletteScope.of(context).surface,
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              shape: const StadiumBorder(),
            ),
            child: const Text('Change provider', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }

  /// The selected category's name and size, and the clock.
  Widget _topBar(AppState state, Palette p) {
    final count = state.visibleChannels.length;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: _edge),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
      child: Row(children: [
        Expanded(
          child: Row(children: [
            Flexible(
              child: Text(
                state.search.isNotEmpty ? 'Results for \u201c${state.search}\u201d' : state.categoryName(state.category),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.35),
              ),
            ),
            const SizedBox(width: 10),
            Text('$count channel${count == 1 ? '' : 's'}', style: const TextStyle(fontSize: 13, color: Palette.dim, fontFeatures: tabular)),
          ]),
        ),
        const SizedBox(width: 16),
        const Clock(),
      ]),
    );
  }

  /// Brand, search, categories with counts, and Settings at the bottom.
  Widget _sidebar(AppState state, Palette p) {
    final ids = [
      allCategory,
      if (state.favorites.isNotEmpty || state.category == favoritesCategory) favoritesCategory,
      ...state.categories.map((c) => c.id),
    ];
    final host = Uri.tryParse(state.credentials?.server ?? '')?.host ?? '';
    return Container(
      width: _sidebarWidth,
      decoration: BoxDecoration(border: Border(right: BorderSide(color: p.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: const Row(children: [
            BrandMark(size: 26),
            SizedBox(width: 10),
            Text('Lineup', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
          child: Container(
            height: 38,
            padding: const EdgeInsets.only(left: 12, right: 8),
            decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.search_rounded, size: 17, color: Palette.dim),
              const SizedBox(width: 8),
              Expanded(
                child: CallbackShortcuts(
                  bindings: {const SingleActivator(LogicalKeyboardKey.escape): _clearSearch},
                  child: TextField(
                    controller: _searchText,
                    focusNode: _searchFocus,
                    onChanged: state.setSearch,
                    onSubmitted: (_) => _focus.requestFocus(),
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search channels',
                      hintStyle: TextStyle(color: Palette.dim, fontSize: 13),
                    ),
                  ),
                ),
              ),
              if (state.search.isEmpty) const KeyCap('/') else
                InkWell(
                  onTap: _clearSearch,
                  borderRadius: BorderRadius.circular(10),
                  child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.close_rounded, size: 16, color: Palette.muted)),
                ),
            ]),
          ),
        ),
        const Padding(padding: EdgeInsets.fromLTRB(24, 14, 24, 8), child: Text('CATEGORIES', style: eyebrow)),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: ids.length,
            itemBuilder: (context, i) {
              final id = ids[i];
              return _SidebarItem(
                label: state.categoryName(id),
                count: state.countFor(id),
                selected: state.search.isEmpty && state.category == id,
                leading: switch (id) {
                  allCategory => const Icon(Icons.grid_view_rounded, size: 15, color: Palette.muted),
                  favoritesCategory => const Icon(Icons.star_rounded, size: 16, color: Palette.muted),
                  _ => Container(width: 8, height: 8, decoration: BoxDecoration(color: tintFor(id).$2, shape: BoxShape.circle)),
                },
                onTap: () {
                  if (state.search.isNotEmpty) _clearSearch();
                  state.setCategory(id);
                },
              );
            },
          ),
        ),
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.line))),
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            if (state.updater.status == UpdateStatus.available)
              _SidebarItem(
                label: 'Update to ${state.updater.latest!.version}',
                subtitle: 'New version on GitHub',
                leading: Icon(Icons.arrow_circle_up_rounded, size: 17, color: p.accent),
                onTap: () => _openSettings(section: SettingsSection.updates),
              ),
            _SidebarItem(
              label: 'Settings',
              subtitle: host,
              leading: const Icon(Icons.settings_outlined, size: 17, color: Palette.muted),
              onTap: _openSettings,
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({required this.label, required this.leading, required this.onTap, this.count, this.subtitle, this.selected = false});
  final String label;
  final Widget leading;
  final VoidCallback onTap;
  final int? count;
  final String? subtitle;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? p.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              SizedBox(width: 18, child: Center(child: leading)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                        color: selected ? Palette.textStrong : Palette.textSoft,
                      )),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Palette.dim)),
                  ],
                ]),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                Text('$count', style: TextStyle(fontSize: 12, color: selected ? p.accent : Palette.dim, fontFeatures: tabular)),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// The selected channel: live preview with sound, what's on, and Watch.
class _Hero extends StatelessWidget {
  const _Hero({required this.onWatch});
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final ch = state.selected;
    if (ch == null) return const SizedBox(height: 24);
    state.ensureEpg(ch.id);
    return Ticker(builder: (context, now) {
      final (cur, next) = state.nowNext(ch.id, now);
      final progress = cur == null ? 0.0 : now.difference(cur.start).inSeconds / cur.end.difference(cur.start).inSeconds;
      final tag = state.primaryCategoryName(ch);
      return Padding(
        padding: const EdgeInsets.fromLTRB(_edge, 28, _edge, 24),
        child: SizedBox(
          height: 268,
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _Preview(channel: ch, progress: progress, onTap: onWatch),
            const SizedBox(width: 32),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  ChannelLogo(channel: ch, size: 40),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ch.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(ch.number == null ? 'Live channel' : 'Channel ${ch.number}',
                        style: const TextStyle(fontSize: 12, color: Palette.dim, fontFeatures: tabular)),
                  ]),
                ]),
                const SizedBox(height: 18),
                Text(cur?.title.isNotEmpty == true ? cur!.title : ch.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1, height: 1.1)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  if (cur != null) ...[
                    Text('${fullTime(cur.start)} to ${fullTime(cur.end)}',
                        style: const TextStyle(fontSize: 13, color: Palette.muted, fontFeatures: tabular)),
                    Container(width: 3, height: 3, decoration: const BoxDecoration(color: Color(0xFF4A5058), shape: BoxShape.circle)),
                    Text(timeLeft(cur.end.difference(now)),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFeatures: tabular)),
                  ] else
                    Text(state.epgLoaded(ch.id) ? 'No guide data' : 'Loading guide',
                        style: const TextStyle(fontSize: 13, color: Palette.muted)),
                  if (tag.isNotEmpty) Tag(tag),
                ]),
                if (cur != null && cur.description.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(cur.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, height: 1.6, color: Palette.muted)),
                  ),
                ],
                const SizedBox(height: 18),
                Row(children: [
                  PrimaryPill(label: 'Watch live', icon: Icons.play_arrow_rounded, onPressed: onWatch),
                  const SizedBox(width: 10),
                  RoundIconButton(
                    icon: state.favorites.contains(ch.id) ? Icons.star_rounded : Icons.star_outline_rounded,
                    tooltip: state.favorites.contains(ch.id) ? 'Remove from favorites' : 'Add to favorites',
                    onPressed: () => state.toggleFavorite(ch.id),
                  ),
                  const SizedBox(width: 10),
                  RoundIconButton(icon: Icons.picture_in_picture_alt_rounded, tooltip: 'Mini player  P', onPressed: state.enterMini),
                  if (next != null) ...[
                    const SizedBox(width: 16),
                    Flexible(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(text: 'Next at ${fullTime(next.start)} | '),
                          TextSpan(text: next.title, style: const TextStyle(color: Palette.textSoft)),
                        ]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Palette.dim),
                      ),
                    ),
                  ],
                ]),
              ]),
            ),
          ]),
        ),
      );
    });
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.channel, required this.progress, required this.onTap});
  final Channel channel;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = PaletteScope.of(context);
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: Color(0x80000000), blurRadius: 48, offset: Offset(0, 24))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            color: const Color(0xFF050506),
            child: InkWell(
              onTap: onTap,
              child: Stack(fit: StackFit.expand, children: [
                if (state.playingId == channel.id)
                  IgnorePointer(child: Video(controller: state.video, controls: NoVideoControls, fill: const Color(0xFF050506))),
                if (state.playingId == channel.id) const PlaybackStatus(compact: true),
                const Positioned(top: 12, left: 12, child: LiveBadge()),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: ThinProgress(value: progress, color: p.accent, track: Colors.white.withValues(alpha: 0.12), height: 3),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.line),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The timeline: a channel per row, programmes as blocks across two hours, and the now line.
class _GuideGrid extends StatelessWidget {
  const _GuideGrid({required this.scroll, required this.onWatch});
  final ScrollController scroll;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = PaletteScope.of(context);
    final list = state.visibleChannels;
    return Ticker(builder: (context, now) {
      final start = guideStart(now);
      final frac = nowFraction(now, start);
      return LayoutBuilder(builder: (context, box) {
        final timelineWidth = box.maxWidth - _channelColumn - _edge;
        final nowX = _channelColumn + timelineWidth * frac;
        return Column(children: [
          Container(
            height: 40,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
            child: Row(children: [
              const SizedBox(
                width: _channelColumn,
                child: Padding(padding: EdgeInsets.only(left: _edge), child: Text('TODAY', style: eyebrow)),
              ),
              Expanded(
                child: Stack(children: [
                  for (final (f, t) in guideSlots(start))
                    Positioned(
                      left: timelineWidth * f,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.only(left: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(border: Border(left: BorderSide(color: p.line))),
                        child: Text(f == 0 ? fullTime(t) : clockTime(t),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Palette.muted, fontFeatures: tabular)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: _edge),
            ]),
          ),
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Text(state.search.isNotEmpty ? 'No channels match “${state.search}”.' : 'No channels here yet.',
                        style: const TextStyle(color: Palette.muted, fontSize: 14)),
                  )
                : Stack(children: [
                    ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.only(top: 6, bottom: 16),
                      itemExtent: _rowHeight,
                      itemCount: list.length,
                      itemBuilder: (context, i) => _GuideRow(
                        channel: list[i],
                        start: start,
                        now: now,
                        timelineWidth: timelineWidth,
                        onWatch: onWatch,
                      ),
                    ),
                    Positioned(
                      left: nowX - 1,
                      top: 0,
                      bottom: 0,
                      child: IgnorePointer(
                        child: Stack(clipBehavior: Clip.none, children: [
                          Container(width: 2, color: p.accent),
                          Positioned(
                            top: -1,
                            left: -3,
                            child: Container(width: 8, height: 8, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
                          ),
                        ]),
                      ),
                    ),
                  ]),
          ),
        ]);
      });
    });
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.channel, required this.start, required this.now, required this.timelineWidth, required this.onWatch});
  final Channel channel;
  final DateTime start, now;
  final double timelineWidth;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = PaletteScope.of(context);
    final on = state.selectedId == channel.id;
    state.ensureEpg(channel.id);
    final blocks = layoutBlocks(state.epg[channel.id] ?? const [], start, now);
    void pick() => on ? onWatch() : state.select(channel.id);

    return ColoredBox(
      color: on ? p.rowOn : Colors.transparent,
      child: Row(children: [
        InkWell(
          onTap: pick,
          child: SizedBox(
            width: _channelColumn,
            height: _rowHeight,
            child: Padding(
              padding: const EdgeInsets.only(left: _edge, right: 16),
              child: Row(children: [
                SizedBox(
                  width: 34,
                  child: Text(channel.number ?? '',
                      overflow: TextOverflow.clip,
                      maxLines: 1,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: on ? Palette.text : Palette.faint, fontFeatures: tabular)),
                ),
                const SizedBox(width: 8),
                ChannelLogo(channel: channel),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: on ? Palette.textStrong : Palette.textSoft)),
                ),
              ]),
            ),
          ),
        ),
        SizedBox(
          width: timelineWidth,
          height: _rowHeight,
          child: Stack(children: [
            if (blocks.isEmpty)
              Positioned(
                left: 2,
                right: 2,
                top: 6,
                bottom: 6,
                child: _Block(
                  title: state.epgLoaded(channel.id) ? channel.name : '',
                  subtitle: state.epgLoaded(channel.id) ? 'No guide data' : '',
                  bg: p.future,
                  fg: Palette.muted,
                  sub: Palette.faint,
                  onTap: pick,
                ),
              ),
            for (final b in blocks)
              Positioned(
                left: timelineWidth * b.left + 2,
                width: (timelineWidth * b.width - 4).clamp(0, double.infinity),
                top: 6,
                bottom: 6,
                child: _Block(
                  title: b.programme.title.isEmpty ? channel.name : b.programme.title,
                  subtitle: b.state == BlockState.live
                      ? '${fullTime(b.programme.start)} to ${fullTime(b.programme.end)}'
                      : fullTime(b.programme.start),
                  bg: switch (b.state) { BlockState.past => p.past, BlockState.live => p.live, BlockState.future => p.future },
                  fg: b.state == BlockState.past ? Palette.faint : Palette.text,
                  sub: b.state == BlockState.past ? Palette.pastSub : Palette.sub,
                  elapsed: b.elapsed,
                  fill: p.fill,
                  ring: b.state == BlockState.live && on ? p.ring : null,
                  onTap: pick,
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.title, required this.subtitle, required this.bg, required this.fg, required this.sub, required this.onTap, this.elapsed = 0, this.fill, this.ring});
  final String title, subtitle;
  final Color bg, fg, sub;
  final double elapsed;
  final Color? fill, ring;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: ring == null ? BorderSide.none : BorderSide(color: ring!),
    );
    return Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(children: [
          if (elapsed > 0 && fill != null)
            Positioned.fill(child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: elapsed, child: ColoredBox(color: fill!))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: fg)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false,
                    style: TextStyle(fontSize: 11, color: sub, fontFeatures: tabular)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}
