import 'package:cloud_firestore/cloud_firestore.dart';
import 'opening_hours.dart';

class Restaurant {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String address;
  final String? imageUrl;
  final String? description;
  final bool isOpen;
  final bool isActive;
  final double rating;
  final int totalOrders;
  final double totalRevenue;
  final double latitude;
  final double longitude;
  final OpeningHours openingHours;
  final DateTime createdAt;
  final DateTime updatedAt;

  Restaurant({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.address,
    this.imageUrl,
    this.description,
    required this.isOpen,
    required this.isActive,
    this.rating = 0.0,
    this.totalOrders = 0,
    this.totalRevenue = 0.0,
    this.latitude = 11.5721, // Djibouti par défaut
    this.longitude = 43.1456,
    OpeningHours? openingHours,
    required this.createdAt,
    required this.updatedAt,
  }) : openingHours = openingHours ?? const OpeningHours({});

  // Créer depuis Firestore
  factory Restaurant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Restaurant(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'] ?? '',
      imageUrl: data['imageUrl'],
      description: data['description'],
      isOpen: data['isOpen'] ?? true,
      isActive: data['isActive'] ?? true,
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalOrders: data['totalOrders'] ?? 0,
      totalRevenue: (data['totalRevenue'] ?? 0.0).toDouble(),
      latitude: (data['latitude'] ?? 11.5721).toDouble(),
      longitude: (data['longitude'] ?? 43.1456).toDouble(),
      openingHours: OpeningHours.fromMap(
        data['openingHours'] is Map
            ? Map<String, dynamic>.from(data['openingHours'])
            : null,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'imageUrl': imageUrl,
      'description': description,
      'isOpen': isOpen,
      'isActive': isActive,
      'rating': rating,
      'totalOrders': totalOrders,
      'totalRevenue': totalRevenue,
      'latitude': latitude,
      'longitude': longitude,
      'openingHours': openingHours.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Copier avec modifications
  Restaurant copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? imageUrl,
    String? description,
    bool? isOpen,
    bool? isActive,
    double? rating,
    int? totalOrders,
    double? totalRevenue,
    double? latitude,
    double? longitude,
    OpeningHours? openingHours,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      isOpen: isOpen ?? this.isOpen,
      isActive: isActive ?? this.isActive,
      rating: rating ?? this.rating,
      totalOrders: totalOrders ?? this.totalOrders,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      openingHours: openingHours ?? this.openingHours,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Formater le numéro de téléphone pour affichage
  String get formattedPhone {
    if (phone.length == 10 && phone.startsWith('+253')) {
      return '+253 ${phone.substring(4, 6)} ${phone.substring(6, 8)} ${phone.substring(8, 10)} ${phone.substring(10)}';
    }
    return phone;
  }

  // Badge de statut
  String get statusBadge {
    if (!isActive) return 'Inactif';
    if (!isOpen) return 'Fermé';
    return 'Actif';
  }

  // Couleur du statut
  String get statusColor {
    if (!isActive) return 'red';
    if (!isOpen) return 'orange';
    return 'green';
  }

  /// Des horaires d'ouverture ont-ils été configurés ?
  bool get hasOpeningHours => openingHours.hasAnyHours;

  /// Ouvert maintenant selon les horaires configurés (indépendant du
  /// toggle manuel [isOpen]). Renvoie `null` si aucun horaire n'est défini.
  bool? get isOpenNowBySchedule =>
      hasOpeningHours ? openingHours.isOpenNow : null;
}
