import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'constants.dart';
import 'services/app_logger.dart';
import 'screens/auth/admin_login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Log constant : capturer TOUTES les erreurs Flutter + zones non gérées.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.e(
      'FlutterError: ${details.exceptionAsString()}',
      tag: 'FLUTTER',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.e('Erreur non gérée', tag: 'ZONE', error: error, stackTrace: stack);
    return true;
  };

  AppLogger.i('Démarrage Velox Admin', tag: 'BOOT');

  // Initialiser Firebase avec les vraies credentials
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  AppLogger.i('Firebase initialisé', tag: 'BOOT');

  runApp(const VeloxAdminPanel());
}

class VeloxAdminPanel extends StatelessWidget {
  const VeloxAdminPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Velox Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        canvasColor: backgroundColor,
        colorScheme: const ColorScheme.dark(
          primary: primaryColor,
          onPrimary: veloxBlack,
          secondary: accentColor,
          onSecondary: veloxBlack,
          surface: cardColor,
          onSurface: textDarkColor,
          error: errorColor,
          onError: veloxBlack,
        ),
        dividerColor: Colors.white12,
        iconTheme: const IconThemeData(color: textDarkColor),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: primaryColor,
          selectionColor: Color(0x55A6E22E),
          selectionHandleColor: primaryColor,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: veloxBlack,
          foregroundColor: textDarkColor,
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: primaryColor),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: veloxBlack, // texte noir sur bouton vert fluo
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(defaultRadius),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: primaryColor),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primaryColor,
            side: const BorderSide(color: primaryColor),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(defaultRadius),
            ),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: primaryColor,
          foregroundColor: veloxBlack,
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: primaryColor,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(defaultRadius),
            side: const BorderSide(color: Colors.white10),
          ),
          color: cardColor,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: veloxSurfaceAlt,
          hintStyle: const TextStyle(color: textLightColor),
          labelStyle: const TextStyle(color: textLightColor),
          prefixIconColor: textLightColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(defaultRadius),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(defaultRadius),
            borderSide: const BorderSide(color: Colors.white12),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(defaultRadius),
            borderSide: const BorderSide(color: primaryColor, width: 2),
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? primaryColor
                : Colors.grey.shade400,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? primaryColor.withValues(alpha: 0.4)
                : Colors.white24,
          ),
        ),
        dataTableTheme: DataTableThemeData(
          headingRowColor: WidgetStateProperty.all(veloxSurfaceAlt),
          dataRowColor: WidgetStateProperty.all(cardColor),
          dividerThickness: 1,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

/// Wrapper pour vérifier l'authentification admin
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // En cours de chargement
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          );
        }

        // User connecté → Dashboard
        if (snapshot.hasData) {
          return const DashboardScreen();
        }

        // Pas connecté → Login
        return const AdminLoginScreen();
      },
    );
  }
}