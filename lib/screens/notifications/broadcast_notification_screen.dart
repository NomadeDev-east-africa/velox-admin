import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../../constants.dart';

class _Audience {
  final String key;
  final String label;
  final IconData icon;
  const _Audience(this.key, this.label, this.icon);
}

const List<_Audience> _kAudiences = [
  _Audience('clients', 'Clients', Icons.people_outline),
  _Audience('restaurants', 'Restaurants', Icons.restaurant),
  _Audience('livreurs', 'Livreurs', Icons.delivery_dining),
  _Audience('drivers', 'Chauffeurs', Icons.local_taxi),
];

class BroadcastNotificationScreen extends StatefulWidget {
  const BroadcastNotificationScreen({super.key});

  @override
  State<BroadcastNotificationScreen> createState() =>
      _BroadcastNotificationScreenState();
}

class _BroadcastNotificationScreenState
    extends State<BroadcastNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final Set<String> _selectedAudiences = {};
  bool _isSending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAudiences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sélectionnez au moins une audience'),
          backgroundColor: errorColor,
        ),
      );
      return;
    }

    final audienceLabels = _kAudiences
        .where((a) => _selectedAudiences.contains(a.key))
        .map((a) => a.label)
        .join(', ');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer l\'envoi'),
        content: Text(
          'Envoyer cette notification à : $audienceLabels ?\n\n'
          'Cette action est irréversible et peut toucher un grand nombre '
          'd\'utilisateurs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: primaryColor),
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSending = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('sendBroadcastNotification')
          .call({
        'title': _titleController.text.trim(),
        'body': _bodyController.text.trim(),
        'audiences': _selectedAudiences.toList(),
      });

      if (!mounted) return;
      final data = Map<String, dynamic>.from(result.data as Map);
      await _showResultDialog(data);
      _titleController.clear();
      _bodyController.clear();
      setState(() => _selectedAudiences.clear());
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${e.message ?? e.code}'),
          backgroundColor: errorColor,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e'), backgroundColor: errorColor),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _showResultDialog(Map<String, dynamic> data) {
    final perAudience = Map<String, dynamic>.from(data['perAudience'] as Map);
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification envoyée'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final audience in _kAudiences)
              if (perAudience.containsKey(audience.key))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Builder(builder: (context) {
                    final stats =
                        Map<String, dynamic>.from(perAudience[audience.key] as Map);
                    return Text(
                      '${audience.label} : ${stats['sent']} envoyée(s), '
                      '${stats['failed']} échec(s) (${stats['targeted']} ciblé(s))',
                    );
                  }),
                ),
          ],
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          color: cardColor,
          child: Padding(
            padding: const EdgeInsets.all(largePadding),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Envoyer une notification', style: subheadingStyle),
                  const SizedBox(height: 4),
                  const Text(
                    'Diffusée en push (FCM) aux audiences sélectionnées.',
                    style: captionStyle,
                  ),
                  const SizedBox(height: largePadding),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Titre',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        Validators.validateRequired(value, 'Le titre'),
                  ),
                  const SizedBox(height: defaultPadding),
                  TextFormField(
                    controller: _bodyController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                    validator: (value) =>
                        Validators.validateRequired(value, 'Le message'),
                  ),
                  const SizedBox(height: defaultPadding),
                  const Text('Audiences', style: bodyStyle),
                  for (final audience in _kAudiences)
                    CheckboxListTile(
                      value: _selectedAudiences.contains(audience.key),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedAudiences.add(audience.key);
                          } else {
                            _selectedAudiences.remove(audience.key);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      activeColor: primaryColor,
                      secondary: Icon(audience.icon, color: textLightColor),
                      title: Text(audience.label),
                    ),
                  const SizedBox(height: largePadding),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isSending ? null : _send,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: veloxBlack,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: veloxBlack,
                              ),
                            )
                          : const Text('Envoyer'),
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
