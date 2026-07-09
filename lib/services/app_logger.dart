import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Niveau de gravité d'un log.
enum LogLevel { debug, info, warning, error }

/// Logger centralisé de l'application.
///
/// Objectifs :
///  - Un **log constant et homogène** de toute l'appli (au lieu de `print`
///    dispersés et non horodatés).
///  - Chaque entrée passe par `dart:developer.log`, donc elle est visible dans
///    la console du navigateur, dans Flutter DevTools **et** récupérable via
///    le Dart Tooling Daemon (outil MCP `get_app_logs`) pour analyse externe.
///  - Un buffer mémoire ([history]) permet d'afficher/exporter les derniers
///    logs directement depuis l'interface admin.
class AppLogger {
  AppLogger._();

  /// Nombre maximal de lignes conservées en mémoire.
  static const int _maxBuffer = 1000;
  static final List<String> _buffer = <String>[];

  /// Copie non-modifiable de l'historique en mémoire (du plus ancien au plus
  /// récent).
  static List<String> get history => List<String>.unmodifiable(_buffer);

  /// Vide le buffer mémoire (n'affecte pas la console).
  static void clear() => _buffer.clear();

  static void d(String message, {String tag = 'APP'}) =>
      _log(LogLevel.debug, message, tag: tag);

  static void i(String message, {String tag = 'APP'}) =>
      _log(LogLevel.info, message, tag: tag);

  static void w(String message, {String tag = 'APP'}) =>
      _log(LogLevel.warning, message, tag: tag);

  static void e(
    String message, {
    String tag = 'APP',
    Object? error,
    StackTrace? stackTrace,
  }) =>
      _log(LogLevel.error, message,
          tag: tag, error: error, stackTrace: stackTrace);

  static void _log(
    LogLevel level,
    String message, {
    required String tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final now = DateTime.now();
    final line =
        '[${now.toIso8601String()}][${level.name.toUpperCase().padRight(7)}][$tag] $message';

    // Buffer mémoire (ring buffer).
    _buffer.add(line);
    if (error != null) _buffer.add('    ↳ error: $error');
    if (stackTrace != null) _buffer.add('    ↳ stack: $stackTrace');
    while (_buffer.length > _maxBuffer) {
      _buffer.removeAt(0);
    }

    // dart:developer.log → visible dans DevTools / DTD / MCP get_app_logs.
    developer.log(
      message,
      name: tag,
      time: now,
      level: _levelValue(level),
      error: error,
      stackTrace: stackTrace,
    );

    // Console (utile en web debug où developer.log est moins lisible).
    if (kDebugMode) {
      // ignore: avoid_print
      print(line);
    }
  }

  static int _levelValue(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}
