import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CartReservationTimer extends StatelessWidget {
  final Duration remaining;
  const CartReservationTimer({super.key, required this.remaining});

  @override
  Widget build(BuildContext context) {
    final totalSecs = remaining.inSeconds.clamp(0, 300);
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    final frac = totalSecs / 300.0;
    final urgent = totalSecs < 120;
    final c1 = urgent ? const Color(0xFFF4511E) : AppTheme.primary;
    final c2 = urgent ? const Color(0xFFBF360C) : AppTheme.primaryDark;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [c1, c2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: c1.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              urgent ? 'Affrettati, stanno per scadere!' : 'Prodotti riservati per te',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12.5),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 7,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 58,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(
              '$mins:${secs.toString().padLeft(2, '0')}',
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 24,
                letterSpacing: 1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const Text('rimasti', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }
}
