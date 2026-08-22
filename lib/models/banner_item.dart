import 'package:cloud_firestore/cloud_firestore.dart';

enum BannerType { text, image }

BannerType bannerTypeFromString(String? value) =>
    value == 'image' ? BannerType.image : BannerType.text;

String bannerTypeToString(BannerType type) =>
    type == BannerType.image ? 'image' : 'text';

/// Action déclenchée au tap sur la bannière, côté client.
enum BannerActionType { none, whatsapp, url, restaurant, category }

BannerActionType bannerActionTypeFromString(String? value) {
  switch (value) {
    case 'whatsapp':
      return BannerActionType.whatsapp;
    case 'url':
      return BannerActionType.url;
    case 'restaurant':
      return BannerActionType.restaurant;
    case 'category':
      return BannerActionType.category;
    default:
      return BannerActionType.none;
  }
}

String bannerActionTypeToString(BannerActionType type) {
  switch (type) {
    case BannerActionType.whatsapp:
      return 'whatsapp';
    case BannerActionType.url:
      return 'url';
    case BannerActionType.restaurant:
      return 'restaurant';
    case BannerActionType.category:
      return 'category';
    case BannerActionType.none:
      return 'none';
  }
}

/// Bannière du carrousel promo affiché en haut de l'accueil Food (app client).
/// Remplace les bannières codées en dur — pilotées depuis l'admin, en temps
/// réel côté client (collection `banners`, triée par [order]).
class BannerItem {
  final String id;
  final BannerType type;
  final int order;
  final bool active;

  // type == text
  final String? title;
  final String? subtitle;

  // type == image
  final String? imageUrl;
  final String? storagePath; // chemin Storage, pour permettre la suppression

  final BannerActionType actionType;
  final String? actionValue; // numéro WhatsApp / URL / restaurantId / nom de catégorie

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BannerItem({
    this.id = '',
    required this.type,
    this.order = 0,
    this.active = true,
    this.title,
    this.subtitle,
    this.imageUrl,
    this.storagePath,
    this.actionType = BannerActionType.none,
    this.actionValue,
    this.createdAt,
    this.updatedAt,
  });

  factory BannerItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BannerItem(
      id: doc.id,
      type: bannerTypeFromString(data['type'] as String?),
      order: (data['order'] as num?)?.toInt() ?? 0,
      active: data['active'] as bool? ?? true,
      title: data['title'] as String?,
      subtitle: data['subtitle'] as String?,
      imageUrl: data['imageUrl'] as String?,
      storagePath: data['storagePath'] as String?,
      actionType: bannerActionTypeFromString(data['actionType'] as String?),
      actionValue: data['actionValue'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': bannerTypeToString(type),
      'order': order,
      'active': active,
      'title': title,
      'subtitle': subtitle,
      'imageUrl': imageUrl,
      'storagePath': storagePath,
      'actionType': bannerActionTypeToString(actionType),
      'actionValue': actionValue,
    };
  }
}
