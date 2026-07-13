import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../../constants.dart';

/// Modification d'un chauffeur existant (profil Firestore : identité +
/// véhicule + statut + photo). Ne touche **pas** au compte Firebase Auth ni au
/// mot de passe.
class EditDriverScreen extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic> data;

  const EditDriverScreen({
    super.key,
    required this.driverId,
    required this.data,
  });

  @override
  State<EditDriverScreen> createState() => _EditDriverScreenState();
}

class _EditDriverScreenState extends State<EditDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _licensePlateController;
  late final TextEditingController _licenseNumberController;
  late final TextEditingController _vehicleBrandController;
  late final TextEditingController _vehicleModelController;
  late final TextEditingController _vehicleYearController;
  late final TextEditingController _vehicleColorController;

  static const _vehicleTypes = ['Standard', 'Comfort', 'Van'];
  String _vehicleType = 'Standard';
  bool _isActive = true;
  bool _isLoading = false;

  String? _existingPhotoUrl;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    final d = widget.data;
    _nameController = TextEditingController(text: (d['name'] ?? '').toString());
    _emailController = TextEditingController(text: (d['email'] ?? '').toString());
    _phoneController = TextEditingController(text: (d['phone'] ?? '').toString());
    _licensePlateController =
        TextEditingController(text: (d['licensePlate'] ?? '').toString());
    _licenseNumberController =
        TextEditingController(text: (d['licenseNumber'] ?? '').toString());
    _vehicleBrandController =
        TextEditingController(text: (d['vehicleBrand'] ?? '').toString());
    _vehicleModelController =
        TextEditingController(text: (d['vehicleModel'] ?? '').toString());
    _vehicleYearController = TextEditingController(
        text: d['vehicleYear'] == null ? '' : d['vehicleYear'].toString());
    _vehicleColorController =
        TextEditingController(text: (d['vehicleColor'] ?? '').toString());
    final t = (d['vehicleType'] ?? 'Standard').toString();
    _vehicleType = _vehicleTypes.contains(t) ? t : 'Standard';
    _isActive = d['isActive'] ?? true;
    _existingPhotoUrl = d['photoUrl']?.toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _licensePlateController.dispose();
    _licenseNumberController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Image trop grande (max 5MB)'),
            backgroundColor: warningColor,
          ));
        }
        return;
      }
      setState(() => _imageBytes = bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur sélection image: $e'),
          backgroundColor: errorColor,
        ));
      }
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageBytes == null) return _existingPhotoUrl;
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref()
          .child('drivers')
          .child('driver_${widget.driverId}_$ts.jpg');
      await ref.putData(
          _imageBytes!, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (_) {
      return _existingPhotoUrl;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final photoUrl = await _uploadImage();
      await _firestore.collection('drivers').doc(widget.driverId).update({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.replaceAll(' ', ''),
        'photoUrl': photoUrl,
        'vehicleType': _vehicleType,
        'licensePlate': _licensePlateController.text.trim().toUpperCase(),
        'licenseNumber': _licenseNumberController.text.trim().toUpperCase(),
        'vehicleBrand': _vehicleBrandController.text.trim().isEmpty
            ? null
            : _vehicleBrandController.text.trim(),
        'vehicleModel': _vehicleModelController.text.trim().isEmpty
            ? null
            : _vehicleModelController.text.trim(),
        'vehicleYear': _vehicleYearController.text.trim().isEmpty
            ? null
            : int.tryParse(_vehicleYearController.text.trim()),
        'vehicleColor': _vehicleColorController.text.trim().isEmpty
            ? null
            : _vehicleColorController.text.trim(),
        'isActive': _isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Erreur lors de la modification: $e'),
          backgroundColor: errorColor,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le Chauffeur'), elevation: 0),
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            padding: const EdgeInsets.all(largePadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionHeader(Icons.photo_camera, 'Photo du chauffeur'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(largePadding),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius:
                                    BorderRadius.circular(defaultRadius),
                                border:
                                    Border.all(color: Colors.grey.shade300),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: _imageBytes != null
                                  ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                                  : (_existingPhotoUrl != null &&
                                          _existingPhotoUrl!.isNotEmpty)
                                      ? Image.network(_existingPhotoUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Icon(
                                              Icons.person,
                                              size: 64,
                                              color: Colors.grey.shade400))
                                      : Icon(Icons.person,
                                          size: 64,
                                          color: Colors.grey.shade400),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.add_photo_alternate),
                              label: const Text('Changer la photo'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: largePadding),
                  _sectionHeader(Icons.person, 'Informations personnelles'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(largePadding),
                      child: Column(
                        children: [
                          _field(
                            controller: _nameController,
                            label: 'Nom complet *',
                            icon: Icons.person,
                            validator: (v) => (v == null || v.trim().length < 3)
                                ? 'Nom requis (min. 3 caractères)'
                                : null,
                          ),
                          const SizedBox(height: defaultPadding),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  controller: _emailController,
                                  label: 'Email *',
                                  icon: Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'L\'email est requis';
                                    }
                                    if (!RegExp(r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+')
                                        .hasMatch(v.trim())) {
                                      return 'Email invalide';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: defaultPadding),
                              Expanded(
                                child: _field(
                                  controller: _phoneController,
                                  label: 'Téléphone *',
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                  validator: (v) {
                                    final c = (v ?? '').replaceAll(' ', '');
                                    if (!RegExp(r'^\+253[0-9]{8}$')
                                        .hasMatch(c)) {
                                      return 'Format: +25377XXXXXX';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: largePadding),
                  _sectionHeader(
                      Icons.directions_car, 'Informations du véhicule'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(largePadding),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: _vehicleType,
                            decoration: InputDecoration(
                              labelText: 'Type de véhicule *',
                              prefixIcon: const Icon(Icons.category),
                              filled: true,
                              fillColor: veloxSurfaceAlt,
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Standard', child: Text('Standard')),
                              DropdownMenuItem(
                                  value: 'Comfort', child: Text('Comfort')),
                              DropdownMenuItem(
                                  value: 'Van', child: Text('Van')),
                            ],
                            onChanged: (v) =>
                                setState(() => _vehicleType = v ?? 'Standard'),
                          ),
                          const SizedBox(height: defaultPadding),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  controller: _licensePlateController,
                                  label: 'Numéro de plaque *',
                                  icon: Icons.confirmation_number,
                                  validator: (v) =>
                                      (v == null || v.trim().length < 4)
                                          ? 'Plaque requise'
                                          : null,
                                ),
                              ),
                              const SizedBox(width: defaultPadding),
                              Expanded(
                                child: _field(
                                  controller: _licenseNumberController,
                                  label: 'Numéro de permis *',
                                  icon: Icons.credit_card,
                                  validator: (v) =>
                                      (v == null || v.trim().length < 6)
                                          ? 'Permis requis'
                                          : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: defaultPadding),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  controller: _vehicleBrandController,
                                  label: 'Marque (optionnel)',
                                  icon: Icons.business,
                                ),
                              ),
                              const SizedBox(width: defaultPadding),
                              Expanded(
                                child: _field(
                                  controller: _vehicleModelController,
                                  label: 'Modèle (optionnel)',
                                  icon: Icons.directions_car_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: defaultPadding),
                          Row(
                            children: [
                              Expanded(
                                child: _field(
                                  controller: _vehicleYearController,
                                  label: 'Année (optionnel)',
                                  icon: Icons.calendar_today,
                                  keyboardType: TextInputType.number,
                                  validator: (v) {
                                    if (v != null && v.trim().isNotEmpty) {
                                      final y = int.tryParse(v.trim());
                                      if (y == null ||
                                          y < 1990 ||
                                          y > DateTime.now().year + 1) {
                                        return 'Année invalide';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: defaultPadding),
                              Expanded(
                                child: _field(
                                  controller: _vehicleColorController,
                                  label: 'Couleur (optionnel)',
                                  icon: Icons.palette,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: largePadding),
                  _sectionHeader(Icons.settings, 'Statut du compte'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(largePadding),
                      child: SwitchListTile(
                        title: const Text('Chauffeur actif'),
                        subtitle: Text(_isActive
                            ? 'Le chauffeur peut recevoir des courses'
                            : 'Le compte est désactivé'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        activeThumbColor: successColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: largePadding),
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
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save),
                        label: Text(
                            _isLoading ? 'Enregistrement...' : 'Enregistrer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32, vertical: 18),
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
    );
  }

  Widget _sectionHeader(IconData icon, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, color: primaryColor, size: 24),
            const SizedBox(width: 12),
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textDarkColor)),
          ],
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: veloxSurfaceAlt,
      ),
      validator: validator,
    );
  }
}
