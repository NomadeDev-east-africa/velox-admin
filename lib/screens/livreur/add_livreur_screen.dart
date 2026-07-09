import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../constants.dart';
import '../../firebase_options.dart';

class AddLivreurScreen extends StatefulWidget {
  const AddLivreurScreen({super.key});

  @override
  State<AddLivreurScreen> createState() => _AddLivreurScreenState();
}

class _AddLivreurScreenState extends State<AddLivreurScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // Informations personnelles
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Informations moto
  final _licensePlateController = TextEditingController(); // Plaque moto
  final _vehicleBrandController = TextEditingController(); // Marque (Honda, Yamaha...)
  final _vehicleModelController = TextEditingController(); // Modèle
  final _vehicleYearController = TextEditingController(); // Année
  final _vehicleColorController = TextEditingController(); // Couleur

  bool _isActive = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Image
  Uint8List? _imageBytes;
  String? _imageName;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _licensePlateController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehicleYearController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }

  // Choisir une image
  Future<void> _pickImage() async {
    try {
      debugPrint('📸 Début sélection image...');
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        debugPrint('✅ Fichier sélectionné: ${pickedFile.name}');
        final bytes = await pickedFile.readAsBytes();

        // Vérifier la taille (max 5MB)
        if (bytes.length > 5 * 1024 * 1024) {
          debugPrint('❌ Image trop grande: ${bytes.length} bytes');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image trop grande (max 5MB)'),
                backgroundColor: warningColor,
              ),
            );
          }
          return;
        }

        setState(() {
          _imageBytes = bytes;
          _imageName = pickedFile.name;
        });
        debugPrint('✅ Image chargée: ${bytes.length} bytes');
      }
    } catch (e) {
      debugPrint('❌ Erreur sélection image: $e');
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
  Future<String?> _uploadImage(String livreurId) async {
    if (_imageBytes == null) {
      debugPrint('❌ Aucune image à uploader');
      return null;
    }

    try {
      debugPrint('🖼️ Début upload image pour livreur: $livreurId');
      debugPrint('📏 Taille image: ${_imageBytes!.length} bytes');

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'livreur_${livreurId}_$timestamp.jpg';

      debugPrint('📁 Chemin: livreurs/$fileName');

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('livreurs')
          .child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'livreur_photo',
        },
      );

      debugPrint('⏫ Début upload vers Firebase Storage...');

      final uploadTask = storageRef.putData(_imageBytes!, metadata);

      final uploadSub = uploadTask.snapshotEvents.listen((taskSnapshot) {
        final progress =
            (taskSnapshot.bytesTransferred / taskSnapshot.totalBytes) * 100;
        debugPrint('📊 Upload: ${progress.toStringAsFixed(1)}%');
      }, onError: (error) {
        debugPrint('🔥 Erreur pendant upload: $error');
      });

      final snapshot = await uploadTask;
      await uploadSub.cancel();
      debugPrint('✅ Upload terminé avec succès!');

      // Récupérer l'URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      debugPrint('🔗 URL générée: $downloadUrl');

      return downloadUrl;
    } catch (e, stackTrace) {
      debugPrint('🔥 ERREUR UPLOAD IMAGE: $e');
      debugPrint('📋 Stack trace: $stackTrace');

      // Solution alternative: Upload vers un dossier public
      if (e.toString().contains('permission') ||
          e.toString().contains('rule')) {
        debugPrint('🔄 Tentative avec dossier public...');
        return await _uploadToPublicFolder(livreurId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur upload: ${e.toString()}'),
            backgroundColor: errorColor,
          ),
        );
      }

      return null;
    }
  }

  // Méthode alternative: Upload vers dossier public
  Future<String?> _uploadToPublicFolder(String livreurId) async {
    try {
      debugPrint('🔄 Tentative upload vers dossier public...');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'public_livreur_${livreurId}_$timestamp.jpg';

      final storageRef = FirebaseStorage.instance
          .ref()
          .child('public_images')
          .child(fileName);

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
      );

      await storageRef.putData(_imageBytes!, metadata);
      final url = await storageRef.getDownloadURL();
      debugPrint('✅ Upload réussi dans public_images: $url');
      return url;
    } catch (e) {
      debugPrint('❌ Échec upload public: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un Livreur'),
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
                  // Info badge
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(defaultRadius),
                      border: Border.all(color: Colors.orange.withValues(alpha:0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Les livreurs sont pour le module Food (livraison de repas)',
                            style: TextStyle(color: Colors.orange),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: largePadding),

                  // Section 1: Photo du livreur
                  _buildSectionHeader(
                    icon: Icons.photo_camera,
                    title: 'Photo du livreur',
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
                                borderRadius:
                                    BorderRadius.circular(defaultRadius),
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
                                      Icons.delivery_dining,
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
                            hint: 'Ex: Ahmed Mohamed Ali',
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
                              const SizedBox(width: defaultPadding),
                              Expanded(
                                child: _buildTextField(
                                  controller: _emailController,
                                  label: 'Email (optionnel)',
                                  icon: Icons.email,
                                  hint: 'livreur@velox.dj',
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value != null && value.isNotEmpty) {
                                      final emailRegex = RegExp(
                                        r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
                                      );
                                      if (!emailRegex.hasMatch(value)) {
                                        return 'Email invalide';
                                      }
                                    }
                                    return null;
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

                  // Section 3: Informations Moto
                  _buildSectionHeader(
                    icon: Icons.motorcycle,
                    title: 'Informations Moto',
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(largePadding),
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _licensePlateController,
                            label: 'Numéro de plaque *',
                            icon: Icons.confirmation_number,
                            hint: 'Ex: DJ1234AB',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'La plaque est requise';
                              }
                              if (value.length < 4) {
                                return 'Numéro de plaque invalide';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              _licensePlateController.text = value.toUpperCase();
                              _licensePlateController.selection =
                                  TextSelection.fromPosition(
                                TextPosition(
                                    offset: _licensePlateController.text.length),
                              );
                            },
                          ),
                          const SizedBox(height: defaultPadding),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _vehicleBrandController,
                                  label: 'Marque (optionnel)',
                                  icon: Icons.badge,
                                  hint: 'Ex: Honda, Yamaha',
                                ),
                              ),
                              const SizedBox(width: defaultPadding),
                              Expanded(
                                child: _buildTextField(
                                  controller: _vehicleModelController,
                                  label: 'Modèle (optionnel)',
                                  icon: Icons.two_wheeler,
                                  hint: 'Ex: Wave, Cub',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: defaultPadding),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  controller: _vehicleYearController,
                                  label: 'Année (optionnel)',
                                  icon: Icons.calendar_today,
                                  hint: 'Ex: 2022',
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
                                  hint: 'Ex: Noir, Rouge',
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
                  _buildSectionHeader(
                    icon: Icons.settings,
                    title: 'Statut du compte',
                  ),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(largePadding),
                      child: SwitchListTile(
                        title: const Text('Compte actif'),
                        subtitle: Text(
                          _isActive
                              ? 'Le livreur peut se connecter à l\'application'
                              : 'Le compte est désactivé',
                        ),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() => _isActive = value);
                        },
                        activeThumbColor: successColor,
                      ),
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
                        label: Text(_isLoading ? 'Création...' : 'Créer le livreur'),
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
        fillColor: Colors.grey.shade50,
      ),
      validator: validator,
      onChanged: onChanged,
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      debugPrint('❌ Formulaire invalide');
      return;
    }

    setState(() => _isLoading = true);
    debugPrint('🔄 ===== DÉBUT CRÉATION LIVREUR =====');

    FirebaseApp? secondaryApp;
    try {
      // 1. Créer le compte Firebase Auth via une app secondaire
      // (évite de déconnecter l'admin courant)
      String livreurId;

      if (_emailController.text.trim().isNotEmpty) {
        debugPrint('1️⃣ Création compte Auth avec email...');
        secondaryApp = await Firebase.initializeApp(
          name: 'livreurCreation_${DateTime.now().millisecondsSinceEpoch}',
          options: DefaultFirebaseOptions.currentPlatform,
        );
        final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
        final UserCredential userCredential = await secondaryAuth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        livreurId = userCredential.user!.uid;
        debugPrint('✅ Compte Auth créé avec ID: $livreurId');
      } else {
        // Créer ID unique si pas d'email
        debugPrint('1️⃣ Pas d\'email, création ID Firestore...');
        final docRef = _firestore.collection('livreurs').doc();
        livreurId = docRef.id;
        debugPrint('✅ ID généré: $livreurId');
      }

      // 2. Upload l'image SI elle existe
      String? photoUrl;
      if (_imageBytes != null) {
        debugPrint('\n2️⃣ Tentative upload photo...');
        debugPrint('📏 Taille image: ${_imageBytes!.length} bytes');

        photoUrl = await _uploadImage(livreurId);

        if (photoUrl != null) {
          debugPrint('✅ Photo uploadée avec succès!');
          debugPrint('🔗 URL: $photoUrl');
        } else {
          debugPrint('⚠️ Photo NON uploadée (mais livreur créé)');
        }
      } else {
        debugPrint('ℹ️ Pas de photo sélectionnée');
      }

      // 3. Créer le document dans Firestore
      debugPrint('\n3️⃣ Création document Firestore...');
      
      // ✅ VERSION CORRIGÉE - TOUT EN CAMELCASE
      final livreurData = {
        // ── Identité ────────────────────────────────────────────────────────
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.replaceAll(' ', ''),
        if (_emailController.text.trim().isNotEmpty)
          'email': _emailController.text.trim(),
        'photoUrl': photoUrl,                           // ✅ camelCase

        // ── Véhicule (TOUT EN CAMELCASE) ────────────────────────────────────
        'licensePlate': _licensePlateController.text.trim().toUpperCase(), // ✅ camelCase
        'vehicleBrand': _vehicleBrandController.text.trim().isEmpty        // ✅ camelCase
            ? null
            : _vehicleBrandController.text.trim(),
        'vehicleModel': _vehicleModelController.text.trim().isEmpty        // ✅ camelCase
            ? null
            : _vehicleModelController.text.trim(),
        'vehicleYear': _vehicleYearController.text.trim().isEmpty          // ✅ camelCase
            ? null
            : int.tryParse(_vehicleYearController.text.trim()),
        'vehicleColor': _vehicleColorController.text.trim().isEmpty        // ✅ camelCase
            ? null
            : _vehicleColorController.text.trim(),
        'vehicleType': 'moto',                         // ✅ camelCase

        // ── Statut ──────────────────────────────────────────────────────────
        'isActive': _isActive,                         // ✅ camelCase
        'isOnline': false,                             // ✅ camelCase
        'isAvailable': false,                          // ✅ camelCase
        'currentLocation': null,                       // ✅ camelCase
        'currentOrderId': null,                        // ✅ camelCase

        // ── Stats ────────────────────────────────────────────────────────────
        'totalDeliveries': 0,                          // ✅ camelCase
        'totalEarnings': 0.0,                          // ✅ camelCase
        'rating': 5.0,

        // ── FCM (token rempli à la première connexion de l'app) ──────────────
        'fcmToken': null,
        'fcmTokenUpdatedAt': null,

        // ── Dates ────────────────────────────────────────────────────────────
        'createdAt': FieldValue.serverTimestamp(),     // ✅ camelCase
        'updatedAt': FieldValue.serverTimestamp(),     // ✅ camelCase
        'lastSeen': null,                              // ✅ camelCase
      };

      debugPrint('📋 Données livreur (camelCase): $livreurData');
      await _firestore.collection('livreurs').doc(livreurId).set(livreurData);
      debugPrint('✅ Document Firestore créé');

      if (!mounted) return;

      // Succès !
      debugPrint('\n🎉 ===== CRÉATION RÉUSSIE =====');

      // Message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Livreur créé avec succès !',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Nom: ${_nameController.text}'),
              Text('Plaque: ${_licensePlateController.text.toUpperCase()}'),
              if (photoUrl != null)
                const Text('✓ Photo uploadée')
              else
                const Text('⚠ Photo non uploadée (règles Storage restrictives)'),
            ],
          ),
          backgroundColor: successColor,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Retour à la liste
      Navigator.pop(context, true);
    } on FirebaseAuthException catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String errorMessage;
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'Cet email est déjà utilisé';
            break;
          case 'weak-password':
            errorMessage = 'Mot de passe trop faible (minimum 6 caractères)';
            break;
          case 'invalid-email':
            errorMessage = 'Format d\'email invalide';
            break;
          default:
            errorMessage = 'Erreur auth: ${e.message}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('🔥 ERREUR: $e');
      debugPrint('📋 Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Erreur lors de la création'),
            backgroundColor: errorColor,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      await secondaryApp?.delete();
    }
  }
}