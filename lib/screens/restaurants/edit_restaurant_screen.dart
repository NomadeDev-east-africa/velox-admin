import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants.dart';
import '../../models/restaurant.dart';
import '../../services/restaurant_service.dart';
import '../../services/app_logger.dart';

/// Écran d'édition d'un restaurant existant.
///
/// Permet de modifier le nom, le **numéro de téléphone**, l'adresse, la
/// description, la position et surtout l'**image** (ce qui était impossible
/// auparavant car le bouton d'édition n'était qu'un TODO).
///
/// L'email et le mot de passe (compte Firebase Auth) ne sont pas modifiables
/// ici : ils touchent au compte de connexion et nécessitent une opération Auth
/// dédiée.
class EditRestaurantScreen extends StatefulWidget {
  final Restaurant restaurant;

  const EditRestaurantScreen({super.key, required this.restaurant});

  @override
  State<EditRestaurantScreen> createState() => _EditRestaurantScreenState();
}

class _EditRestaurantScreenState extends State<EditRestaurantScreen> {
  static const String _tag = 'EDIT_RESTO';

  final _formKey = GlobalKey<FormState>();
  final RestaurantService _restaurantService = RestaurantService();
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;

  late bool _isActive;
  bool _isLoading = false;

  // Image existante (URL) et nouvelle image éventuellement choisie.
  String? _currentImageUrl;
  Uint8List? _newImageBytes;
  String? _newImageName;

  @override
  void initState() {
    super.initState();
    final r = widget.restaurant;
    _nameController = TextEditingController(text: r.name);
    _phoneController = TextEditingController(text: r.phone);
    _addressController = TextEditingController(text: r.address);
    _descriptionController = TextEditingController(text: r.description ?? '');
    _latitudeController = TextEditingController(text: r.latitude.toString());
    _longitudeController = TextEditingController(text: r.longitude.toString());
    _isActive = r.isActive;
    _currentImageUrl = r.imageUrl;
    AppLogger.i('Ouverture édition restaurant ${r.id} (${r.name})', tag: _tag);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  // ==================== IMAGE ====================

  Future<void> _pickImage() async {
    try {
      AppLogger.d('Sélection d\'une nouvelle image...', tag: _tag);
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (pickedFile == null) {
        AppLogger.d('Sélection image annulée', tag: _tag);
        return;
      }

      final bytes = await pickedFile.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        AppLogger.w('Image trop grande: ${bytes.length} bytes', tag: _tag);
        _showSnack('Image trop grande (max 5MB)', Colors.orange);
        return;
      }

      setState(() {
        _newImageBytes = bytes;
        _newImageName = pickedFile.name;
      });
      AppLogger.i(
        'Nouvelle image chargée: ${pickedFile.name} (${bytes.length} bytes)',
        tag: _tag,
      );
    } catch (e, st) {
      AppLogger.e('Erreur sélection image', tag: _tag, error: e, stackTrace: st);
      _showSnack('Erreur sélection image: $e', errorColor);
    }
  }

  /// Upload l'image vers Firebase Storage et renvoie l'URL de téléchargement.
  Future<String?> _uploadImage(String restaurantId) async {
    if (_newImageBytes == null) return null;
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'restaurant_${restaurantId}_$timestamp.jpg';
      AppLogger.i('Upload image → restaurants/$fileName', tag: _tag);

      final storageRef =
          FirebaseStorage.instance.ref().child('restaurants').child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'restaurant_logo',
        },
      );

      final snapshot = await storageRef.putData(_newImageBytes!, metadata);
      final downloadUrl = await snapshot.ref.getDownloadURL();
      AppLogger.i('Image uploadée: $downloadUrl', tag: _tag);
      return downloadUrl;
    } catch (e, st) {
      AppLogger.e('Erreur upload image', tag: _tag, error: e, stackTrace: st);

      // Repli : dossier public (mêmes règles que la création).
      if (e.toString().contains('permission') || e.toString().contains('rule')) {
        return _uploadToPublicFolder(restaurantId);
      }
      rethrow;
    }
  }

  Future<String?> _uploadToPublicFolder(String restaurantId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'public_restaurant_${restaurantId}_$timestamp.jpg';
      AppLogger.w('Repli upload → public_images/$fileName', tag: _tag);

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('public_images')
          .child(fileName);

      await storageRef.putData(
        _newImageBytes!,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await storageRef.getDownloadURL();
      AppLogger.i('Image uploadée (public): $url', tag: _tag);
      return url;
    } catch (e, st) {
      AppLogger.e('Échec upload public', tag: _tag, error: e, stackTrace: st);
      return null;
    }
  }

  // ==================== SUBMIT ====================

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      AppLogger.w('Formulaire invalide', tag: _tag);
      return;
    }

    setState(() => _isLoading = true);
    AppLogger.i('===== DÉBUT MISE À JOUR RESTAURANT =====', tag: _tag);

    try {
      final id = widget.restaurant.id;

      // 1. Upload de la nouvelle image si l'utilisateur en a choisi une.
      String? imageUrl = _currentImageUrl;
      if (_newImageBytes != null) {
        final uploaded = await _uploadImage(id);
        if (uploaded != null) {
          imageUrl = uploaded;
        } else {
          AppLogger.w(
            'Nouvelle image NON uploadée, conservation de l\'ancienne',
            tag: _tag,
          );
          _showSnack(
            'Image non uploadée (vérifiez les règles Storage). '
            'Les autres champs seront enregistrés.',
            Colors.orange,
          );
        }
      }

      // 2. Construire les données à mettre à jour (camelCase).
      final description = _descriptionController.text.trim();
      final data = <String, dynamic>{
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.replaceAll(' ', ''),
        'address': _addressController.text.trim(),
        'description': description.isEmpty ? null : description,
        'latitude': double.parse(_latitudeController.text.trim()),
        'longitude': double.parse(_longitudeController.text.trim()),
        'imageUrl': imageUrl,
        'isActive': _isActive,
      };

      AppLogger.d('Données mises à jour: $data', tag: _tag);
      await _restaurantService.updateRestaurant(id, data);
      AppLogger.i('===== MISE À JOUR RÉUSSIE =====', tag: _tag);

      if (!mounted) return;

      // Restaurant mis à jour renvoyé à l'écran précédent pour rafraîchir l'UI.
      final updated = widget.restaurant.copyWith(
        name: data['name'] as String,
        phone: data['phone'] as String,
        address: data['address'] as String,
        description: data['description'] as String?,
        latitude: data['latitude'] as double,
        longitude: data['longitude'] as double,
        imageUrl: imageUrl,
        isActive: _isActive,
        updatedAt: DateTime.now(),
      );

      _showSnack('Restaurant mis à jour', successColor);
      Navigator.pop(context, updated);
    } catch (e, st) {
      AppLogger.e('Erreur mise à jour restaurant',
          tag: _tag, error: e, stackTrace: st);
      if (mounted) {
        _showSnack('Erreur: $e', errorColor);
      }
    } finally {
      AppLogger.i('===== FIN MISE À JOUR =====', tag: _tag);
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le Restaurant'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(largePadding),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(largePadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informations du restaurant',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: largePadding),

                      // SECTION IMAGE
                      Center(child: _buildImageSection()),
                      const SizedBox(height: largePadding),

                      // Nom
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom du restaurant *',
                          prefixIcon: Icon(Icons.restaurant),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le nom est requis';
                          }
                          if (value.length < 3) {
                            return 'Au moins 3 caractères';
                          }
                          if (value.length > 50) {
                            return 'Maximum 50 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: defaultPadding),

                      // Email (lecture seule, informatif)
                      TextFormField(
                        initialValue: widget.restaurant.email,
                        readOnly: true,
                        enabled: false,
                        decoration: const InputDecoration(
                          labelText: 'Email (non modifiable)',
                          prefixIcon: Icon(Icons.email),
                          helperText:
                              'L\'email de connexion ne peut pas être changé ici',
                        ),
                      ),
                      const SizedBox(height: defaultPadding),

                      // Téléphone
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone *',
                          hintText: '+25377123456',
                          prefixIcon: Icon(Icons.phone),
                          helperText: 'Format: +253 + 8 chiffres',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le téléphone est requis';
                          }
                          final cleanValue = value.replaceAll(' ', '');
                          final phoneRegex = RegExp(r'^\+253[0-9]{8}$');
                          if (!phoneRegex.hasMatch(cleanValue)) {
                            return 'Format invalide. Ex: +25377123456';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          if (value.isNotEmpty && !value.startsWith('+253')) {
                            _phoneController.text = '+253$value';
                            _phoneController.selection =
                                TextSelection.fromPosition(
                              TextPosition(offset: _phoneController.text.length),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: defaultPadding),

                      // Adresse
                      TextFormField(
                        controller: _addressController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Adresse *',
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'L\'adresse est requise';
                          }
                          if (value.length < 10) {
                            return 'L\'adresse doit être plus détaillée';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: defaultPadding),

                      // Latitude / Longitude
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latitudeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Latitude *',
                                prefixIcon: Icon(Icons.pin_drop),
                              ),
                              validator: (value) {
                                final lat = double.tryParse(value ?? '');
                                if (lat == null || lat < -90 || lat > 90) {
                                  return 'Latitude invalide (-90 à 90)';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: defaultPadding),
                          Expanded(
                            child: TextFormField(
                              controller: _longitudeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Longitude *',
                                prefixIcon: Icon(Icons.pin_drop),
                              ),
                              validator: (value) {
                                final lng = double.tryParse(value ?? '');
                                if (lng == null || lng < -180 || lng > 180) {
                                  return 'Longitude invalide (-180 à 180)';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: defaultPadding),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description (optionnel)',
                          prefixIcon: Icon(Icons.description),
                        ),
                      ),
                      const SizedBox(height: largePadding),

                      // Switch Actif
                      SwitchListTile(
                        title: const Text('Restaurant actif'),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                        activeTrackColor: successColor.withValues(alpha: 0.5),
                        activeThumbColor: successColor,
                      ),
                      const SizedBox(height: largePadding),

                      // Boutons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed:
                                _isLoading ? null : () => Navigator.pop(context),
                            child: const Text('Annuler'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _submit,
                            icon: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(
                                _isLoading ? 'Enregistrement...' : 'Enregistrer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    Widget preview;
    if (_newImageBytes != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(defaultRadius),
        child: Image.memory(_newImageBytes!, fit: BoxFit.cover),
      );
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(defaultRadius),
        child: Image.network(
          _currentImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              Icon(Icons.restaurant, size: 64, color: Colors.grey.shade400),
        ),
      );
    } else {
      preview = Icon(Icons.restaurant, size: 64, color: Colors.grey.shade400);
    }

    return Column(
      children: [
        Container(
          width: 150,
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(defaultRadius),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: preview,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickImage,
          icon: const Icon(Icons.add_photo_alternate),
          label: Text(
            (_currentImageUrl != null || _newImageBytes != null)
                ? 'Changer l\'image'
                : 'Ajouter une image',
          ),
        ),
        if (_newImageName != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _newImageName!,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }
}
