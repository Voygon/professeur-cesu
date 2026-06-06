import 'package:flutter/material.dart';

/// Affiche un bottom sheet avec deux colonnes défilantes (heures / minutes)
/// style drum-roll. Retourne [TimeOfDay] ou null si annulé.
Future<TimeOfDay?> showHeureScrollPicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => _HeureScrollSheet(initialTime: initialTime),
  );
}

class _HeureScrollSheet extends StatefulWidget {
  final TimeOfDay initialTime;
  const _HeureScrollSheet({required this.initialTime});

  @override
  State<_HeureScrollSheet> createState() => _HeureScrollSheetState();
}

class _HeureScrollSheetState extends State<_HeureScrollSheet> {
  late int _heure;
  late int _minute;
  late final FixedExtentScrollController _heureCtrl;
  late final FixedExtentScrollController _minCtrl;

  @override
  void initState() {
    super.initState();
    _heure = widget.initialTime.hour;
    _minute = widget.initialTime.minute;
    _heureCtrl = FixedExtentScrollController(initialItem: _heure);
    _minCtrl = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void dispose() {
    _heureCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ── Barre Annuler / heure affichée / OK ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  Text(
                    '${_heure.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      TimeOfDay(hour: _heure, minute: _minute),
                    ),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),

            // ── Colonnes défilantes ──
            SizedBox(
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Bande de sélection centrale
                  Positioned(
                    left: 32,
                    right: 32,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _colonne(
                          controller: _heureCtrl,
                          count: 24,
                          selected: _heure,
                          onChanged: (v) => setState(() => _heure = v),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          ':',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _colonne(
                          controller: _minCtrl,
                          count: 60,
                          selected: _minute,
                          onChanged: (v) => setState(() => _minute = v),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colonne({
    required FixedExtentScrollController controller,
    required int count,
    required int selected,
    required ValueChanged<int> onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 52,
      perspective: 0.003,
      diameterRatio: 1.8,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) {
          final isSelected = index == selected;
          return Center(
            child: Text(
              index.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: isSelected ? 32 : 22,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.w300,
                color: isSelected
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
          );
        },
      ),
    );
  }
}
