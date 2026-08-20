import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _horizontalController = ScrollController();
  String _searchQuery = '';

  @override
  void dispose() {
    _horizontalController.dispose();
    super.dispose();
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _formatDate(dynamic value, {String pattern = 'dd/MM/yyyy HH:mm'}) {
    final dt = _parseDate(value);
    if (dt == null) return 'N/A';
    return DateFormat(pattern).format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(defaultPadding),
          color: cardColor,
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher un utilisateur...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: backgroundColor,
            ),
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          ),
        ),

        // Liste utilisateurs
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              var docs = snapshot.data!.docs.toList();

              // Tri par date d'inscription décroissante (du plus récent au plus ancien)
              docs.sort((a, b) {
                final da =
                    _parseDate((a.data() as Map<String, dynamic>)['createdAt']);
                final db =
                    _parseDate((b.data() as Map<String, dynamic>)['createdAt']);
                if (da == null && db == null) return 0;
                if (da == null) return 1;
                if (db == null) return -1;
                return db.compareTo(da);
              });

              if (_searchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? data['displayName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final phone = (data['phone'] ?? data['phoneNumber'] ?? '')
                      .toString()
                      .toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery) ||
                      phone.contains(_searchQuery) ||
                      email.contains(_searchQuery);
                }).toList();
              }

              if (docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun utilisateur',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                );
              }

              return isMobile(context)
                  ? _buildMobileList(docs)
                  : _buildDesktopTable(docs);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMobileList(List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(defaultPadding),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final data = docs[i].data() as Map<String, dynamic>;
        final name = data['name'] ?? data['displayName'] ?? 'N/A';
        final phone = data['phone'] ?? data['phoneNumber'] ?? 'N/A';
        final email = data['email'] ?? 'N/A';
        final photoUrl = data['photoUrl'] ?? data['photoURL'];
        final isActive = data['isActive'] ?? true;
        final createdAt = data['createdAt'] != null
            ? _formatDate(data['createdAt'], pattern: 'dd/MM/yyyy')
            : 'N/A';

        return Card(
          margin: const EdgeInsets.only(bottom: defaultPadding),
          child: ListTile(
            onTap: () => _showUserDetails(docs[i].id, data),
            leading: CircleAvatar(
              backgroundColor: primaryColor,
              backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            title:
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phone),
                Text(email, style: const TextStyle(fontSize: 12)),
                Text('Inscrit le $createdAt',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                if (!isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: _statusBadge('Bloqué', errorColor),
                  ),
              ],
            ),
            isThreeLine: true,
            trailing: IconButton(
              icon: Icon(isActive ? Icons.block : Icons.check_circle,
                  color: isActive ? errorColor : successColor),
              tooltip: isActive ? 'Bloquer' : 'Débloquer',
              onPressed: () =>
                  _confirmToggleActive(docs[i].id, name.toString(), isActive),
            ),
          ),
        );
      },
    );
  }

  Widget _statusBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildDesktopTable(List<QueryDocumentSnapshot> docs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Card(
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 12),
            child: DataTable(
              columnSpacing: 24,
              horizontalMargin: 16,
              columns: const [
                DataColumn(label: Text('Photo')),
                DataColumn(label: Text('Nom')),
                DataColumn(label: Text('Téléphone')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Statut')),
                DataColumn(label: Text('Inscription')),
                DataColumn(label: Text('Actions')),
              ],
              rows: docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final name = data['name'] ?? data['displayName'] ?? 'N/A';
                final phone = data['phone'] ?? data['phoneNumber'] ?? 'N/A';
                final email = data['email'] ?? 'N/A';
                final photoUrl = data['photoUrl'] ?? data['photoURL'];
                final isActive = data['isActive'] ?? true;
                final createdAt =
                    _formatDate(data['createdAt'], pattern: 'dd/MM/yyyy');

                return DataRow(cells: [
                  // Photo
                  DataCell(
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: primaryColor,
                      backgroundImage:
                          photoUrl != null ? NetworkImage(photoUrl) : null,
                      child: photoUrl == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 12),
                            )
                          : null,
                    ),
                  ),
                  DataCell(Text(name)),
                  DataCell(Text(phone)),
                  DataCell(Text(email)),
                  DataCell(_statusBadge(isActive ? 'Actif' : 'Bloqué',
                      isActive ? successColor : errorColor)),
                  DataCell(Text(createdAt)),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility, size: 20),
                          onPressed: () => _showUserDetails(doc.id, data),
                          tooltip: 'Voir détails',
                        ),
                        IconButton(
                          icon: Icon(
                              isActive ? Icons.block : Icons.check_circle,
                              size: 20,
                              color: isActive ? errorColor : successColor),
                          tooltip: isActive ? 'Bloquer' : 'Débloquer',
                          onPressed: () => _confirmToggleActive(
                              doc.id, name.toString(), isActive),
                        ),
                      ],
                    ),
                  ),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  void _showUserDetails(String id, Map<String, dynamic> data) {
    final name = data['name'] ?? data['displayName'] ?? 'N/A';
    final phone = data['phone'] ?? data['phoneNumber'] ?? 'N/A';
    final email = data['email'] ?? 'N/A';
    final isActive = data['isActive'] ?? true;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person, color: primaryColor),
            const SizedBox(width: 8),
            Expanded(child: Text(name)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _detailRow('ID', id),
              _detailRow('Nom', name),
              _detailRow('Téléphone', phone),
              _detailRow('Email', email),
              _detailRow('Statut', isActive ? 'Actif' : 'Bloqué'),
              if (data['createdAt'] != null)
                _detailRow('Inscrit le', _formatDate(data['createdAt'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmToggleActive(id, name.toString(), isActive);
            },
            style: TextButton.styleFrom(
                foregroundColor: isActive ? errorColor : successColor),
            child: Text(isActive ? 'Bloquer' : 'Débloquer'),
          ),
        ],
      ),
    );
  }

  // Bloquer/débloquer un client
  Future<void> _confirmToggleActive(
      String userId, String userName, bool currentlyActive) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title:
            Text(currentlyActive ? 'Bloquer le client' : 'Débloquer le client'),
        content: Text(currentlyActive
            ? 'Voulez-vous vraiment bloquer $userName ?'
            : 'Voulez-vous vraiment débloquer $userName ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: currentlyActive ? errorColor : successColor),
            child: Text(currentlyActive ? 'Bloquer' : 'Débloquer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _firestore.collection('users').doc(userId).update({
          'isActive': !currentlyActive,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(currentlyActive ? 'Client bloqué' : 'Client débloqué'),
              backgroundColor: successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: errorColor),
          );
        }
      }
    }
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label :',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: textLightColor),
            ),
          ),
          Expanded(child: Text(value?.toString() ?? '-')),
        ],
      ),
    );
  }
}
