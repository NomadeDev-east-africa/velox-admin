import 'package:flutter/material.dart';
import '../../constants.dart';
import '../../models/taxi_pricing.dart';
import '../../services/taxi_pricing_service.dart';

class TaxiPricingScreen extends StatefulWidget {
  const TaxiPricingScreen({super.key});

  @override
  State<TaxiPricingScreen> createState() => _TaxiPricingScreenState();
}

class _TaxiPricingScreenState extends State<TaxiPricingScreen> {
  final _pricingService = TaxiPricingService();

  final _standardBasePrice = TextEditingController();
  final _standardIncludedKm = TextEditingController();
  final _standardPricePerKm = TextEditingController();

  final _comfortBasePrice = TextEditingController();
  final _comfortIncludedKm = TextEditingController();
  final _comfortPricePerKm = TextEditingController();

  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _standardBasePrice.dispose();
    _standardIncludedKm.dispose();
    _standardPricePerKm.dispose();
    _comfortBasePrice.dispose();
    _comfortIncludedKm.dispose();
    _comfortPricePerKm.dispose();
    super.dispose();
  }

  void _fillControllers(TaxiPricingConfig config) {
    _standardBasePrice.text = _formatNum(config.standard.basePrice);
    _standardIncludedKm.text = _formatNum(config.standard.includedKm);
    _standardPricePerKm.text = _formatNum(config.standard.pricePerKm);
    _comfortBasePrice.text = _formatNum(config.comfort.basePrice);
    _comfortIncludedKm.text = _formatNum(config.comfort.includedKm);
    _comfortPricePerKm.text = _formatNum(config.comfort.pricePerKm);
  }

  String _formatNum(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();

  double _parse(TextEditingController controller) => double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;

  TaxiPricingTier get _standardTier => TaxiPricingTier(
        basePrice: _parse(_standardBasePrice),
        includedKm: _parse(_standardIncludedKm),
        pricePerKm: _parse(_standardPricePerKm),
      );

  TaxiPricingTier get _comfortTier => TaxiPricingTier(
        basePrice: _parse(_comfortBasePrice),
        includedKm: _parse(_comfortIncludedKm),
        pricePerKm: _parse(_comfortPricePerKm),
      );

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _pricingService.savePricing(
        TaxiPricingConfig(standard: _standardTier, comfort: _comfortTier),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tarifs enregistrés'), backgroundColor: successColor),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: errorColor),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(defaultPadding),
          color: cardColor,
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Tarification des courses VTC (prix de prise en charge, km inclus et '
                  'prix par km au-delà) — appliquée en temps réel côté clients et backend.',
                  style: captionStyle,
                ),
              ),
              const SizedBox(width: defaultPadding),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: const Text('Enregistrer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<TaxiPricingConfig>(
            stream: _pricingService.watchPricing(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Erreur: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator(color: primaryColor));
              }
              if (!_initialized) {
                _fillControllers(snapshot.data!);
                _initialized = true;
              }

              final standardCard = _buildTierCard(
                title: 'Standard',
                icon: Icons.local_taxi_outlined,
                basePriceController: _standardBasePrice,
                includedKmController: _standardIncludedKm,
                pricePerKmController: _standardPricePerKm,
                tier: _standardTier,
              );
              final comfortCard = _buildTierCard(
                title: 'Confort',
                icon: Icons.airline_seat_recline_extra_outlined,
                basePriceController: _comfortBasePrice,
                includedKmController: _comfortIncludedKm,
                pricePerKmController: _comfortPricePerKm,
                tier: _comfortTier,
              );

              return SingleChildScrollView(
                padding: const EdgeInsets.all(defaultPadding),
                child: isMobile(context)
                    ? Column(
                        children: [
                          standardCard,
                          const SizedBox(height: defaultPadding),
                          comfortCard,
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: standardCard),
                          const SizedBox(width: defaultPadding),
                          Expanded(child: comfortCard),
                        ],
                      ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTierCard({
    required String title,
    required IconData icon,
    required TextEditingController basePriceController,
    required TextEditingController includedKmController,
    required TextEditingController pricePerKmController,
    required TaxiPricingTier tier,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor),
                const SizedBox(width: 8),
                Text(title, style: subheadingStyle),
              ],
            ),
            const SizedBox(height: defaultPadding),
            _numberField(
              controller: basePriceController,
              label: 'Prix de prise en charge (FDJ)',
            ),
            const SizedBox(height: mediumPadding),
            _numberField(
              controller: includedKmController,
              label: 'Km inclus dans ce prix',
            ),
            const SizedBox(height: mediumPadding),
            _numberField(
              controller: pricePerKmController,
              label: 'Prix par km au-delà (FDJ)',
            ),
            const SizedBox(height: defaultPadding),
            Container(
              padding: const EdgeInsets.all(mediumPadding),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(smallRadius),
              ),
              child: Text(
                'Aperçu : 5 km → ${tier.priceForDistance(5).toStringAsFixed(0)} FDJ · '
                '10 km → ${tier.priceForDistance(10).toStringAsFixed(0)} FDJ',
                style: captionStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField({required TextEditingController controller, required String label}) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: veloxSurfaceAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(smallRadius)),
      ),
    );
  }
}
