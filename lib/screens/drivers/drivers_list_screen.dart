import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants.dart';
import 'add_driver_screen.dart';

class DriversListScreen extends StatefulWidget {
  const DriversListScreen({super.key});

  @override
  State<DriversListScreen> createState() => _DriversListScreenState();
}

class _DriversListScreenState extends State<DriversListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header avec recherche et bouton ajouter
        Container(
          padding: const EdgeInsets.all(defaultPadding),
          color: Colors.white,
          child: Row(
            children: [
              // Barre de recherche
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un chauffeur...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: backgroundColor,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value.toLowerCase());
                  },
                ),
              ),

              const SizedBox(width: defaultPadding),

              // Bouton ajouter
              ElevatedButton.icon(
                onPressed: () => _navigateToAddDriver(),
                icon: const Icon(Icons.add),
                label: Text(isMobile(context) ? 'Ajouter' : 'Ajouter Chauffeur'),
              ),
            ],
          ),
        ),

        // Liste des chauffeurs
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('drivers').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              var drivers = snapshot.data!.docs;

              // Filtrer par recherche
              if (_searchQuery.isNotEmpty) {
                drivers = drivers.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                         phone.contains(_searchQuery) ||
                         email.contains(_searchQuery);
                }).toList();
              }

              if (drivers.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Aucun chauffeur enregistré'
                            : 'Aucun résultat',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              // Affichage responsive
              return isMobile(context)
                  ? _buildMobileList(drivers)
                  : _buildDesktopTable(drivers);
            },
          ),
        ),
      ],
    );
  }

  // Liste mobile (cards)
  Widget _buildMobileList(List<QueryDocumentSnapshot> drivers) {
    return ListView.builder(
      padding: const EdgeInsets.all(defaultPadding),
      itemCount: drivers.length,
      itemBuilder: (context, index) {
        final data = drivers[index].data() as Map<String, dynamic>;
        
        // ✅ VERSION CORRIGÉE - lecture uniquement camelCase
        final isOnline = data['isOnline'] ?? false;  // Plus besoin de fallback snake_case
        
        return Card(
          margin: const EdgeInsets.only(bottom: defaultPadding),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isOnline == true ? successColor : Colors.grey,
              child: const Icon(Icons.person, color: Colors.white),
            ),
            title: Text(data['name'] ?? 'N/A'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['phone'] ?? ''),
                Text(
                  data['vehicleType'] ?? 'N/A',  // ✅ camelCase uniquement
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Modifier'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer'),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmDelete(drivers[index].id, data['name']);
                }
              },
            ),
          ),
        );
      },
    );
  }

  // Table desktop
  Widget _buildDesktopTable(List<QueryDocumentSnapshot> drivers) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Card(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Statut')),
            DataColumn(label: Text('Nom')),
            DataColumn(label: Text('Téléphone')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Véhicule')),
            DataColumn(label: Text('Courses')),
            DataColumn(label: Text('Note')),
            DataColumn(label: Text('Actions')),
          ],
          rows: drivers.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            
            // ✅ VERSION CORRIGÉE - lecture uniquement camelCase
            final isOnline = data['isOnline'] ?? false;
            
            return DataRow(cells: [
              DataCell(
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: isOnline == true ? successColor : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              DataCell(Text(data['name'] ?? 'N/A')),
              DataCell(Text(data['phone'] ?? 'N/A')),
              DataCell(Text(data['email'] ?? 'N/A')),
              DataCell(Text(data['vehicleType'] ?? 'N/A')),  // ✅ camelCase
              DataCell(Text('${data['totalRides'] ?? 0}')),  // ✅ camelCase
              DataCell(
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: warningColor),
                    const SizedBox(width: 4),
                    Text((data['rating'] ?? 0.0).toStringAsFixed(1)),
                  ],
                ),
              ),
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        // TODO: Implémenter modification
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20, color: errorColor),
                      onPressed: () => _confirmDelete(doc.id, data['name']),
                    ),
                  ],
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // Navigation vers ajout chauffeur
  void _navigateToAddDriver() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddDriverScreen(),
      ),
    ).then((success) {
      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chauffeur ajouté avec succès'),
            backgroundColor: successColor,
          ),
        );
      }
    });
  }

  // Confirmer suppression
  Future<void> _confirmDelete(String driverId, String driverName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le chauffeur'),
        content: Text('Voulez-vous vraiment supprimer $driverName ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: errorColor),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('drivers').doc(driverId).delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Chauffeur supprimé'),
              backgroundColor: successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: errorColor,
            ),
          );
        }
      }
    }
  }
}