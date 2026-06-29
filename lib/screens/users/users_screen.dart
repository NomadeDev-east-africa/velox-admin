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
  String _searchQuery = '';

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
          color: Colors.white,
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
                final da = _parseDate(
                    (a.data() as Map<String, dynamic>)['createdAt']);
                final db = _parseDate(
                    (b.data() as Map<String, dynamic>)['createdAt']);
                if (da == null && db == null) return 0;
                if (da == null) return 1;
                if (db == null) return -1;
                return db.compareTo(da);
              });

              if (_searchQuery.isNotEmpty) {
                docs = docs.where((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final name =
                      (data['name'] ?? data['displayName'] ?? '').toString().toLowerCase();
                  final phone =
                      (data['phone'] ?? data['phoneNumber'] ?? '').toString().toLowerCase();
                  final email =
                      (data['email'] ?? '').toString().toLowerCase();
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
        final createdAt = data['createdAt'] != null
            ? _formatDate(data['createdAt'], pattern: 'dd/MM/yyyy')
            : 'N/A';

        return Card(
          margin: const EdgeInsets.only(bottom: defaultPadding),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: primaryColor,
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white),
                    )
                  : null,
            ),
            title: Text(name,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phone),
                Text(email, style: const TextStyle(fontSize: 12)),
                Text('Inscrit le $createdAt',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  Widget _buildDesktopTable(List<QueryDocumentSnapshot> docs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Card(
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Photo')),
            DataColumn(label: Text('Nom')),
            DataColumn(label: Text('Téléphone')),
            DataColumn(label: Text('Email')),
            DataColumn(label: Text('Inscription')),
            DataColumn(label: Text('Actions')),
          ],
          rows: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['name'] ?? data['displayName'] ?? 'N/A';
            final phone = data['phone'] ?? data['phoneNumber'] ?? 'N/A';
            final email = data['email'] ?? 'N/A';
            final photoUrl = data['photoUrl'] ?? data['photoURL'];
            final createdAt = _formatDate(data['createdAt'], pattern: 'dd/MM/yyyy');

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
              DataCell(Text(createdAt)),
              DataCell(
                IconButton(
                  icon: const Icon(Icons.visibility, size: 20),
                  onPressed: () => _showUserDetails(doc.id, data),
                  tooltip: 'Voir détails',
                ),
              ),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  void _showUserDetails(String id, Map<String, dynamic> data) {
    final name = data['name'] ?? data['displayName'] ?? 'N/A';
    final phone = data['phone'] ?? data['phoneNumber'] ?? 'N/A';
    final email = data['email'] ?? 'N/A';

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
        ],
      ),
    );
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
