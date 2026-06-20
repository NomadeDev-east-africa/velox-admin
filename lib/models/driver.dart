import 'package:cloud_firestore/cloud_firestore.dart';

// Enum pour les types de véhicules (SEULEMENT 3)
enum VehicleType {
  standard('Standard', 'Véhicule standard 4 places'),
  comfort('Comfort', 'Véhicule confort 4 places climatisé'),
  van('Van', 'Van 7+ places');

  final String label;
  final String description;
  const VehicleType(this.label, this.description);

  static VehicleType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'comfort':
        return VehicleType.comfort;
      case 'van':
        return VehicleType.van;
      default:
        return VehicleType.standard;
    }
  }
}

class Driver {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? photoUrl;

  // VÉHICULE (INTÉGRÉ DIRECTEMENT)
  final VehicleType vehicleType;
  final String licensePlate; // Numéro de plaque
  final String licenseNumber; // Numéro de permis
  final String? vehicleBrand; // Marque (ex: Toyota)
  final String? vehicleModel; // Modèle (ex: Corolla)
  final int? vehicleYear; // Année
  final String? vehicleColor; // Couleur

  // STATUT
  final bool isActive; // Compte activé par admin
  final bool isOnline; // En ligne sur l'app
  final bool isAvailable; // Disponible pour courses

  // POSITION ACTUELLE
  final DriverLocation? currentLocation;

  // STATISTIQUES
  final int totalRides;
  final double rating;
  final double totalEarnings; // FDJ
  final int totalRatings; // Nombre de notations

  // DATES
  final DateTime createdAt;
  final DateTime? lastActiveAt;
  final DateTime updatedAt;
  
  // FCM
  final String? fcmToken;
  final DateTime? tokenUpdatedAt;

  Driver({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.photoUrl,
    required this.vehicleType,
    required this.licensePlate,
    required this.licenseNumber,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleColor,
    this.isActive = true,
    this.isOnline = false,
    this.isAvailable = false,
    this.currentLocation,
    this.totalRides = 0,
    this.rating = 5.0,
    this.totalEarnings = 0.0,
    this.totalRatings = 0,
    required this.createdAt,
    this.lastActiveAt,
    required this.updatedAt,
    this.fcmToken,
    this.tokenUpdatedAt,
  });

  // Créer depuis Firestore - LIT UNIQUEMENT CAMELCASE
  factory Driver.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Driver(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      photoUrl: data['photoUrl'],
      vehicleType: VehicleType.fromString(data['vehicleType'] ?? 'standard'),
      licensePlate: data['licensePlate'] ?? '',
      licenseNumber: data['licenseNumber'] ?? '',
      vehicleBrand: data['vehicleBrand'],
      vehicleModel: data['vehicleModel'],
      vehicleYear: data['vehicleYear'],
      vehicleColor: data['vehicleColor'],
      isActive: data['isActive'] ?? true,
      isOnline: data['isOnline'] ?? false,
      isAvailable: data['isAvailable'] ?? false,
      currentLocation: data['currentLocation'] != null
          ? DriverLocation.fromMap(data['currentLocation'])
          : null,
      totalRides: data['totalRides'] ?? 0,
      rating: (data['rating'] ?? 5.0).toDouble(),
      totalEarnings: (data['totalEarnings'] ?? 0.0).toDouble(),
      totalRatings: data['totalRatings'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastActiveAt: data['lastActiveAt'] != null
          ? (data['lastActiveAt'] as Timestamp).toDate()
          : null,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmToken: data['fcmToken'],
      tokenUpdatedAt: data['tokenUpdatedAt'] != null
          ? (data['tokenUpdatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Convertir en Map pour Firestore - UNIQUEMENT CAMELCASE
  Map<String, dynamic> toMap() {
    return {
      // Identité
      'name': name,
      'email': email,
      'phone': phone,
      'photoUrl': photoUrl,                          // ✅ camelCase
      
      // Véhicule
      'vehicleType': vehicleType.label,              // ✅ camelCase
      'licensePlate': licensePlate,                  // ✅ camelCase
      'licenseNumber': licenseNumber,                // ✅ camelCase
      'vehicleBrand': vehicleBrand,                  // ✅ camelCase
      'vehicleModel': vehicleModel,                  // ✅ camelCase
      'vehicleYear': vehicleYear,                    // ✅ camelCase
      'vehicleColor': vehicleColor,                  // ✅ camelCase
      
      // Statut
      'isActive': isActive,                          // ✅ camelCase
      'isOnline': isOnline,                          // ✅ camelCase
      'isAvailable': isAvailable,                    // ✅ camelCase
      
      // Position
      'currentLocation': currentLocation?.toMap(),   // ✅ camelCase
      
      // Stats
      'totalRides': totalRides,                      // ✅ camelCase
      'rating': rating,
      'totalEarnings': totalEarnings,                // ✅ camelCase
      'totalRatings': totalRatings,                  // ✅ camelCase
      
      // Dates
      'createdAt': Timestamp.fromDate(createdAt),    // ✅ camelCase
      'lastActiveAt': lastActiveAt != null 
          ? Timestamp.fromDate(lastActiveAt!) 
          : null,                                     // ✅ camelCase
      'updatedAt': Timestamp.fromDate(updatedAt),    // ✅ camelCase
      
      // FCM
      'fcmToken': fcmToken,                          // ✅ camelCase
      'tokenUpdatedAt': tokenUpdatedAt != null 
          ? Timestamp.fromDate(tokenUpdatedAt!) 
          : null,                                     // ✅ camelCase
    };
  }

  // CopyWith
  Driver copyWith({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
    VehicleType? vehicleType,
    String? licensePlate,
    String? licenseNumber,
    String? vehicleBrand,
    String? vehicleModel,
    int? vehicleYear,
    String? vehicleColor,
    bool? isActive,
    bool? isOnline,
    bool? isAvailable,
    DriverLocation? currentLocation,
    int? totalRides,
    double? rating,
    double? totalEarnings,
    int? totalRatings,
    DateTime? lastActiveAt,
    DateTime? updatedAt,
    String? fcmToken,
    DateTime? tokenUpdatedAt,
  }) {
    return Driver(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      photoUrl: photoUrl ?? this.photoUrl,
      vehicleType: vehicleType ?? this.vehicleType,
      licensePlate: licensePlate ?? this.licensePlate,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLocation: currentLocation ?? this.currentLocation,
      totalRides: totalRides ?? this.totalRides,
      rating: rating ?? this.rating,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      totalRatings: totalRatings ?? this.totalRatings,
      createdAt: createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      updatedAt: updatedAt ?? this.updatedAt,
      fcmToken: fcmToken ?? this.fcmToken,
      tokenUpdatedAt: tokenUpdatedAt ?? this.tokenUpdatedAt,
    );
  }

  // Formater le téléphone
  String get formattedPhone {
    if (phone.length == 10 && phone.startsWith('+253')) {
      return '+253 ${phone.substring(4, 6)} ${phone.substring(6, 8)} ${phone.substring(8, 10)} ${phone.substring(10)}';
    }
    return phone;
  }

  // Informations véhicule complètes
  String get vehicleInfo {
    final parts = <String>[];
    if (vehicleBrand != null) parts.add(vehicleBrand!);
    if (vehicleModel != null) parts.add(vehicleModel!);
    if (vehicleYear != null) parts.add('($vehicleYear)');
    if (parts.isEmpty) return vehicleType.label;
    return '${parts.join(' ')} - ${vehicleType.label}';
  }

  // Badge de statut
  String get statusBadge {
    if (!isActive) return 'Inactif';
    if (isOnline && isAvailable) return 'En ligne';
    if (isOnline) return 'Occupé';
    return 'Hors ligne';
  }

  // Couleur du statut
  String get statusColor {
    if (!isActive) return 'red';
    if (isOnline && isAvailable) return 'green';
    if (isOnline) return 'orange';
    return 'grey';
  }
}

// Position du chauffeur
class DriverLocation {
  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  DriverLocation({
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  factory DriverLocation.fromMap(Map<String, dynamic> map) {
    return DriverLocation(
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'updatedAt': Timestamp.fromDate(updatedAt),    // ✅ camelCase
    };
  }
}