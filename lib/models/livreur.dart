import 'package:cloud_firestore/cloud_firestore.dart';

/// Model Livreur pour MODULE FOOD
/// Séparé des Drivers (module TAXI)
class Livreur {
  final String id;
  final String name;
  final String phone;
  final String? email; // Optionnel
  final String? photoUrl;

  // VÉHICULE (Moto uniquement)
  final String licensePlate; // Numéro de plaque moto
  final String? vehicleBrand; // Marque (ex: Honda, Yamaha)
  final String? vehicleModel; // Modèle
  final int? vehicleYear; // Année
  final String? vehicleColor; // Couleur
  final String vehicleType; // Toujours 'moto'

  // STATUT
  final bool isActive; // Compte activé par admin
  final bool isOnline; // En ligne sur l'app
  final bool isAvailable; // Disponible pour livraisons

  // POSITION ACTUELLE
  final LivreurLocation? currentLocation;
  final String? currentOrderId; // Commande en cours

  // STATISTIQUES
  final int totalDeliveries; // Nombre de livraisons
  final double rating; // Note moyenne
  final double totalEarnings; // Gains totaux (FDJ)

  // DATES
  final DateTime createdAt;
  final DateTime? lastSeen;
  final DateTime updatedAt;
  
  // FCM
  final String? fcmToken;
  final DateTime? fcmTokenUpdatedAt;

  Livreur({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.photoUrl,
    required this.licensePlate,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehicleYear,
    this.vehicleColor,
    this.vehicleType = 'moto',
    this.isActive = true,
    this.isOnline = false,
    this.isAvailable = false,
    this.currentLocation,
    this.currentOrderId,
    this.totalDeliveries = 0,
    this.rating = 5.0,
    this.totalEarnings = 0.0,
    required this.createdAt,
    this.lastSeen,
    required this.updatedAt,
    this.fcmToken,
    this.fcmTokenUpdatedAt,
  });

  // Créer depuis Firestore - LIT UNIQUEMENT CAMELCASE
  factory Livreur.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Livreur(
      id: doc.id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      email: data['email'],
      photoUrl: data['photoUrl'],
      licensePlate: data['licensePlate'] ?? '',
      vehicleBrand: data['vehicleBrand'],
      vehicleModel: data['vehicleModel'],
      vehicleYear: data['vehicleYear'],
      vehicleColor: data['vehicleColor'],
      vehicleType: data['vehicleType'] ?? 'moto',
      isActive: data['isActive'] ?? true,
      isOnline: data['isOnline'] ?? false,
      isAvailable: data['isAvailable'] ?? false,
      currentLocation: data['currentLocation'] != null
          ? LivreurLocation.fromMap(data['currentLocation'])
          : null,
      currentOrderId: data['currentOrderId'],
      totalDeliveries: data['totalDeliveries'] ?? 0,
      rating: (data['rating'] ?? 5.0).toDouble(),
      totalEarnings: (data['totalEarnings'] ?? 0.0).toDouble(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: data['lastSeen'] != null
          ? (data['lastSeen'] as Timestamp).toDate()
          : null,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      fcmToken: data['fcmToken'],
      fcmTokenUpdatedAt: data['fcmTokenUpdatedAt'] != null
          ? (data['fcmTokenUpdatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  // Convertir en Map pour Firestore - UNIQUEMENT CAMELCASE
  Map<String, dynamic> toMap() {
    return {
      // Identité
      'name': name,
      'phone': phone,
      if (email != null) 'email': email,
      'photoUrl': photoUrl,                          // ✅ camelCase
      
      // Véhicule
      'licensePlate': licensePlate,                  // ✅ camelCase
      'vehicleBrand': vehicleBrand,                  // ✅ camelCase
      'vehicleModel': vehicleModel,                  // ✅ camelCase
      'vehicleYear': vehicleYear,                    // ✅ camelCase
      'vehicleColor': vehicleColor,                  // ✅ camelCase
      'vehicleType': 'moto',                         // ✅ camelCase
      
      // Statut
      'isActive': isActive,                          // ✅ camelCase
      'isOnline': isOnline,                          // ✅ camelCase
      'isAvailable': isAvailable,                    // ✅ camelCase
      
      // Position
      'currentLocation': currentLocation?.toMap(),   // ✅ camelCase
      'currentOrderId': currentOrderId,              // ✅ camelCase
      
      // Stats
      'totalDeliveries': totalDeliveries,            // ✅ camelCase
      'rating': rating,
      'totalEarnings': totalEarnings,                // ✅ camelCase
      
      // Dates
      'createdAt': Timestamp.fromDate(createdAt),    // ✅ camelCase
      'lastSeen': lastSeen != null 
          ? Timestamp.fromDate(lastSeen!) 
          : null,                                     // ✅ camelCase
      'updatedAt': Timestamp.fromDate(updatedAt),    // ✅ camelCase
      
      // FCM
      'fcmToken': fcmToken,                          // ✅ camelCase
      'fcmTokenUpdatedAt': fcmTokenUpdatedAt != null 
          ? Timestamp.fromDate(fcmTokenUpdatedAt!) 
          : null,                                     // ✅ camelCase
    };
  }

  // CopyWith
  Livreur copyWith({
    String? name,
    String? phone,
    String? email,
    String? photoUrl,
    String? licensePlate,
    String? vehicleBrand,
    String? vehicleModel,
    int? vehicleYear,
    String? vehicleColor,
    String? vehicleType,
    bool? isActive,
    bool? isOnline,
    bool? isAvailable,
    LivreurLocation? currentLocation,
    String? currentOrderId,
    int? totalDeliveries,
    double? rating,
    double? totalEarnings,
    DateTime? lastSeen,
    DateTime? updatedAt,
    String? fcmToken,
    DateTime? fcmTokenUpdatedAt,
  }) {
    return Livreur(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      photoUrl: photoUrl ?? this.photoUrl,
      licensePlate: licensePlate ?? this.licensePlate,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleType: vehicleType ?? this.vehicleType,
      isActive: isActive ?? this.isActive,
      isOnline: isOnline ?? this.isOnline,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLocation: currentLocation ?? this.currentLocation,
      currentOrderId: currentOrderId ?? this.currentOrderId,
      totalDeliveries: totalDeliveries ?? this.totalDeliveries,
      rating: rating ?? this.rating,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      createdAt: createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
      updatedAt: updatedAt ?? this.updatedAt,
      fcmToken: fcmToken ?? this.fcmToken,
      fcmTokenUpdatedAt: fcmTokenUpdatedAt ?? this.fcmTokenUpdatedAt,
    );
  }

  // Formater le téléphone
  String get formattedPhone {
    if (phone.length >= 10 && phone.startsWith('+253')) {
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
    if (parts.isEmpty) return 'Moto';
    return '${parts.join(' ')} - Moto';
  }

  // Badge de statut
  String get statusBadge {
    if (!isActive) return 'Inactif';
    if (isOnline && isAvailable) return 'Disponible';
    if (isOnline) return 'En livraison';
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

// Position du livreur
class LivreurLocation {
  final double latitude;
  final double longitude;
  final DateTime updatedAt;

  LivreurLocation({
    required this.latitude,
    required this.longitude,
    required this.updatedAt,
  });

  factory LivreurLocation.fromMap(Map<String, dynamic> map) {
    return LivreurLocation(
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