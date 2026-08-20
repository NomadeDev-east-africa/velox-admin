import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../models/promo_code.dart';
import '../../models/restaurant.dart';
import '../../services/promo_code_service.dart';
import '../../services/restaurant_service.dart';

/// Formulaire de création/édition d'un code promo.
///
/// Passer [existing] pour éditer (le code lui-même n'est alors plus modifiable
/// puisqu'il sert de doc ID Firestore — supprimer/recréer si besoin de renommer).
class AddEditPromoCodeScreen extends StatefulWidget {
  final PromoCode? existing;

  const AddEditPromoCodeScreen({super.key, this.existing});

  @override
  State<AddEditPromoCodeScreen> createState() =>
      _AddEditPromoCodeScreenState();
}

class _AddEditPromoCodeScreenState extends State<AddEditPromoCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _promoCodeService = PromoCodeService();
  final _restaurantService = RestaurantService();

  late final TextEditingController _codeController;
  late final TextEditingController _valueController;

  PromoDiscountType _discountType = PromoDiscountType.percentage;
  String? _restaurantId; // null = global
  String? _restaurantName;
  DateTime? _expiresAt;
  bool _active = true;
  bool _isLoading = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _codeController = TextEditingController(text: existing?.code ?? '');
    _valueController = TextEditingController(
      text: existing != null ? existing.discountValue.toString() : '',
    );
    if (existing != null) {
      _discountType = existing.discountType;
      _restaurantId = existing.restaurantId;
      _restaurantName = existing.restaurantName;
      _expiresAt = existing.expiresAt;
      _active = existing.active;
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final code = PromoCodeService.normalizeCode(_codeController.text);
      final value = num.parse(_valueController.text.replaceAll(',', '.'));

      final promo = PromoCode(
        code: code,
        discountType: _discountType,
        discountValue: value,
        restaurantId: _restaurantId,
        restaurantName: _restaurantId != null ? _restaurantName : null,
        expiresAt: _expiresAt,
        active: _active,
      );

      if (_isEditing) {
        await _promoCodeService.updatePromoCode(code, promo.toMap());
      } else {
        await _promoCodeService.createPromoCode(promo);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le code promo' : 'Nouveau code promo'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(largePadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _codeController,
                    enabled: !_isEditing,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Code',
                      hintText: 'Ex: VLX3425',
                      prefixIcon: Icon(Icons.sell_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le code est requis';
                      }
                      final normalized = PromoCodeService.normalizeCode(value);
                      if (normalized.length < 6) {
                        return 'Au moins 6 caractères';
                      }
                      if (!RegExp(r'^[A-Z0-9]+$').hasMatch(normalized)) {
                        return 'Lettres et chiffres uniquement (pas d\'espace ni de symbole)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: defaultPadding),

                  // Type de réduction
                  const Text('Type de réduction', style: subheadingStyle),
                  const SizedBox(height: smallPadding),
                  SegmentedButton<PromoDiscountType>(
                    segments: const [
                      ButtonSegment(
                        value: PromoDiscountType.percentage,
                        label: Text('Pourcentage'),
                        icon: Icon(Icons.percent),
                      ),
                      ButtonSegment(
                        value: PromoDiscountType.fixed,
                        label: Text('Montant fixe'),
                        icon: Icon(Icons.attach_money),
                      ),
                    ],
                    selected: {_discountType},
                    onSelectionChanged: (selection) {
                      setState(() => _discountType = selection.first);
                    },
                  ),
                  const SizedBox(height: defaultPadding),

                  TextFormField(
                    controller: _valueController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _discountType == PromoDiscountType.percentage
                          ? 'Valeur (%)'
                          : 'Valeur (FDJ)',
                      prefixIcon: const Icon(Icons.discount_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La valeur est requise';
                      }
                      final parsed = num.tryParse(value.replaceAll(',', '.'));
                      if (parsed == null || parsed <= 0) {
                        return 'Valeur invalide';
                      }
                      if (_discountType == PromoDiscountType.percentage && parsed > 100) {
                        return 'Un pourcentage ne peut pas dépasser 100';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: largePadding),

                  // Portée : global ou restaurant précis
                  const Text('Portée', style: subheadingStyle),
                  const SizedBox(height: smallPadding),
                  StreamBuilder<List<Restaurant>>(
                    stream: _restaurantService.getRestaurants(),
                    builder: (context, snapshot) {
                      final restaurants = snapshot.data ?? [];
                      return DropdownButtonFormField<String?>(
                        initialValue: _restaurantId,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.storefront_outlined),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tous les restaurants'),
                          ),
                          ...restaurants.map(
                            (r) => DropdownMenuItem<String?>(
                              value: r.id,
                              child: Text(r.name, overflow: TextOverflow.ellipsis),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _restaurantId = value;
                            _restaurantName = value == null
                                ? null
                                : restaurants
                                    .firstWhere((r) => r.id == value)
                                    .name;
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: largePadding),

                  // Expiration
                  const Text("Date d'expiration", style: subheadingStyle),
                  const SizedBox(height: smallPadding),
                  InkWell(
                    onTap: _pickExpiryDate,
                    borderRadius: BorderRadius.circular(defaultRadius),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.event_outlined),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _expiresAt != null
                                ? Formatters.formatDate(_expiresAt!)
                                : 'Sans expiration',
                          ),
                          if (_expiresAt != null)
                            IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => setState(() => _expiresAt = null),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: defaultPadding),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Actif'),
                    subtitle: const Text('Un code inactif ne peut plus être utilisé'),
                    value: _active,
                    activeThumbColor: primaryColor,
                    onChanged: (value) => setState(() => _active = value),
                  ),
                  const SizedBox(height: largePadding),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: veloxBlack,
                              ),
                            )
                          : Text(_isEditing ? 'Enregistrer' : 'Créer le code'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
