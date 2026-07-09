import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../../constants.dart';
import '../../firebase_options.dart';
import '../../models/opening_hours.dart';
import '../../widgets/opening_hours_editor.dart';

class AddRestaurantScreen extends StatefulWidget {
  const AddRestaurantScreen({super.key});

  @override
  State<AddRestaurantScreen> createState() => _AddRestaurantScreenState();
}

class _AddRestaurantScreenState extends State<AddRestaurantScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // Contrôleurs
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  bool _isActive = true;
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Horaires d'ouverture (tous fermés par défaut)
  OpeningHours _openingHours = OpeningHours.empty();

  // Image
  Uint8List? _imageBytes;
  String? _imageName;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
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
  Future<String?> _uploadImage(String restaurantId) async {
    if (_imageBytes == null) {
      print('❌ Aucune image à uploader');
      return null;
    }

    try {
      print('🖼️ Début upload image pour restaurant: $restaurantId');
      print('📏 Taille image: ${_imageBytes!.length} bytes');
      
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'restaurant_${restaurantId}_$timestamp.jpg';
      
      print('📁 Chemin: restaurants/$fileName');
      
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('restaurants')
          .child(fileName);
      
      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedAt': DateTime.now().toIso8601String(),
          'type': 'restaurant_logo',
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
        return await _uploadToPublicFolder(restaurantId);
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
  Future<String?> _uploadToPublicFolder(String restaurantId) async {
    try {
      print('🔄 Tentative upload vers dossier public...');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'public_restaurant_${restaurantId}_$timestamp.jpg';
      
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
        title: const Text('Ajouter un Restaurant'),
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
                      // Titre
                      const Text(
                        'Informations du restaurant',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: largePadding),

                      // SECTION IMAGE
                      Center(
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
                                      Icons.restaurant,
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
                                    ? 'Changer l\'image'
                                    : 'Ajouter une image',
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

                      const SizedBox(height: largePadding),

                      // Nom du restaurant
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Nom du restaurant *',
                          hintText: 'Ex: Restaurant Le Palmier',
                          prefixIcon: Icon(Icons.restaurant),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le nom est requis';
                          }
                          if (value.length < 3) {
                            return 'Le nom doit contenir au moins 3 caractères';
                          }
                          if (value.length > 50) {
                            return 'Le nom ne doit pas dépasser 50 caractères';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: defaultPadding),

                      // Email
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email *',
                          hintText: 'restaurant@velox.dj',
                          prefixIcon: Icon(Icons.email),
                        ),
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
                      const SizedBox(height: defaultPadding),

                      // Mot de passe
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe *',
                          hintText: 'Minimum 8 caractères',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setState(() => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le mot de passe est requis';
                          }
                          if (value.length < 8) {
                            return 'Le mot de passe doit contenir au moins 8 caractères';
                          }
                          return null;
                        },
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
                            _phoneController.selection = TextSelection.fromPosition(
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
                          hintText: 'Rue de la République, Djibouti',
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

                      // Latitude et Longitude
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _latitudeController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Latitude *',
                                hintText: 'Ex: 11.5721',
                                prefixIcon: Icon(Icons.pin_drop),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'La latitude est requise';
                                }
                                final lat = double.tryParse(value);
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
                                hintText: 'Ex: 43.1456',
                                prefixIcon: Icon(Icons.pin_drop),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'La longitude est requise';
                                }
                                final lng = double.tryParse(value);
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
                          hintText: 'Décrivez votre restaurant...',
                          prefixIcon: Icon(Icons.description),
                        ),
                      ),
                      const SizedBox(height: largePadding),

                      // Horaires d'ouverture
                      OpeningHoursEditor(
                        value: _openingHours,
                        onChanged: (h) => _openingHours = h,
                      ),

                      const SizedBox(height: largePadding),

                      // Switch Actif
                      SwitchListTile(
                        title: const Text('Restaurant actif'),
                        subtitle: const Text(
                          'Le restaurant pourra recevoir des commandes immédiatement',
                        ),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() => _isActive = value);
                        },
                        activeTrackColor: successColor.withValues(alpha:0.5),
                        activeThumbColor: successColor,
                      ),

                      const SizedBox(height: largePadding),

                      // Note
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
                                'Le restaurant pourra se connecter sur l\'application mobile.',
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
                            label: Text(_isLoading ? 'Création...' : 'Créer le restaurant'),
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      print('❌ Formulaire invalide');
      return;
    }

    setState(() => _isLoading = true);
    print('🔄 ===== DÉBUT CRÉATION RESTAURANT =====');

    FirebaseApp? secondaryApp;
    try {
      // 1. Créer le compte Firebase Auth via une app secondaire
      // (évite de déconnecter l'admin courant)
      print('1️⃣ Création compte Auth...');
      secondaryApp = await Firebase.initializeApp(
        name: 'restaurantCreation_${DateTime.now().millisecondsSinceEpoch}',
        options: DefaultFirebaseOptions.currentPlatform,
      );
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final UserCredential userCredential = await secondaryAuth.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      final String restaurantId = userCredential.user!.uid;
      print('✅ Compte Auth créé avec ID: $restaurantId');

      // 2. Upload l'image SI elle existe
      String? imageUrl;
      if (_imageBytes != null) {
        print('\n2️⃣ Tentative upload image...');
        print('📏 Taille image: ${_imageBytes!.length} bytes');
        
        imageUrl = await _uploadImage(restaurantId);
        
        if (imageUrl != null) {
          print('✅ Image uploadée avec succès!');
          print('🔗 URL: $imageUrl');
        } else {
          print('⚠️ Image NON uploadée (mais restaurant créé)');
        }
      } else {
        print('ℹ️ Pas d\'image sélectionnée');
      }

      // 3. Créer le document dans Firestore
      print('\n3️⃣ Création document Firestore...');
      
      // ✅ VERSION CORRIGÉE - TOUT EN CAMELCASE
      final restaurantData = {
        // Identité
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.replaceAll(' ', ''),
        'address': _addressController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        
        // Localisation
        'latitude': double.parse(_latitudeController.text.trim()),
        'longitude': double.parse(_longitudeController.text.trim()),
        
        // Image
        'imageUrl': imageUrl,                              // ✅ camelCase
        
        // Statut
        'isActive': _isActive,                             // ✅ camelCase
        'isOpen': false,                                   // ✅ camelCase

        // Horaires d'ouverture (camelCase, clés jours en anglais)
        'openingHours': _openingHours.toMap(),
        
        // Stats (initialisés à 0)
        'rating': 0.0,
        'totalOrders': 0,                                  // ✅ camelCase
        'totalRevenue': 0.0,                               // ✅ camelCase
        
        // FCM (sera mis à jour par l'app)
        'fcmToken': null,
        'fcmTokenUpdatedAt': null,
        
        // Dates
        'createdAt': FieldValue.serverTimestamp(),         // ✅ camelCase
        'updatedAt': FieldValue.serverTimestamp(),         // ✅ camelCase
      };

      print('📋 Données restaurant (camelCase): $restaurantData');
      await _firestore.collection('restaurants').doc(restaurantId).set(restaurantData);
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
                    'Restaurant créé avec succès !',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text('Nom: ${_nameController.text}'),
              Text('Email: ${_emailController.text}'),
              if (imageUrl != null) 
                Text('✅ Image uploadée', style: TextStyle(fontSize: 12)),
              if (imageUrl == null && _imageBytes != null)
                Text('⚠️ Image non uploadée (voir règles Storage)', 
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

      Navigator.pop(context);
      
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