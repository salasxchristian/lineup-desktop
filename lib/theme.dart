import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The three looks from the design. Only the accent and a faint tint on the darks change; text
/// and channel colors stay the same everywhere.
enum ThemeId { dark, lilac, blue }

class Palette {
  const Palette({
    required this.id,
    required this.name,
    required this.hint,
    required this.bg,
    required this.raised,
    required this.surface,
    required this.line,
    required this.accent,
    required this.primary,
    required this.onPrimary,
    required this.rowOn,
    required this.past,
    required this.live,
    required this.future,
    required this.ring,
    required this.fill,
    required this.glass,
  });

  final ThemeId id;
  final String name;
  final String hint;
  final Color bg, raised, surface, line;
  final Color accent, primary, onPrimary;
  final Color rowOn, past, live, future, ring, fill, glass;

  // Shared text colors.
  static const text = Color(0xFFECEDEE);
  static const textStrong = Color(0xFFFFFFFF);
  static const textSoft = Color(0xFFD4D6D8);
  static const muted = Color(0xFF9BA1A6);
  static const dim = Color(0xFF7C838A);
  static const faint = Color(0xFF6B7178);
  static const pastSub = Color(0xFF555A61);
  static const sub = Color(0xFF8A9097);
  static const outline = Color(0xFF2A2E33);

  static const dark = Palette(
    id: ThemeId.dark, name: 'Dark', hint: 'Signal red accent',
    bg: Color(0xFF0B0C0E), raised: Color(0xFF101114), surface: Color(0xFF1A1C20), line: Color(0xFF1A1C20),
    accent: Color(0xFFF2555A), primary: Color(0xFFECEDEE), onPrimary: Color(0xFF0B0C0E),
    rowOn: Color(0xFF121417), past: Color(0xFF101114), live: Color(0xFF1C1F24), future: Color(0xFF181A1F),
    ring: Color(0x8CECEDEE), fill: Color(0x0BFFFFFF), glass: Color(0xE00B0C0E),
  );

  static const lilac = Palette(
    id: ThemeId.lilac, name: 'Lilac', hint: 'Soft violet accent',
    bg: Color(0xFF0D0C12), raised: Color(0xFF121118), surface: Color(0xFF1E1C27), line: Color(0xFF1D1B25),
    accent: Color(0xFFC9B8FF), primary: Color(0xFFC9B8FF), onPrimary: Color(0xFF19122E),
    rowOn: Color(0xFF15131C), past: Color(0xFF110F16), live: Color(0xFF221F2E), future: Color(0xFF1B1924),
    ring: Color(0xB3C9B8FF), fill: Color(0x14C9B8FF), glass: Color(0xE00D0C12),
  );

  static const blue = Palette(
    id: ThemeId.blue, name: 'Pastel blue', hint: 'Calm sky accent',
    bg: Color(0xFF0A0D12), raised: Color(0xFF10141B), surface: Color(0xFF1A1F28), line: Color(0xFF1A1F27),
    accent: Color(0xFF9DCBFF), primary: Color(0xFF9DCBFF), onPrimary: Color(0xFF0C1A2C),
    rowOn: Color(0xFF11151C), past: Color(0xFF0F1217), live: Color(0xFF1A2230), future: Color(0xFF171C24),
    ring: Color(0xB39DCBFF), fill: Color(0x149DCBFF), glass: Color(0xE00A0D12),
  );

  static const all = [dark, lilac, blue];

  static Palette of(ThemeId id) => all.firstWhere((p) => p.id == id);

  ThemeData toThemeData() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: ColorScheme.dark(primary: primary, onPrimary: onPrimary, surface: bg, onSurface: text, secondary: accent),
      textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(bodyColor: text, displayColor: text),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.white.withValues(alpha: 0.03),
      focusColor: Colors.white.withValues(alpha: 0.06),
      textSelectionTheme: TextSelectionThemeData(cursorColor: accent, selectionColor: accent.withValues(alpha: 0.3)),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(color: text, fontSize: 12),
      ),
    );
  }
}

/// Logo tile colors (background, letters), picked per category so a category reads as one color.
const tileTints = [
  (Color(0xFF1B2A40), Color(0xFF8DB4F0)),
  (Color(0xFF16302A), Color(0xFF7FCFB0)),
  (Color(0xFF3A2A18), Color(0xFFF0B27A)),
  (Color(0xFF2A2140), Color(0xFFB9A3F0)),
  (Color(0xFF3A1E2C), Color(0xFFF0A0C4)),
  (Color(0xFF143238), Color(0xFF7FCAD6)),
];

(Color, Color) tintFor(String key) {
  var h = 0;
  for (final c in key.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return tileTints[h % tileTints.length];
}

/// The palette in use, from anywhere below the app.
class PaletteScope extends InheritedWidget {
  const PaletteScope({super.key, required this.palette, required super.child});
  final Palette palette;

  static Palette of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaletteScope>()?.palette ?? Palette.dark;

  @override
  bool updateShouldNotify(PaletteScope old) => old.palette != palette;
}

const tabular = [FontFeature.tabularFigures()];
