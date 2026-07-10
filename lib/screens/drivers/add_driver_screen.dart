import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../constants.dart';
import '../../firebase_options.dart';

class AddDriverScreen extends StatefulWidget {
  const AddDriverScreen({super.key});

  @override
  State<AddDriverScreen> createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // Informations personnelles
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  // Informations véhicule
  final _licensePlateController = TextEditingController(); // Plaque
  final _licenseNumberController = TextEditingController(); // Permis
  final _vehicleBrandController = TextEditingController(); // Marque
  final _vehicleModelController = TextEditingController(); // Modèle
  final _vehicleYearController = TextEditingController(); // Année
  final _vehicleColorController = TextEditingController(); // Couleur

  String _vehicleType = 'Standard'; // Standard, Comfort, Van
  bool _isActive = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Image
  Uint8List? _imageBytes;
  String? _imageName;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _licensePlateController.dispose();
    _licenseNumberController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }

  // Choisir une image
  Future<void> _pickImage() async {
    try {
      print('📸 Début sélection image...');
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        print('✅ Fichier sélectionné: ${pickedFile.name}');
        final bytes = await pickedFile.readAsBytes();
        
        // Vérifier la taille (max 5MB)
        if (bytes.length > 5 * 1024 * 1024) {
          print('❌ Image trop grande: ${bytes.length} bytes');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Image trop grande (max 5MB)'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        
        setState(() {
          _imageBytes = bytes;
          _imageName = pickedFile.name;
        });
        print('✅ Image chargée: ${bytes.length} bytes');
      }
    } catch (e) {
      print('❌ Erreur sélection image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur sélection image: ${e.toString()}'),
            backgroundColor: errorColor,
          ),
        );
      }
    }
  }

  // Upload image vers Firebase Storage
  Future<String?> _uploadImage(String driverId) async {
    if (_imageBytes == null) {
      print('❌ Aucune image à uploader');
      return null;
    }

    try {
      print('🖼️ Début upload image pour chauffeur: $driverId');
      print('📏 Taille image: ${_imageBytes!.length} bytes');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'driver_${driverId}_$timestamp.jpg';
      
      print('📁 Chemin: drivers/$fileName');
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('drivers')
          .child(fileName);
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'driver_photo',
        },
      );

      print('⏫ Début upload vers Firebase Storage...');
      
      final uploadTask = storageRef.putData(_imageBytes!, metadata);

      final uploadSub = uploadTask.snapshotEvents.listen((taskSnapshot) {
        final progress = (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes) * 100;
        print('📊 Upload: ${progress.toStringAsFixed(1)}%');
      }, onError: (error) {
        print('🔥 Erreur pendant upload: $error');
      });

      final snapshot = await uploadTask;
      await uploadSub.cancel();
      print('✅ Upload terminé avec succès!');
      
      // Récupérer l'URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      print('🔗 URL générée: $downloadUrl');
      
      return downloadUrl;
      
    } catch (e, stackTrace) {
      print('🔥 ERREUR UPLOAD IMAGE: $e');
      print('📋 Stack trace: $stackTrace');
      
      // Solution alternative: Upload vers un dossier public
      if (e.toString().contains('permission') || e.toString().contains('rule')) {
        print('🔄 Tentative avec dossier public...');
        return await _uploadToPublicFolder(driverId);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur upload: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      return null;
    }
  }

  // Méthode alternative: Upload vers dossier public
  Future<String?> _uploadToPublicFolder(String driverId) async {
    try {
      print('🔄 Tentative upload vers dossier public...');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'public_driver_${driverId}_$timestamp.jpg';
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('public_images')
          .child(fileName);
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );
      
      await storageRef.putData(_imageBytes!, metadata);
      final url = await storageRef.getDownloadURL();
      print('✅ Upload réussi dans public_images: $url');
      return url;
    } catch (e) {
      print('❌ Échec upload public: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un Chauffeur'),
        elevation: 0,
      ),
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
                  // Section 1: Image du chauffeur
                  _buildSectionHeader(
                    icon: Icons.photo_camera,
                    title: 'Photo du chauffeur',
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(largePadding),
                      child: Center(
                        child: Column(
                          children: [
                            // Aperçu image
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(defaultRadius),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: _imageBytes != null
                                  ? ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(defaultRadius),
                                      child: Image.memory(
                                        _imageBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(
                                      Icons.person,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                            ),
                            const SizedBox(height: 12),

                            // Bouton choisir image
                            OutlinedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.add_photo_alternate),
                              label: Text(
                                _imageBytes != null
                                    ? 'Changer la photo'
                                    : 'Ajouter une photo',
                              ),
                            ),

                            if (_imageName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  children: [
                                    Text(
                                      _imageName!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    if (_imageBytes != null)
                                      Text(
                                        '${(_imageBytes!.length / 1024).toStringAsFixed(1)} KB',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: largePadding),

                  // Section 2: Informations personnelles
                  _buildSectionHeader(
                    icon: Icons.person,
                    title: 'Informations personnelles',
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(largePadding),
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _nameController,
                            label: 'Nom complet *',
                            icon: Icons.person,
                            hint: 'Ex: Mohamed Ahmed Hassan',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Le nom est requis';
                              }
                              if (value.length < 3) {
                                return 'Le nom doit contenir au moins 3 caractères';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: defaultPadding),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _emailController,
                                  label: 'Email *',
                                  icon: Icons.email,
                                  hint: 'chauffeur@velox.dj',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'L\'email est requis';
                                    }
                                    final emailRegex = RegExp(
                                      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
                                    );
                                    if (!emailRegex.hasMatch(value)) {
                                      return 'Email invalide';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: defaultPadding),
                              Expanded(
                                child: _buildTextField(
                                  controller: _phoneController,
                                  label: 'Téléphone *',
                                  icon: Icons.phone,
                                  hint: '+25377123456',
                                  keyboardType: TextInputType.phone,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Le téléphone est requis';
                                    }
                                    final cleanValue = value.replaceAll(' ', '');
                                    final phoneRegex = RegExp(r'^\+253[0-9]{8}$');
                                    if (!phoneRegex.hasMatch(cleanValue)) {
                                      return 'Format: +25377XXXXXX';
                                    }
                                    return null;
                                  },
                                  onChanged: (value) {
                                    if (value.isNotEmpty &&
                                        !value.startsWith('+253')) {
                                      _phoneController.text = '+253$value';
                                      _phoneController.selection =
                                          TextSelection.fromPosition(
                                        TextPosition(
                                            offset: _phoneController.text.length),
                                      );
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: defaultPadding),
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Mot de passe *',
                            icon: Icons.lock,
                            hint: 'Minimum 8 caractères',
                            obscureText: _obscurePassword,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed: () {
                                setState(
                                    () => _obscurePassword = !_obscurePassword);
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Le mot de passe est requis';
                              }
                              if (value.length < 8) {
                                return 'Minimum 8 caractères';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: largePadding),

                  // Section 3: Informations du véhicule
                  _buildSectionHeader(
                    icon: Icons.directions_car,
                    title: 'Informations du véhicule',
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(largePadding),
                      child: Column(
                        children: [
                          // Type de véhicule (DROPDOWN - 3 OPTIONS SEULEMENT)
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
                                value: 'Standard',
                                child: Row(
                                  children: [
                                    Icon(Icons.directions_car, size: 20),
                                    SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Standard'),
                                        Text(
                                          '4 places - Véhicule standard',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Comfort',
                                child: Row(
                                  children: [
                                    Icon(Icons.star, size: 20),
                                    SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Comfort'),
                                        Text(
                                          '4 places - Climatisé & confort',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'Van',
                                child: Row(
                                  children: [
                                    Icon(Icons.airport_shuttle, size: 20),
                                    SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Van'),
                                        Text(
                                          '7+ places - Groupes & familles',
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _vehicleType = value!);
                            },
                          ),

                          const SizedBox(height: defaultPadding),

                          // Plaque & Permis (REQUIS)
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _licensePlateController,
                                  label: 'Numéro de plaque *',
                                  icon: Icons.confirmation_number,
                                  hint: 'DJ-1234-AB',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'La plaque est requise';
                                    }
                                    if (value.length < 4) {
                                      return 'Numéro de plaque invalide';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: defaultPadding),
                              Expanded(
                                child: _buildTextField(
                                  controller: _licenseNumberController,
                                  label: 'Numéro de permis *',
                                  icon: Icons.credit_card,
                                  hint: 'DJ123456789',
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Le permis est requis';
                                    }
                                    if (value.length < 6) {
                                      return 'Numéro de permis invalide';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: defaultPadding),

                          // Marque & Modèle (OPTIONNEL)
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _vehicleBrandController,
                                  label: 'Marque (optionnel)',
                                  icon: Icons.business,
                                  hint: 'Ex: Toyota, Nissan',
                                ),
                              ),
                              const SizedBox(width: defaultPadding),
                              Expanded(
                                child: _buildTextField(
                                  controller: _vehicleModelController,
                                  label: 'Modèle (optionnel)',
                                  icon: Icons.directions_car_outlined,
                                  hint: 'Ex: Corolla, Sunny',
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: defaultPadding),

                          // Année & Couleur (OPTIONNEL)
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _vehicleYearController,
                                  label: 'Année (optionnel)',
                                  icon: Icons.calendar_today,
                                  hint: 'Ex: 2020',
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value != null && value.isNotEmpty) {
                                      final year = int.tryParse(value);
                                      if (year == null ||
                                          year < 1990 ||
                                          year > DateTime.now().year + 1) {
                                        return 'Année invalide';
                                      }
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: defaultPadding),
                              Expanded(
                                child: _buildTextField(
                                  controller: _vehicleColorController,
                                  label: 'Couleur (optionnel)',
                                  icon: Icons.palette,
                                  hint: 'Ex: Blanc, Noir',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: largePadding),

                  // Section 4: Statut
                  Card(
                    child: SwitchListTile(
                      title: const Text('Chauffeur actif'),
                      subtitle: const Text(
                        'Le chauffeur pourra recevoir des courses immédiatement',
                      ),
                      value: _isActive,
                      onChanged: (value) {
                        setState(() => _isActive = value);
                      },
                      activeThumbColor: successColor,
                    ),
                  ),

                  const SizedBox(height: largePadding),

                  // Avertissement règles Storage
                  if (_imageBytes != null)
                    Container(
                      padding: const EdgeInsets.all(defaultPadding),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(defaultRadius),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vérifiez les règles Firebase Storage',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Assurez-vous que votre utilisateur est dans la collection "admins"',
                                  style: TextStyle(
                                    color: Colors.orange.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: largePadding),

                  // Note informative
                  Container(
                    padding: const EdgeInsets.all(defaultPadding),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(defaultRadius),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Un compte sera créé avec cet email et mot de passe. '
                            'Le chauffeur pourra se connecter sur l\'application mobile Driver.',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: largePadding),

                  // Boutons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _submitForm,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check),
                        label:
                            Text(_isLoading ? 'Création...' : 'Créer le chauffeur'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 18,
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
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 24),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textDarkColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: veloxSurfaceAlt,
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      print('❌ Formulaire invalide');
      return;
    }

    setState(() => _isLoading = true);
    print('🔄 ===== DÉBUT CRÉATION CHAUFFEUR =====');

    FirebaseApp? secondaryApp;
    try {
      // 1. Créer le compte Firebase Auth via une app secondaire
      // (évite de déconnecter l'admin courant)
      print('1️⃣ Création compte Auth...');
      secondaryApp = await Firebase.initializeApp(
        name: 'driverCreation_${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final UserCredential userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final String driverId = userCredential.user!.uid;
      print('✅ Compte Auth créé avec ID: $driverId');

      // 2. Upload l'image SI elle existe
      String? photoUrl;
      if (_imageBytes != null) {
        print('\n2️⃣ Tentative upload photo...');
        print('📏 Taille image: ${_imageBytes!.length} bytes');
        
        photoUrl = await _uploadImage(driverId);
        
        if (photoUrl != null) {
          print('✅ Photo uploadée avec succès!');
          print('🔗 URL: $photoUrl');
        } else {
          print('⚠️ Photo NON uploadée (mais chauffeur créé)');
          print('ℹ️ Cause probable: règles Firebase Storage trop restrictives');
        }
      } else {
        print('ℹ️ Pas de photo sélectionnée');
      }

      // 3. Créer le document dans Firestore
      print('\n3️⃣ Création document Firestore...');
      
      // ✅ VERSION CORRIGÉE - TOUT EN CAMELCASE
      final driverData = {
        // Informations personnelles
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.replaceAll(' ', ''),
        'photoUrl': photoUrl,                                    // ✅ camelCase (au lieu de photo_url)
        
        // Véhicule - TOUT EN CAMELCASE
        'vehicleType': _vehicleType,                             // ✅ camelCase (au lieu de vehicle_type)
        'licensePlate': _licensePlateController.text.trim().toUpperCase(),  // ✅ camelCase (au lieu de license_plate)
        'licenseNumber': _licenseNumberController.text.trim().toUpperCase(), // ✅ camelCase (au lieu de license_number)
        'vehicleBrand': _vehicleBrandController.text.trim().isEmpty         // ✅ camelCase (au lieu de vehicle_brand)
            ? null
            : _vehicleBrandController.text.trim(),
        'vehicleModel': _vehicleModelController.text.trim().isEmpty         // ✅ camelCase (au lieu de vehicle_model)
            ? null
            : _vehicleModelController.text.trim(),
        'vehicleYear': _vehicleYearController.text.trim().isEmpty           // ✅ camelCase (au lieu de vehicle_year)
            ? null
            : int.tryParse(_vehicleYearController.text.trim()),
        'vehicleColor': _vehicleColorController.text.trim().isEmpty         // ✅ camelCase (au lieu de vehicle_color)
            ? null
            : _vehicleColorController.text.trim(),
        
        // Statut - TOUT EN CAMELCASE
        'isActive': _isActive,                                   // ✅ déjà camelCase
        'isOnline': false,                                       // ✅ camelCase (au lieu de is_online)
        'isAvailable': false,                                    // ✅ camelCase (au lieu de is_available)
        'currentLocation': null,                                 // ✅ camelCase (au lieu de current_location)
        
        // Stats - TOUT EN CAMELCASE
        'totalRides': 0,                                         // ✅ camelCase (au lieu de total_rides)
        'rating': 5.0,
        'totalEarnings': 0.0,                                    // ✅ camelCase (au lieu de total_earnings)
        'totalRatings': 0,                                       // ✅ camelCase (ajouté pour cohérence)
        
        // Dates - TOUT EN CAMELCASE
        'createdAt': FieldValue.serverTimestamp(),               // ✅ camelCase (au lieu de created_at)
        'lastActiveAt': null,                                    // ✅ camelCase (au lieu de last_active_at)
        'updatedAt': FieldValue.serverTimestamp(),               // ✅ camelCase (au lieu de updated_at)
        
        // Token FCM (initialisé à null)
        'fcmToken': null,                                        // ✅ déjà camelCase
        'tokenUpdatedAt': FieldValue.serverTimestamp(),          // ✅ déjà camelCase
      };

      print('📋 Données chauffeur (camelCase): $driverData');
      await _firestore.collection('drivers').doc(driverId).set(driverData);
      print('✅ Document Firestore créé');

      if (!mounted) return;

      // Succès !
      print('\n🎉 ===== CRÉATION RÉUSSIE =====');
      
      // Message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Chauffeur créé avec succès !',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text('Nom: ${_nameController.text}'),
              Text('Email: ${_emailController.text}'),
              if (photoUrl != null) 
                Text('✅ Photo uploadée', style: TextStyle(fontSize: 12)),
              if (photoUrl == null && _imageBytes != null)
                Text('⚠️ Photo non uploadée (voir règles Storage)', 
                     style: TextStyle(fontSize: 12, color: Colors.orange)),
            ],
          ),
          backgroundColor: successColor,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'OK',
            onPressed: () {},
            textColor: Colors.white,
          ),
        ),
      );

      Navigator.pop(context, true);
      
    } on FirebaseAuthException catch (e) {
      print('\n🔥 ERREUR AUTH: ${e.code}');
      String message = 'Erreur création';

      switch (e.code) {
        case 'email-already-in-use':
          message = 'Email déjà utilisé';
          break;
        case 'weak-password':
          message = 'Mot de passe trop faible';
          break;
        case 'invalid-email':
          message = 'Email invalide';
          break;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('\n🔥 ===== ERREUR CRITIQUE =====');
      print('❌ Type: ${e.runtimeType}');
      print('❌ Message: $e');
      print('📋 Stack trace: $stackTrace');
      
      if (!mounted) return;

      // Message d'erreur détaillé
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(width: 10),
              Text('Erreur de création'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Détails de l\'erreur:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    e.toString(),
                    style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
                SizedBox(height: 15),
                if (e.toString().contains('storage') || e.toString().contains('permission'))
                  Text(
                    '🔧 Solution: Modifiez les règles Firebase Storage temporairement',
                    style: TextStyle(color: Colors.orange.shade700),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Fermer'),
            ),
          ],
        ),
      );
      
    } finally {
      await secondaryApp?.delete();
      print('🏁 ===== FIN DU PROCESSUS =====\n');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}