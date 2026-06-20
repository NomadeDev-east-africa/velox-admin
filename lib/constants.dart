import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// COULEURS PANEL ADMIN (Professionnel Bleu/Blanc)
const Color primaryColor = Color(0xFF1E88E5); // Bleu professionnel
const Color secondaryColor = Color(0xFF263238); // Gris foncé
const Color accentColor = Color(0xFF00ACC1); // Bleu cyan
const Color backgroundColor = Color(0xFFF5F7FA); // Gris très clair
const Color cardColor = Color(0xFFFFFFFF);
const Color sidebarColor = Color(0xFF263238);
const Color textDarkColor = Color(0xFF2D3142);
const Color textLightColor = Color(0xFF9E9E9E);
const Color successColor = Color(0xFF4CAF50);
const Color warningColor = Color(0xFFFFC107);
const Color errorColor = Color(0xFFF44336);
const Color infoColor = Color(0xFF2196F3);

// PADDING
const double defaultPadding = 16.0;
const double smallPadding = 8.0;
const double mediumPadding = 12.0; // AJOUTÉ
const double largePadding = 24.0;
const double extraLargePadding = 32.0; // AJOUTÉ
const double sidebarWidth = 250.0;

// BORDER RADIUS
const double defaultRadius = 12.0;
const double smallRadius = 8.0;
const double largeRadius = 20.0;
const double extraLargeRadius = 24.0; // AJOUTÉ

// RESPONSIVE BREAKPOINTS
const double mobileBreakpoint = 768.0;
const double tabletBreakpoint = 1024.0;
const double desktopBreakpoint = 1280.0; // AJOUTÉ

// TEXT STYLES
const TextStyle headingStyle = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: textDarkColor,
);

const TextStyle subheadingStyle = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: textDarkColor,
);

const TextStyle bodyStyle = TextStyle(
  fontSize: 14,
  color: textDarkColor,
);

const TextStyle captionStyle = TextStyle(
  fontSize: 12,
  color: textLightColor,
);

const TextStyle buttonStyle = TextStyle( // AJOUTÉ
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: Colors.white,
);

// ELEVATION
const double defaultElevation = 2.0;
const double mediumElevation = 4.0;
const double highElevation = 8.0;

// ICON SIZES
const double smallIconSize = 16.0;
const double defaultIconSize = 20.0;
const double largeIconSize = 24.0;
const double extraLargeIconSize = 32.0;

// ANIMATION DURATIONS
const Duration animationDuration = Duration(milliseconds: 300);
const Duration longAnimationDuration = Duration(milliseconds: 500);
const Duration shortAnimationDuration = Duration(milliseconds: 150);

// MAP CONSTANTS (AJOUTÉS)
const double minMapZoom = 3.0;
const double maxMapZoom = 18.0;
const double defaultMapZoom = 10.0;
const double circleRadiusMeters = 20000.0; // 20km
const double markerSize = 40.0;
const double markerBorderWidth = 3.0;
const double markerShadowBlur = 6.0;

// STATUTS
class RideStatus {
  static const String requested = 'requested';
  static const String accepted = 'accepted';
  static const String arriving = 'arriving';
  static const String arrived = 'arrived';
  static const String started = 'started';
  static const String completed = 'completed';
  static const String cancelled = 'cancelled';
}

// RÔLES ADMIN
class AdminRole {
  static const String superAdmin = 'super_admin';
  static const String admin = 'admin';
  static const String moderator = 'moderator';
  static const String viewer = 'viewer';
}

// CLÉS FIREBASE
class FirebaseKeys {
  // Collections
  static const String admins = 'admins';
  static const String drivers = 'drivers';
  static const String vehicles = 'vehicles';
  static const String taxiRides = 'taxiRides';
  static const String users = 'users';
  static const String restaurants = 'restaurants';
  static const String orders = 'orders';
  static const String livreurs = 'livreurs';
  static const String deliveries = 'deliveries';
  static const String notifications = 'notifications';
}

// MESSAGES
class Messages {
  static const String welcomeAdmin = 'Bienvenue Admin';
  static const String loginSuccess = 'Connexion réussie';
  static const String loginFailed = 'Échec de connexion';
  static const String noInternet = 'Pas de connexion internet';
  static const String driverAdded = 'Chauffeur ajouté avec succès';
  static const String driverUpdated = 'Chauffeur mis à jour';
  static const String driverDeleted = 'Chauffeur supprimé';
  static const String vehicleAdded = 'Véhicule ajouté avec succès';
  static const String restaurantAdded = 'Restaurant ajouté avec succès';
  static const String restaurantUpdated = 'Restaurant mis à jour';
  static const String restaurantDeleted = 'Restaurant supprimé';
  static const String settingsSaved = 'Paramètres enregistrés';
  static const String errorOccurred = 'Une erreur est survenue';
  static const String confirmDelete = 'Êtes-vous sûr de vouloir supprimer ?';
}

// URLS
class Urls {
  static const String openStreetMap = 'https://www.openstreetmap.org';
  static const String openStreetMapTile = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String openStreetMapCopyright = 'OpenStreetMap contributors';
  static const String privacyPolicy = 'https://nomade253.com/privacy';
  static const String termsOfService = 'https://nomade253.com/terms';
  static const String supportEmail = 'support@nomade253.com';
}

// ICONS
class AppIcons {
  static const IconData mapMarker = Icons.location_on;
  static const IconData mapCenter = Icons.my_location;
  static const IconData zoomIn = Icons.zoom_in;
  static const IconData zoomOut = Icons.zoom_out;
  static const IconData filter = Icons.filter_list;
  static const IconData city = Icons.location_city;
  static const IconData distance = Icons.directions;
  static const IconData population = Icons.people;
  static const IconData altitude = Icons.terrain;
  static const IconData info = Icons.info;
  static const IconData close = Icons.close;
  static const IconData save = Icons.save;
  static const IconData edit = Icons.edit;
  static const IconData delete = Icons.delete;
  static const IconData view = Icons.remove_red_eye;
  static const IconData download = Icons.download;
  static const IconData upload = Icons.upload;
  static const IconData search = Icons.search;
  static const IconData menu = Icons.menu;
  static const IconData notifications = Icons.notifications;
  static const IconData profile = Icons.person;
  static const IconData logout = Icons.logout;
  static const IconData dashboard = Icons.dashboard;
  static const IconData drivers = Icons.people;
  static const IconData restaurants = Icons.restaurant;
  static const IconData deliveries = Icons.delivery_dining;
  static const IconData rides = Icons.local_taxi;
  static const IconData statistics = Icons.analytics;
  static const IconData settings = Icons.settings;
}

// Helper pour responsive
bool isMobile(BuildContext context) =>
    MediaQuery.of(context).size.width < mobileBreakpoint;

bool isTablet(BuildContext context) =>
    MediaQuery.of(context).size.width >= mobileBreakpoint &&
    MediaQuery.of(context).size.width < tabletBreakpoint;

bool isDesktop(BuildContext context) =>
    MediaQuery.of(context).size.width >= tabletBreakpoint;

// Helper pour obtenir la taille d'écran
double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;

// Helper pour les espacements
EdgeInsets getPaddingAll(double padding) => EdgeInsets.all(padding);
EdgeInsets getPaddingHorizontal(double padding) => EdgeInsets.symmetric(horizontal: padding);
EdgeInsets getPaddingVertical(double padding) => EdgeInsets.symmetric(vertical: padding);
EdgeInsets getPaddingSymmetric({double horizontal = 0, double vertical = 0}) =>
    EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
EdgeInsets getPaddingOnly({
  double left = 0,
  double top = 0,
  double right = 0,
  double bottom = 0,
}) => EdgeInsets.only(
  left: left,
  top: top,
  right: right,
  bottom: bottom,
);

// Helper pour les box shadows
List<BoxShadow> getBoxShadow({
  Color color = Colors.black,
  double opacity = 0.1,
  double blurRadius = 4.0,
  double offsetX = 0.0,
  double offsetY = 2.0,
}) => [
  BoxShadow(
    color: color.withValues(alpha: opacity),
    blurRadius: blurRadius,
    offset: Offset(offsetX, offsetY),
  ),
];

// Helper pour les gradients
LinearGradient getPrimaryGradient() => LinearGradient(
  colors: [
    primaryColor,
    accentColor,
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

LinearGradient getSecondaryGradient() => LinearGradient(
  colors: [
    secondaryColor.withValues(alpha: 0.8),
    secondaryColor,
  ],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// Validations
class Validators {
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'L\'email est requis';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Email invalide';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    if (value.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName est requis';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le téléphone est requis';
    }
    final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Numéro de téléphone invalide';
    }
    return null;
  }
}

// Formats
class Formatters {
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  static String formatDateTime(DateTime date) {
    return '${formatDate(date)} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  static String formatCurrency(double amount) {
    return '${amount.toStringAsFixed(0)} DJF';
  }

  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.toStringAsFixed(0)} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static DateTime? parseFirestoreDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  static String formatFirestoreDate(dynamic value,
      {String pattern = 'dd/MM/yyyy HH:mm'}) {
    final dt = parseFirestoreDate(value);
    if (dt == null) return 'N/A';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    if (pattern == 'dd/MM/yyyy HH:mm') {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} $h:$m';
    }
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} $h:$m';
  }
}