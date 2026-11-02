import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../constants.dart';

/// Période [start, end[ (fin exclusive) choisie par l'admin. Remplace les
/// anciennes fenêtres `.limit(200)` / `.limit(500)` qui faisaient
/// « disparaître » les commandes au fil des jours : ici on charge TOUTES les
/// commandes de la période, quelle que soit leur ancienneté.
class Period {
  final String key;
  final DateTime start;
  final DateTime end;

  const Period(this.key, this.start, this.end);

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  static Period today() {
    final s = _day(DateTime.now());
    return Period('today', s, s.add(const Duration(days: 1)));
  }

  static Period yesterday() {
    final e = _day(DateTime.now());
    return Period('yesterday', e.subtract(const Duration(days: 1)), e);
  }

  static Period last7Days() {
    final e = _day(DateTime.now()).add(const Duration(days: 1));
    return Period('last7', e.subtract(const Duration(days: 7)), e);
  }

  static Period thisMonth() {
    final n = DateTime.now();
    return Period(
        'thisMonth', DateTime(n.year, n.month), DateTime(n.year, n.month + 1));
  }

  static Period lastMonth() {
    final n = DateTime.now();
    return Period(
        'lastMonth', DateTime(n.year, n.month - 1), DateTime(n.year, n.month));
  }

  /// [from] et [to] sont des jours inclus.
  static Period custom(DateTime from, DateTime to) =>
      Period('custom', _day(from), _day(to).add(const Duration(days: 1)));

  /// Libellé lisible, ex. « du 01/09/2026 au 30/09/2026 ».
  String get label {
    final f = DateFormat('dd/MM/yyyy');
    final lastDay = end.subtract(const Duration(days: 1));
    if (lastDay == start) return 'le ${f.format(start)}';
    return 'du ${f.format(start)} au ${f.format(lastDay)}';
  }

  /// Requête Firestore bornée sur [field]. Inégalités + orderBy sur un seul
  /// et même champ => index automatique, pas d'index composite à déployer.
  Query<Map<String, dynamic>> apply(
    Query<Map<String, dynamic>> query,
    String field,
  ) {
    return query
        .where(field, isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where(field, isLessThan: Timestamp.fromDate(end))
        .orderBy(field, descending: true);
  }
}

/// Barre de sélection de période (puces + calendrier personnalisé), avec la
/// période affichée en clair pour que l'admin sache toujours ce qu'il voit.
class PeriodFilterBar extends StatelessWidget {
  final Period period;
  final ValueChanged<Period> onChanged;

  const PeriodFilterBar({
    super.key,
    required this.period,
    required this.onChanged,
  });

  Future<void> _pickCustom(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: DateTimeRange(
        start: period.start,
        end: period.end.subtract(const Duration(days: 1)),
      ),
    );
    if (picked != null) onChanged(Period.custom(picked.start, picked.end));
  }

  Widget _chip(String label, String key, VoidCallback onSelected) {
    final selected = period.key == key;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      selectedColor: primaryColor.withValues(alpha: 0.2),
      checkmarkColor: primaryColor,
      labelStyle: TextStyle(
        color: selected ? primaryColor : Colors.grey.shade700,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _chip("Aujourd'hui", 'today', () => onChanged(Period.today())),
        _chip('Hier', 'yesterday', () => onChanged(Period.yesterday())),
        _chip('7 derniers jours', 'last7', () => onChanged(Period.last7Days())),
        _chip('Ce mois', 'thisMonth', () => onChanged(Period.thisMonth())),
        _chip('Mois dernier', 'lastMonth', () => onChanged(Period.lastMonth())),
        _chip('Choisir des dates…', 'custom', () => _pickCustom(context)),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.date_range, size: 18, color: primaryColor),
              const SizedBox(width: 4),
              Text(
                'Période : ${period.label}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: textDarkColor),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
