import 'xtream.dart';

/// The guide shows two hours, starting half an hour before the current half hour, so the now
/// line always sits a quarter to half of the way across.
const guideSpan = Duration(minutes: 120);

DateTime guideStart(DateTime now) {
  final floored = DateTime(now.year, now.month, now.day, now.hour, now.minute < 30 ? 0 : 30);
  return floored.subtract(const Duration(minutes: 30));
}

/// Where the now line sits, 0 to 1 across the timeline.
double nowFraction(DateTime now, DateTime start) =>
    (now.difference(start).inSeconds / guideSpan.inSeconds).clamp(0.0, 1.0);

enum BlockState { past, live, future }

class GuideBlock {
  const GuideBlock(this.programme, this.left, this.width, this.state, this.elapsed);
  final Programme programme;

  /// Fractions of the timeline's width.
  final double left, width;
  final BlockState state;

  /// How much of the visible block has aired, 0 to 1 (live blocks only).
  final double elapsed;
}

/// The programmes that overlap the window, clipped to it.
List<GuideBlock> layoutBlocks(List<Programme> programmes, DateTime start, DateTime now) {
  final end = start.add(guideSpan);
  final total = guideSpan.inSeconds;
  final out = <GuideBlock>[];
  for (final p in programmes) {
    if (!p.end.isAfter(start) || !p.start.isBefore(end)) continue;
    final a = p.start.isBefore(start) ? start : p.start;
    final b = p.end.isAfter(end) ? end : p.end;
    final left = a.difference(start).inSeconds / total;
    final width = b.difference(a).inSeconds / total;
    if (width <= 0) continue;
    final state = !p.end.isAfter(now) ? BlockState.past : (p.isLive(now) ? BlockState.live : BlockState.future);
    final elapsed = state == BlockState.live ? (now.difference(a).inSeconds / b.difference(a).inSeconds).clamp(0.0, 1.0) : 0.0;
    out.add(GuideBlock(p, left, width, state, elapsed));
  }
  return out;
}

/// The half-hour marks across the header.
List<(double, DateTime)> guideSlots(DateTime start) => [
      for (var i = 0; i < guideSpan.inMinutes ~/ 30; i++)
        (i * 30 / guideSpan.inMinutes, start.add(Duration(minutes: 30 * i))),
    ];
