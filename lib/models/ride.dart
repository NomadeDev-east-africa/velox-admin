import 'package:cloud_firestore/cloud_firestore.dart';

enum RideStatusEnum {
  requested,
  accepted,
  arriving,
  arrived,
  started,
  completed,
  cancelled,
}

class Ride {
  final String id;
  
  // User info
  final String userId;
  final String userName;
  final String userPhone;
  final String? userPhotoUrl;
  
  // Pickup
  final RideLocation pickup;
  
  // Destination
  final RideLocation destination;
  
  // Details
  final double distance; // km
  final int estimatedDuration; // minutes
  final double estimatedFare; // FDJ
  final double? finalFare;
  
  // Vehicle
  final String vehicleType;
  final String? vehicleId;
  
  // Driver (null si pas encore accepté)
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverPhotoUrl;
  
  // Status
  final RideStatusEnum status;
  final String paymentMethod; // 'cash', 'd-money', 'waafi'
  final String paymentStatus; // 'pending', 'completed', 'failed'
  
  // Timestamps
  final DateTime requestedAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  
  // Ratings
  final int? userRating;
  final String? userReview;
  final int? driverRating;
  final String? driverReview;
  
  // Cancellation
  final String? cancellationReason;
  final String? cancelledBy; // 'user' ou 'driver'

  Ride({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userPhone,
    this.userPhotoUrl,
    required this.pickup,
    required this.destination,
    required this.distance,
    required this.estimatedDuration,
    required this.estimatedFare,
    this.finalFare,
    required this.vehicleType,
    this.vehicleId,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverPhotoUrl,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.requestedAt,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.userRating,
    this.userReview,
    this.driverRating,
    this.driverReview,
    this.cancellationReason,
    this.cancelledBy,
  });

  // Créer depuis Firestore - CAMELCASE UNIQUEMENT
  factory Ride.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return Ride(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userPhone: data['userPhone'] ?? '',
      userPhotoUrl: data['userPhotoUrl'],
      pickup: RideLocation.fromMap(data['pickup']),
      destination: RideLocation.fromMap(data['destination']),
      distance: (data['distance'] ?? 0.0).toDouble(),
      estimatedDuration: data['estimatedDuration'] ?? 0,
      estimatedFare: (data['estimatedFare'] ?? 0.0).toDouble(),
      finalFare: data['finalFare'] != null ? (data['finalFare'] as num).toDouble() : null,
      vehicleType: data['vehicleType'] ?? '',
      vehicleId: data['vehicleId'],
      driverId: data['driverId'],
      driverName: data['driverName'],
      driverPhone: data['driverPhone'],
      driverPhotoUrl: data['driverPhotoUrl'],
      status: _statusFromString(data['status'] ?? 'requested'),
      paymentMethod: data['paymentMethod'] ?? 'cash',
      paymentStatus: data['paymentStatus'] ?? 'pending',
      requestedAt: (data['requestedAt'] as Timestamp).toDate(),
      acceptedAt: data['acceptedAt'] != null ? (data['acceptedAt'] as Timestamp).toDate() : null,
      arrivedAt: data['arrivedAt'] != null ? (data['arrivedAt'] as Timestamp).toDate() : null,
      startedAt: data['startedAt'] != null ? (data['startedAt'] as Timestamp).toDate() : null,
      completedAt: data['completedAt'] != null ? (data['completedAt'] as Timestamp).toDate() : null,
      cancelledAt: data['cancelledAt'] != null ? (data['cancelledAt'] as Timestamp).toDate() : null,
      userRating: data['userRating'],
      userReview: data['userReview'],
      driverRating: data['driverRating'],
      driverReview: data['driverReview'],
      cancellationReason: data['cancellationReason'],
      cancelledBy: data['cancelledBy'],
    );
  }

  // Convertir status string → enum
  static RideStatusEnum _statusFromString(String status) {
    switch (status) {
      case 'requested':
        return RideStatusEnum.requested;
      case 'accepted':
        return RideStatusEnum.accepted;
      case 'arriving':
        return RideStatusEnum.arriving;
      case 'arrived':
        return RideStatusEnum.arrived;
      case 'started':
        return RideStatusEnum.started;
      case 'completed':
        return RideStatusEnum.completed;
      case 'cancelled':
        return RideStatusEnum.cancelled;
      default:
        return RideStatusEnum.requested;
    }
  }

  // Convertir enum → status string
  String get statusString {
    switch (status) {
      case RideStatusEnum.requested:
        return 'requested';
      case RideStatusEnum.accepted:
        return 'accepted';
      case RideStatusEnum.arriving:
        return 'arriving';
      case RideStatusEnum.arrived:
        return 'arrived';
      case RideStatusEnum.started:
        return 'started';
      case RideStatusEnum.completed:
        return 'completed';
      case RideStatusEnum.cancelled:
        return 'cancelled';
    }
  }

  // Prix formaté
  String get formattedEstimatedFare => '${estimatedFare.toStringAsFixed(0)} FDJ';
  String get formattedFinalFare => finalFare != null ? '${finalFare!.toStringAsFixed(0)} FDJ' : formattedEstimatedFare;

  // Distance formatée
  String get formattedDistance => '${distance.toStringAsFixed(1)} km';

  // Durée formatée
  String get formattedDuration => '$estimatedDuration min';

  // Vérifier si le chauffeur est assigné
  bool get hasDriver => driverId != null;

  // Vérifier si la course est active
  bool get isActive => status == RideStatusEnum.accepted || 
                       status == RideStatusEnum.arriving ||
                       status == RideStatusEnum.arrived ||
                       status == RideStatusEnum.started;
  
  // Vérifier si la course peut être annulée
  bool get isCancellable => status == RideStatusEnum.requested || 
                            status == RideStatusEnum.accepted ||
                            status == RideStatusEnum.arriving;
  
  // Vérifier si la course est terminée
  bool get isCompleted => status == RideStatusEnum.completed || 
                          status == RideStatusEnum.cancelled;
}

// Location (pickup ou destination) - CORRIGÉ EN CAMELCASE
class RideLocation {
  final double latitude;
  final double longitude;
  final String address;
  final String placeName;

  RideLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.placeName,
  });

  factory RideLocation.fromMap(Map<String, dynamic> map) {
    return RideLocation(
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      address: map['address'] ?? '',
      placeName: map['placeName'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'placeName': placeName,
    };
  }
}