/// Modèle des horaires d'ouverture d'un restaurant.
///
/// Stocké dans Firestore sous `restaurants/{id}.openingHours` :
/// ```
/// openingHours: {
///   "monday":    [ {"open":"08:00","close":"14:00"}, {"open":"14:00","close":"22:00"} ],
///   "friday":    [],                                  // liste vide = fermé ce jour
///   "saturday":  [ {"open":"18:00","close":"00:00"} ] // 00:00 = jusqu'à minuit
/// }
/// ```
/// Convention : clés en anglais minuscule (stables, neutres en langue),
/// heures au format "HH:mm". Une plage dont `close <= open` traverse minuit
/// (ex. 22:00 → 02:00 = ferme à 2h le lendemain ; 18:00 → 00:00 = ferme à minuit).
library;

/// Clés canoniques des jours (ordre ISO : lundi=1 … dimanche=7).
const List<String> kDayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// Libellés FR indexés par clé.
const Map<String, String> kDayLabelsFr = {
  'monday': 'Lundi',
  'tuesday': 'Mardi',
  'wednesday': 'Mercredi',
  'thursday': 'Jeudi',
  'friday': 'Vendredi',
  'saturday': 'Samedi',
  'sunday': 'Dimanche',
};

/// Ordre d'affichage local (Djibouti) : semaine débutant samedi,
/// vendredi (week-end / jour de repos) placé en dernier.
const List<String> kDayDisplayOrder = [
  'saturday',
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
];

/// Une plage horaire ("08:00" → "14:00").
class TimeRange {
  final String open; // "HH:mm"
  final String close; // "HH:mm"

  const TimeRange({required this.open, required this.close});

  factory TimeRange.fromMap(Map<String, dynamic> map) => TimeRange(
        open: (map['open'] ?? '00:00').toString(),
        close: (map['close'] ?? '00:00').toString(),
      );

  Map<String, dynamic> toMap() => {'open': open, 'close': close};

  TimeRange copyWith({String? open, String? close}) =>
      TimeRange(open: open ?? this.open, close: close ?? this.close);

  /// Minutes depuis minuit pour "HH:mm" (retourne 0 si invalide).
  static int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return (h.clamp(0, 23)) * 60 + m.clamp(0, 59);
  }

  int get openMinutes => _toMinutes(open);

  /// Fin de plage en minutes, normalisée sur l'échelle du jour d'ouverture.
  /// Si `close <= open`, la plage traverse minuit → on ajoute 1440
  /// (ainsi "00:00" en fermeture = 1440 = minuit du même jour).
  int get closeMinutesNormalized {
    final o = openMinutes;
    var c = _toMinutes(close);
    if (c <= o) c += 1440;
    return c;
  }

  /// Vrai si cette plage traverse minuit (déborde sur le lendemain).
  bool get crossesMidnight => closeMinutesNormalized > 1440;

  String get label => '$open – $close';
}

class OpeningHours {
  /// clé jour anglais → liste de plages. Jour absent ou liste vide = fermé.
  final Map<String, List<TimeRange>> days;

  const OpeningHours(this.days);

  factory OpeningHours.empty() => OpeningHours({for (final k in kDayKeys) k: const []});

  factory OpeningHours.fromMap(Map<String, dynamic>? raw) {
    final result = <String, List<TimeRange>>{};
    for (final key in kDayKeys) {
      final value = raw?[key];
      if (value is List) {
        result[key] = value
            .whereType<Map>()
            .map((e) => TimeRange.fromMap(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        result[key] = const [];
      }
    }
    return OpeningHours(result);
  }

  Map<String, dynamic> toMap() =>
      {for (final key in kDayKeys) key: days[key]?.map((r) => r.toMap()).toList() ?? []};

  List<TimeRange> rangesFor(String dayKey) => days[dayKey] ?? const [];

  OpeningHours copyWithDay(String dayKey, List<TimeRange> ranges) {
    final next = Map<String, List<TimeRange>>.from(days);
    next[dayKey] = ranges;
    return OpeningHours(next);
  }

  /// Applique les mêmes plages à tous les jours.
  OpeningHours copyToAllDays(List<TimeRange> ranges) =>
      OpeningHours({for (final k in kDayKeys) k: List<TimeRange>.from(ranges)});

  bool get isEmpty => kDayKeys.every((k) => rangesFor(k).isEmpty);

  /// Vrai s'il y a au moins une plage définie dans la semaine.
  bool get hasAnyHours => !isEmpty;

  /// Clé anglaise du jour pour un [DateTime] (weekday 1=lundi … 7=dimanche).
  static String _dayKeyForWeekday(int weekday) => kDayKeys[(weekday - 1) % 7];

  /// Le restaurant est-il ouvert (selon les horaires) au moment [dt] ?
  /// Gère les plages traversant minuit, y compris le débordement de la veille.
  bool isOpenAt(DateTime dt) {
    final nowMin = dt.hour * 60 + dt.minute;

    // Plages du jour courant.
    for (final r in rangesFor(_dayKeyForWeekday(dt.weekday))) {
      if (nowMin >= r.openMinutes && nowMin < r.closeMinutesNormalized) {
        return true;
      }
    }

    // Plages de la veille qui débordent après minuit sur aujourd'hui.
    final yesterday = dt.subtract(const Duration(days: 1));
    for (final r in rangesFor(_dayKeyForWeekday(yesterday.weekday))) {
      if (r.crossesMidnight && (nowMin + 1440) < r.closeMinutesNormalized) {
        return true;
      }
    }
    return false;
  }

  /// Pratique pour l'UI / le client.
  bool get isOpenNow => isOpenAt(DateTime.now());
}
