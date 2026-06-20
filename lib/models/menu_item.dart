import 'package:cloud_firestore/cloud_firestore.dart';
import 'option_group.dart';

class MenuItem {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final String? imageUrl;
  final String category;
  final bool isAvailable;
  final int preparationTime; // en minutes
  final List<OptionGroup> optionGroups; // formules, tailles, suppléments…
  final DateTime createdAt;
  final DateTime updatedAt;

  MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.category,
    this.isAvailable = true,
    this.preparationTime = 20,
    this.optionGroups = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  // Créer depuis Firestore
  factory MenuItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return MenuItem(
      id: doc.id,
      restaurantId: data['restaurantId'] ?? '',
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      price: (data['price'] ?? 0.0).toDouble(),
      imageUrl: data['imageUrl'],
      category: data['category'] ?? 'Autres',
      isAvailable: data['isAvailable'] ?? true,
      preparationTime: data['preparationTime'] ?? 20,
      optionGroups: OptionGroup.listFromRaw(data['optionGroups']),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Convertir en Map pour Firestore
  Map<String, dynamic> toMap() {
    return {
      'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
      'category': category,
      'isAvailable': isAvailable,
      'preparationTime': preparationTime,
      'optionGroups': OptionGroup.listToRaw(optionGroups),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  // Copier avec modifications
  MenuItem copyWith({
    String? id,
    String? restaurantId,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    String? category,
    bool? isAvailable,
    int? preparationTime,
    List<OptionGroup>? optionGroups,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItem(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      preparationTime: preparationTime ?? this.preparationTime,
      optionGroups: optionGroups ?? this.optionGroups,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Formater le prix
  String get formattedPrice {
    return '${price.toStringAsFixed(0)} FDJ';
  }

  // Badge disponibilité
  String get availabilityBadge {
    return isAvailable ? 'Disponible' : 'Indisponible';
  }

  // Temps de préparation formaté
  String get formattedPreparationTime {
    if (preparationTime < 60) {
      return '$preparationTime min';
    } else {
      final hours = preparationTime ~/ 60;
      final minutes = preparationTime % 60;
      return minutes > 0 ? '${hours}h${minutes}' : '${hours}h';
    }
  }
}

// Catégories prédéfinies
class MenuCategories {
  static const String traditional = 'Plats traditionnels';
  static const String grills = 'Grillades';
  static const String pasta = 'Pâtes';
  static const String salads = 'Salades';
  static const String desserts = 'Desserts';
  static const String drinks = 'Boissons';
  static const String breakfast = 'Petit-déjeuner';
  static const String seafood = 'Fruits de mer';
  static const String other = 'Autres';

  static List<String> get all => [
        traditional,
        grills,
        pasta,
        salads,
        desserts,
        drinks,
        breakfast,
        seafood,
        other,
      ];
}
