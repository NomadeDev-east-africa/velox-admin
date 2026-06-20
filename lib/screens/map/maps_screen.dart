import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants.dart';

class MapsScreen extends StatefulWidget {
  const MapsScreen({super.key});

  @override
  State<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends State<MapsScreen> {
  late final MapController _mapController;
  final LatLng _djiboutiCenter = const LatLng(11.5940, 43.1470);

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Extrait une LatLng depuis un champ Firestore qui peut être :
  /// - un GeoPoint natif  (livreurs)
  /// - une Map {latitude, longitude} (drivers)
  LatLng? _parseLocation(dynamic value) {
    if (value == null) return null;
    if (value is GeoPoint) {
      return LatLng(value.latitude, value.longitude);
    }
    if (value is Map) {
      final lat = value['latitude'];
      final lng = value['longitude'];
      if (lat != null && lng != null) {
        return LatLng((lat as num).toDouble(), (lng as num).toDouble());
      }
    }
    return null;
  }

  /// Applique un offset angulaire pour les marqueurs au même endroit.
  /// Si N personnes sont au même point, elles sont réparties sur un cercle
  /// de ~20m de rayon autour du point réel.
  List<LatLng> _applyOffset(List<LatLng> positions) {
    if (positions.length <= 1) return positions;

    const double offsetDeg = 0.00018; // ≈ 20m
    final result = <LatLng>[];
    for (int i = 0; i < positions.length; i++) {
      final angle = (2 * pi * i) / positions.length;
      result.add(LatLng(
        positions[i].latitude + offsetDeg * cos(angle),
        positions[i].longitude + offsetDeg * sin(angle),
      ));
    }
    return result;
  }

  /// Regroupe les docs par position arrondie (≈ 11m de précision),
  /// puis applique l'offset angulaire pour chaque groupe.
  List<({LatLng displayPos, LatLng realPos, Map<String, dynamic> data})>
      _resolveMarkers(List<QueryDocumentSnapshot> docs) {
    // 1. Parser toutes les positions valides
    final entries = <({LatLng realPos, Map<String, dynamic> data})>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final pos = _parseLocation(data['currentLocation']);
      if (pos == null) continue;
      entries.add((realPos: pos, data: data));
    }

    // 2. Grouper par clé arrondie à 4 décimales
    final groups = <String, List<int>>{};
    for (int i = 0; i < entries.length; i++) {
      final key =
          '${entries[i].realPos.latitude.toStringAsFixed(4)},${entries[i].realPos.longitude.toStringAsFixed(4)}';
      groups.putIfAbsent(key, () => []).add(i);
    }

    // 3. Calculer positions d'affichage avec offset
    final result =
        <({LatLng displayPos, LatLng realPos, Map<String, dynamic> data})>[];
    for (final indices in groups.values) {
      final rawPositions = indices.map((i) => entries[i].realPos).toList();
      final offsetPositions = _applyOffset(rawPositions);
      for (int j = 0; j < indices.length; j++) {
        final e = entries[indices[j]];
        result.add((
          displayPos: offsetPositions[j],
          realPos: e.realPos,
          data: e.data,
        ));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Column(
        children: [
          // En-tête
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: defaultPadding, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Carte — Positions en temps réel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textDarkColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('livreurs')
                            .where('isOnline', isEqualTo: true)
                            .snapshots(),
                        builder: (_, livSnap) => StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('drivers')
                              .where('isOnline', isEqualTo: true)
                              .snapshots(),
                          builder: (_, drvSnap) {
                            final livCount =
                                livSnap.data?.docs.length ?? 0;
                            final drvCount =
                                drvSnap.data?.docs.length ?? 0;
                            return Text(
                              '$livCount livreur(s) • $drvCount chauffeur(s) en ligne',
                              style: const TextStyle(
                                  fontSize: 12, color: textLightColor),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    _controlBtn(Icons.zoom_in, _zoomIn),
                    const SizedBox(width: 6),
                    _controlBtn(Icons.zoom_out, _zoomOut),
                    const SizedBox(width: 6),
                    _controlBtn(Icons.my_location, _resetCenter),
                  ],
                ),
              ],
            ),
          ),

          // Carte
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('livreurs')
                  .where('isOnline', isEqualTo: true)
                  .snapshots(),
              builder: (_, livSnap) => StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('drivers')
                    .where('isOnline', isEqualTo: true)
                    .snapshots(),
                builder: (_, drvSnap) {
                  final livreurMarkers = _resolveMarkers(
                      livSnap.data?.docs ?? []);
                  final driverMarkers = _resolveMarkers(
                      drvSnap.data?.docs ?? []);

                  return FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _djiboutiCenter,
                      initialZoom: 14.0,
                      maxZoom: 18.0,
                      minZoom: 10.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.nomade253.admin',
                      ),

                      // Marqueurs livreurs (moto — orange)
                      MarkerLayer(
                        markers: livreurMarkers.map((e) {
                          final isAvailable =
                              e.data['isAvailable'] ?? false;
                          return Marker(
                            point: e.displayPos,
                            width: 46,
                            height: 46,
                            child: GestureDetector(
                              onTap: () => _showInfo(
                                name: e.data['name'] ?? 'Livreur',
                                phone: e.data['phone'] ?? '',
                                plate: e.data['licensePlate'] ?? '',
                                status: isAvailable
                                    ? 'Disponible'
                                    : 'En livraison',
                                statusColor: isAvailable
                                    ? successColor
                                    : warningColor,
                                icon: Icons.motorcycle,
                                color: Colors.orange,
                                realPos: e.realPos,
                                displayPos: e.displayPos,
                              ),
                              child: _markerWidget(
                                icon: Icons.motorcycle,
                                color: Colors.orange,
                                dotColor: isAvailable
                                    ? successColor
                                    : warningColor,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      // Marqueurs chauffeurs (voiture — bleu)
                      MarkerLayer(
                        markers: driverMarkers.map((e) {
                          final isAvailable =
                              e.data['isAvailable'] ?? false;
                          return Marker(
                            point: e.displayPos,
                            width: 46,
                            height: 46,
                            child: GestureDetector(
                              onTap: () => _showInfo(
                                name: e.data['name'] ?? 'Chauffeur',
                                phone: e.data['phone'] ?? '',
                                plate: e.data['licensePlate'] ?? '',
                                status: isAvailable
                                    ? 'Disponible'
                                    : 'En course',
                                statusColor: isAvailable
                                    ? successColor
                                    : infoColor,
                                icon: Icons.directions_car,
                                color: primaryColor,
                                realPos: e.realPos,
                                displayPos: e.displayPos,
                              ),
                              child: _markerWidget(
                                icon: Icons.directions_car,
                                color: primaryColor,
                                dotColor: isAvailable
                                    ? successColor
                                    : infoColor,
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const RichAttributionWidget(
                        attributions: [
                          TextSourceAttribution(
                              'OpenStreetMap contributors'),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Légende
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: defaultPadding, vertical: 10),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _legendItem(Colors.orange, Icons.motorcycle, 'Livreur'),
                const SizedBox(width: 24),
                _legendItem(primaryColor, Icons.directions_car, 'Chauffeur'),
                const SizedBox(width: 24),
                _legendItem(successColor, Icons.circle, 'Disponible'),
                const SizedBox(width: 24),
                _legendItem(warningColor, Icons.circle, 'Occupé'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _markerWidget({
    required IconData icon,
    required Color color,
    required Color dotColor,
  }) {
    return Stack(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.45),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        Positioned(
          right: 1,
          top: 1,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  void _showInfo({
    required String name,
    required String phone,
    required String plate,
    required String status,
    required Color statusColor,
    required IconData icon,
    required Color color,
    required LatLng realPos,
    required LatLng displayPos,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(largeRadius)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(largePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: textDarkColor)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(status,
                            style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),
            _infoRow(Icons.phone, phone),
            const SizedBox(height: 6),
            _infoRow(Icons.confirmation_number, plate),
            const SizedBox(height: 6),
            _infoRow(
              Icons.location_on,
              '${realPos.latitude.toStringAsFixed(5)}, ${realPos.longitude.toStringAsFixed(5)}',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _mapController.move(displayPos, 16.0);
                    },
                    icon: const Icon(Icons.zoom_in, size: 18),
                    label: const Text('Centrer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      foregroundColor: primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white),
                    child: const Text('Fermer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: textLightColor),
        const SizedBox(width: 8),
        Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13, color: textDarkColor))),
      ],
    );
  }

  Widget _controlBtn(IconData icon, VoidCallback onPressed) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 17, color: primaryColor),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _legendItem(Color color, IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, size: 11, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: textLightColor)),
      ],
    );
  }

  void _zoomIn() {
    final z = _mapController.camera.zoom;
    if (z < 18.0) _mapController.move(_mapController.camera.center, z + 1);
  }

  void _zoomOut() {
    final z = _mapController.camera.zoom;
    if (z > 10.0) _mapController.move(_mapController.camera.center, z - 1);
  }

  void _resetCenter() => _mapController.move(_djiboutiCenter, 14.0);
}
