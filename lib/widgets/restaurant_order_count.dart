import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants.dart';

/// Nombre réel de commandes d'un restaurant, calculé en direct via une
/// requête d'agrégation (`count()`, ne lit pas les documents) sur `orders`.
///
/// Remplace l'affichage du champ dénormalisé `restaurant.totalOrders`, qui
/// n'est incrémenté côté Cloud Functions qu'au moment où une commande passe
/// "prête" (remise resto→livreur) — donc souvent à 0 alors que le restaurant
/// a bien reçu des commandes (en attente, annulées, etc.). Voir aussi
/// `restaurant_details_screen.dart` qui recalculait déjà en direct pour son
/// historique, avec le même commentaire sur l'obsolescence de `totalOrders`.
class RestaurantOrderCount extends StatefulWidget {
  final String restaurantId;
  final TextStyle? style;

  const RestaurantOrderCount({
    super.key,
    required this.restaurantId,
    this.style,
  });

  @override
  State<RestaurantOrderCount> createState() => _RestaurantOrderCountState();
}

class _RestaurantOrderCountState extends State<RestaurantOrderCount> {
  late Future<int> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetchCount();
  }

  @override
  void didUpdateWidget(covariant RestaurantOrderCount oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.restaurantId != widget.restaurantId) {
      _future = _fetchCount();
    }
  }

  Future<int> _fetchCount() async {
    final agg = await FirebaseFirestore.instance
        .collection('orders')
        .where('restaurantId', isEqualTo: widget.restaurantId)
        .count()
        .get();
    return agg.count ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 14,
            height: 14,
            child:
                CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
          );
        }
        if (snapshot.hasError) return const Text('—');
        return Text(snapshot.data.toString(), style: widget.style);
      },
    );
  }
}
