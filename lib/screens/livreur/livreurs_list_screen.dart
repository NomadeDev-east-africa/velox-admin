import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants.dart';
import 'add_livreur_screen.dart';

class LivreursListScreen extends StatefulWidget {
  const LivreursListScreen({super.key});

  @override
  State<LivreursListScreen> createState() => _LivreursListScreenState();
}

class _LivreursListScreenState extends State<LivreursListScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header avec recherche et bouton ajouter
        Container(
          padding: const EdgeInsets.all(defaultPadding),
          color: cardColor,
          child: Row(
            children: [
              // Barre de recherche
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Rechercher un livreur...',
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
                onPressed: () => _navigateToAddLivreur(),
                icon: const Icon(Icons.add),
                label: Text(isMobile(context) ? 'Ajouter' : 'Ajouter Livreur'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Liste des livreurs
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('livreurs').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              var livreurs = snapshot.data!.docs.toList();

              // Trier par note décroissante (les mieux notés en haut)
              livreurs.sort((a, b) {
                final ra = ((a.data() as Map<String, dynamic>)['rating'] ?? 5.0)
                    as num;
                final rb = ((b.data() as Map<String, dynamic>)['rating'] ?? 5.0)
                    as num;
                return rb.compareTo(ra);
              });

              // Filtrer par recherche
              if (_searchQuery.isNotEmpty) {
                livreurs = livreurs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final phone = (data['phone'] ?? '').toString().toLowerCase();
                  final plate =
                      (data['licensePlate'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      phone.contains(_searchQuery) ||
                      plate.contains(_searchQuery);
                }).toList();
              }

              if (livreurs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delivery_dining,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        _searchQuery.isEmpty
                            ? 'Aucun livreur enregistré'
                            : 'Aucun résultat',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Les livreurs sont pour le module Food',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Affichage responsive
              return isMobile(context)
                  ? _buildMobileList(livreurs)
                  : _buildDesktopTable(livreurs);
            },
          ),
        ),
      ],
    );
  }

  // Liste mobile (cards)
  Widget _buildMobileList(List<QueryDocumentSnapshot> livreurs) {
    return ListView.builder(
      padding: const EdgeInsets.all(defaultPadding),
      itemCount: livreurs.length,
      itemBuilder: (context, index) {
        final data = livreurs[index].data() as Map<String, dynamic>;

        final isOnline = data['isOnline'] ?? data['is_online'] ?? false;
        final isAvailable =
            data['isAvailable'] ?? data['is_available'] ?? false;

        return Card(
          margin: const EdgeInsets.only(bottom: defaultPadding),
          child: ListTile(
            leading: Stack(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.orange,
                  child: ClipOval(
                    child: data['photoUrl'] != null
                        ? Image.network(
                            data['photoUrl'],
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.delivery_dining,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delivery_dining,
                            color: Colors.white),
                  ),
                ),
                // Indicateur en ligne
                if (isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isAvailable ? Colors.green : Colors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            title: Text(data['name'] ?? 'N/A'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['phone'] ?? ''),
                Row(
                  children: [
                    const Icon(Icons.motorcycle, size: 12),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        data['licensePlate'] ?? 'N/A',
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: errorColor),
                      SizedBox(width: 8),
                      Text('Supprimer', style: TextStyle(color: errorColor)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'delete') {
                  _confirmDelete(livreurs[index].id, data['name']);
                }
              },
            ),
          ),
        );
      },
    );
  }

  // Table desktop
  Widget _buildDesktopTable(List<QueryDocumentSnapshot> livreurs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Card(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
          columns: const [
            DataColumn(label: Text('Statut')),
            DataColumn(label: Text('Photo')),
            DataColumn(label: Text('Nom')),
            DataColumn(label: Text('Téléphone')),
            DataColumn(label: Text('Plaque Moto')),
            DataColumn(label: Text('Livraisons')),
            DataColumn(label: Text('Note')),
            DataColumn(label: Text('Actions')),
          ],
          rows: livreurs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            final isOnline = data['isOnline'] ?? data['is_online'] ?? false;
            final isAvailable =
                data['isAvailable'] ?? data['is_available'] ?? false;

            return DataRow(cells: [
              // Statut
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isOnline
                            ? (isAvailable ? Colors.green : Colors.orange)
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOnline
                          ? (isAvailable ? 'Dispo' : 'Occupé')
                          : 'Offline',
                      style: TextStyle(
                        fontSize: 11,
                        color: isOnline
                            ? (isAvailable ? Colors.green : Colors.orange)
                            : Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Photo
              DataCell(
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.orange,
                  child: ClipOval(
                    child: data['photoUrl'] != null
                        ? Image.network(
                            data['photoUrl'],
                            width: 32,
                            height: 32,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.delivery_dining,
                              size: 16,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.delivery_dining,
                            size: 16, color: Colors.white),
                  ),
                ),
              ),
              // Nom
              DataCell(Text(data['name'] ?? 'N/A')),
              // Téléphone
              DataCell(Text(data['phone'] ?? 'N/A')),
              // Plaque
              DataCell(
                Row(
                  children: [
                    const Icon(Icons.motorcycle, size: 16),
                    const SizedBox(width: 4),
                    Text(data['licensePlate'] ?? 'N/A'),
                  ],
                ),
              ),
              // Livraisons
              DataCell(
                  Text('${data['totalDeliveries'] ?? data['total_deliveries'] ?? 0}')),
              // Note
              DataCell(
                Row(
                  children: [
                    const Icon(Icons.star, size: 16, color: warningColor),
                    const SizedBox(width: 4),
                    Text((data['rating'] ?? 5.0).toStringAsFixed(1)),
                  ],
                ),
              ),
              // Actions
              DataCell(
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: () {
                        // TODO: Implémenter modification
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Modification à venir'),
                          ),
                        );
                      },
                      tooltip: 'Modifier',
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete,
                          size: 20, color: errorColor),
                      onPressed: () => _confirmDelete(doc.id, data['name']),
                      tooltip: 'Supprimer',
                    ),
                  ],
                ),
              ),
            ]);
          }).toList(),
          ),
        ),
      ),
    );
  }

  // Navigation vers ajout livreur
  void _navigateToAddLivreur() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddLivreurScreen(),
      ),
    ).then((success) {
      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Livreur ajouté avec succès'),
            backgroundColor: successColor,
          ),
        );
      }
    });
  }

  // Confirmer suppression
  Future<void> _confirmDelete(String livreurId, String livreurName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le livreur'),
        content: Text('Voulez-vous vraiment supprimer $livreurName ?\n\n'
            'Cette action est irréversible.'),
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
        await _firestore.collection('livreurs').doc(livreurId).delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Livreur supprimé'),
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
