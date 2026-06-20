import 'package:flutter/material.dart';
import '../../constants.dart';

class VehiclesScreen extends StatelessWidget {
  const VehiclesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 24),
          Text(
            'Gestion des Véhicules',
            style: headingStyle,
          ),
          const SizedBox(height: 8),
          Text(
            'Cette fonctionnalité sera disponible prochainement',
            style: TextStyle(color: textLightColor),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bientôt disponible !')),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un véhicule'),
          ),
        ],
      ),
    );
  }
}
