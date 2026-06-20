import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/opening_hours.dart';

/// Éditeur réutilisable des horaires d'ouverture, par jour de la semaine.
///
/// Chaque jour peut être « Fermé » (aucune plage) ou contenir une ou plusieurs
/// plages horaires (gère les coupures, ex. 08:00–14:00 puis 14:00–22:00).
/// Une plage dont la fermeture est antérieure ou égale à l'ouverture traverse
/// minuit (ex. 18:00–00:00 = jusqu'à minuit ; 22:00–02:00 = jusqu'à 2h).
///
/// Ordre d'affichage local : semaine débutant samedi, vendredi (jour de repos
/// à Djibouti) en dernier.
class OpeningHoursEditor extends StatefulWidget {
  final OpeningHours value;
  final ValueChanged<OpeningHours> onChanged;

  const OpeningHoursEditor({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<OpeningHoursEditor> createState() => _OpeningHoursEditorState();
}

class _OpeningHoursEditorState extends State<OpeningHoursEditor> {
  late OpeningHours _hours;

  @override
  void initState() {
    super.initState();
    _hours = widget.value;
  }

  @override
  void didUpdateWidget(OpeningHoursEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _hours = widget.value;
    }
  }

  void _update(OpeningHours next) {
    setState(() => _hours = next);
    widget.onChanged(next);
  }

  Future<TimeOfDay?> _pickTime(String current) {
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 8,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '') ?? 0,
    );
    return showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.schedule, color: primaryColor),
            const SizedBox(width: 8),
            const Text(
              'Horaires d\'ouverture',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _copyToAllDays,
              icon: const Icon(Icons.copy_all, size: 18),
              label: const Text('Appliquer à tous'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Laissez un jour « Fermé » s\'il n\'y a pas de service. '
          'Vous pouvez ajouter plusieurs plages (ex. service midi + soir).',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 12),
        for (final dayKey in kDayDisplayOrder) _buildDayRow(dayKey),
      ],
    );
  }

  Widget _buildDayRow(String dayKey) {
    final ranges = _hours.rangesFor(dayKey);
    final isOpen = ranges.isNotEmpty;
    final isFriday = dayKey == 'friday';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 100,
                  child: Row(
                    children: [
                      Text(
                        kDayLabelsFr[dayKey] ?? dayKey,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (isFriday) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: 'Week-end',
                          child: Icon(Icons.weekend,
                              size: 14, color: Colors.grey.shade500),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  isOpen ? 'Ouvert' : 'Fermé',
                  style: TextStyle(
                    fontSize: 12,
                    color: isOpen ? successColor : Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Switch(
                  value: isOpen,
                  activeThumbColor: successColor,
                  onChanged: (v) {
                    _update(_hours.copyWithDay(
                      dayKey,
                      v
                          ? [const TimeRange(open: '08:00', close: '22:00')]
                          : const [],
                    ));
                  },
                ),
              ],
            ),
            if (isOpen) ...[
              const SizedBox(height: 4),
              for (int i = 0; i < ranges.length; i++)
                _buildRangeRow(dayKey, ranges, i),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    final next = List<TimeRange>.from(ranges)
                      ..add(const TimeRange(open: '14:00', close: '22:00'));
                    _update(_hours.copyWithDay(dayKey, next));
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Ajouter une plage'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRangeRow(String dayKey, List<TimeRange> ranges, int index) {
    final range = ranges[index];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _timeButton(
            label: range.open,
            onTap: () async {
              final picked = await _pickTime(range.open);
              if (picked == null) return;
              final next = List<TimeRange>.from(ranges);
              next[index] = range.copyWith(open: _fmt(picked));
              _update(_hours.copyWithDay(dayKey, next));
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('→'),
          ),
          _timeButton(
            label: range.close,
            onTap: () async {
              final picked = await _pickTime(range.close);
              if (picked == null) return;
              final next = List<TimeRange>.from(ranges);
              next[index] = range.copyWith(close: _fmt(picked));
              _update(_hours.copyWithDay(dayKey, next));
            },
          ),
          if (range.crossesMidnight)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Tooltip(
                message: 'Ferme le lendemain (traverse minuit)',
                child: Icon(Icons.nightlight_round,
                    size: 16, color: Colors.indigo.shade300),
              ),
            ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: Colors.red.shade300),
            tooltip: 'Supprimer la plage',
            onPressed: () {
              final next = List<TimeRange>.from(ranges)..removeAt(index);
              _update(_hours.copyWithDay(dayKey, next));
            },
          ),
        ],
      ),
    );
  }

  Widget _timeButton({required String label, required VoidCallback onTap}) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  Future<void> _copyToAllDays() async {
    // Choisir le jour source parmi ceux qui ont des horaires.
    final candidates =
        kDayDisplayOrder.where((k) => _hours.rangesFor(k).isNotEmpty).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Définissez d\'abord les horaires d\'un jour.'),
        ),
      );
      return;
    }
    final source = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Copier les horaires de…'),
        children: [
          for (final k in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, k),
              child: Text(
                  '${kDayLabelsFr[k]} (${_hours.rangesFor(k).map((r) => r.label).join(', ')})'),
            ),
        ],
      ),
    );
    if (source == null) return;
    _update(_hours.copyToAllDays(_hours.rangesFor(source)));
  }
}
