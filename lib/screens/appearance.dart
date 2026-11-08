import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets.dart';

enum _Section { appearance, provider }

/// Settings: the theme picker and the provider login.
class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  _Section _section = _Section.appearance;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Scaffold(
      body: Column(children: [
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          child: Row(children: [
            BackPill(label: 'Guide', onPressed: () => Navigator.of(context).pop()),
            const Expanded(
              child: Center(child: Text('Settings', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.15))),
            ),
            const SizedBox(width: 96),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 40, 28, 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(
                    width: 200,
                    child: Column(children: [
                      _NavItem(label: 'Appearance', selected: _section == _Section.appearance, onTap: () => setState(() => _section = _Section.appearance)),
                      const SizedBox(height: 2),
                      _NavItem(label: 'Provider', selected: _section == _Section.provider, onTap: () => setState(() => _section = _Section.provider)),
                    ]),
                  ),
                  const SizedBox(width: 40),
                  Expanded(child: _section == _Section.appearance ? const _Appearance() : const _Provider()),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    return Material(
      color: selected ? p.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          child: Text(label,
              style: TextStyle(fontSize: 14, fontWeight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? Palette.text : Palette.muted)),
        ),
      ),
    );
  }
}

class _Appearance extends StatelessWidget {
  const _Appearance();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = PaletteScope.of(context);
    final swatches = [('Accent', p.accent), ('Button', p.primary), ('Surface', p.surface), ('Raised', p.raised), ('Background', p.bg)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Appearance', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.7)),
      const SizedBox(height: 8),
      const Text(
        'Pick an accent. It colors the live marker, progress, buttons and selected category. The guide stays dark so video stands out.',
        style: TextStyle(fontSize: 14, height: 1.55, color: Palette.muted),
      ),
      const SizedBox(height: 32),
      LayoutBuilder(builder: (context, box) {
        final cols = (box.maxWidth / 236).floor().clamp(1, 3);
        final w = (box.maxWidth - 16 * (cols - 1)) / cols;
        return Wrap(spacing: 16, runSpacing: 16, children: [
          for (final theme in Palette.all)
            SizedBox(width: w, child: _ThemeCard(theme: theme, selected: theme.id == state.themeId, onTap: () => state.setTheme(theme.id))),
        ]);
      }),
      const SizedBox(height: 32),
      Container(height: 1, color: p.line),
      const SizedBox(height: 24),
      Text('${p.name.toUpperCase()} COLORS', style: eyebrow),
      const SizedBox(height: 14),
      Wrap(spacing: 12, runSpacing: 12, children: [
        for (final (label, color) in swatches)
          Container(
            width: 170,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: p.raised, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_hex(color), style: const TextStyle(fontSize: 12, color: Palette.muted, fontFeatures: tabular)),
              ]),
            ]),
          ),
      ]),
    ]);
  }

  static String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.theme, required this.selected, required this.onTap});
  final Palette theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PaletteScope.of(context);
    final t = theme;
    Widget bar(double w, Color c, {double h = 10}) =>
        Container(width: w, height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(h / 2)));
    Widget row(int live, int rest) => SizedBox(
          height: 18,
          child: Row(children: [
            Container(width: 18, decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(5))),
            const SizedBox(width: 4),
            Expanded(flex: live, child: Container(decoration: BoxDecoration(color: t.live, borderRadius: BorderRadius.circular(5)))),
            const SizedBox(width: 4),
            Expanded(flex: rest, child: Container(decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(5)))),
          ]),
        );

    return Semantics(
      selected: selected,
      button: true,
      label: '${t.name} theme',
      child: Material(
        color: p.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: selected ? t.accent : p.line, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 150,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 10, height: 10, decoration: BoxDecoration(color: t.accent, borderRadius: BorderRadius.circular(3))),
                    const SizedBox(width: 6),
                    bar(38, t.primary),
                    const SizedBox(width: 6),
                    bar(26, t.surface),
                    const SizedBox(width: 6),
                    bar(30, t.surface),
                  ]),
                  const SizedBox(height: 13),
                  Expanded(
                    child: LayoutBuilder(builder: (context, box) => Stack(children: [
                          Column(children: [row(3, 2), const SizedBox(height: 6), row(2, 3), const SizedBox(height: 6), row(4, 1)]),
                          Positioned(left: box.maxWidth * 0.42, top: 0, bottom: 0, child: Container(width: 2, color: t.accent)),
                        ])),
                  ),
                  const SizedBox(height: 9),
                  bar(58, t.primary, h: 16),
                ]),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(t.hint, style: const TextStyle(fontSize: 12, color: Palette.muted)),
                    ]),
                  ),
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: selected ? t.accent : Colors.transparent,
                      shape: BoxShape.circle,
                      border: selected ? null : Border.all(color: const Color(0xFF3A3F45), width: 1.5),
                    ),
                    child: selected ? Icon(Icons.check_rounded, size: 14, color: t.onPrimary) : null,
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Provider extends StatelessWidget {
  const _Provider();

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final p = PaletteScope.of(context);
    final creds = state.credentials;
    final account = state.account;
    String? expires;
    if (account?.expires != null) {
      final e = account!.expires!;
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      expires = '${months[e.month - 1]} ${e.day}, ${e.year}';
    }
    final rows = <(String, String)>[
      ('Server', creds == null ? '' : (Uri.tryParse(creds.server)?.authority ?? creds.server)),
      ('Username', creds?.username ?? ''),
      ('Status', account?.status ?? (account == null ? 'Checking' : 'Active')),
      ('Expires', expires ?? 'Never'),
      if (account?.maxConnections != null) ('Connections', '${account!.activeConnections ?? 0} of ${account.maxConnections} in use'),
      ('Channels', '${state.channels.length}'),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Provider', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.7)),
      const SizedBox(height: 8),
      const Text('The Xtream Codes line this app plays from.', style: TextStyle(fontSize: 14, height: 1.55, color: Palette.muted)),
      const SizedBox(height: 32),
      Container(
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(color: p.raised, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
        child: Column(children: [
          for (var i = 0; i < rows.length; i++)
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: p.line))),
              child: Row(children: [
                SizedBox(width: 140, child: Text(rows[i].$1, style: const TextStyle(fontSize: 14, color: Palette.muted))),
                Expanded(
                  child: Text(rows[i].$2, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, fontFeatures: tabular)),
                ),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 24),
      Row(children: [
        PrimaryPill(label: 'Refresh channels', icon: Icons.refresh_rounded, onPressed: state.reload, busy: state.loadingLists),
        const SizedBox(width: 10),
        TextButton(
          onPressed: () async {
            await state.signOut();
            if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          },
          style: TextButton.styleFrom(
            foregroundColor: Palette.text,
            backgroundColor: p.surface,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            shape: const StadiumBorder(),
          ),
          child: const Text('Sign out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ]),
    ]);
  }
}
