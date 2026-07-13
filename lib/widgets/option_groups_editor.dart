import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/option_group.dart';

/// Éditeur réutilisable de groupes d'options (formules, tailles, suppléments…).
///
/// Travaille sur une copie locale modifiable et notifie le parent via [onChanged].
class OptionGroupsEditor extends StatefulWidget {
  final List<OptionGroup> groups;
  final ValueChanged<List<OptionGroup>> onChanged;

  const OptionGroupsEditor({
    super.key,
    required this.groups,
    required this.onChanged,
  });

  @override
  State<OptionGroupsEditor> createState() => _OptionGroupsEditorState();
}

class _OptionGroupsEditorState extends State<OptionGroupsEditor> {
  late List<_GroupDraft> _drafts;

  @override
  void initState() {
    super.initState();
    _drafts = widget.groups.map(_GroupDraft.fromGroup).toList();
  }

  void _emit() {
    widget.onChanged(_drafts.map((d) => d.toGroup()).toList());
  }

  void _addGroup() {
    setState(() => _drafts.add(_GroupDraft.empty()));
    _emit();
  }

  void _addFreeGroup(String name) {
    setState(() => _drafts.add(_GroupDraft.free(name)));
    _emit();
  }

  void _removeGroup(int i) {
    setState(() => _drafts.removeAt(i));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Options (formules, tailles, suppléments…)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              onPressed: _addGroup,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Groupe'),
            ),
            TextButton.icon(
              onPressed: () => _addFreeGroup('Sauces'),
              icon: const Icon(Icons.local_dining, size: 18),
              label: const Text('Sauces (gratuit)'),
            ),
            TextButton.icon(
              onPressed: () => _addFreeGroup('Légumes'),
              icon: const Icon(Icons.eco, size: 18),
              label: const Text('Légumes (gratuit)'),
            ),
          ],
        ),
        if (_drafts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aucune option. Ex : « Formule » (Seul/Menu), « Suppléments » '
              '(Emmental +100), « Sauces »/« Légumes » gratuits au choix…',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ),
        for (int i = 0; i < _drafts.length; i++)
          _buildGroupCard(i, _drafts[i]),
      ],
    );
  }

  Widget _buildGroupCard(int index, _GroupDraft draft) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      // Fond sombre (thème) : un fond clair rendait le texte clair illisible.
      // veloxSurface est plus foncé que le fond des champs (veloxSurfaceAlt),
      // les champs ressortent donc bien.
      color: veloxSurface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: draft.name,
                    decoration: const InputDecoration(
                      labelText: 'Nom du groupe',
                      isDense: true,
                    ),
                    onChanged: (v) {
                      draft.name = v;
                      _emit();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<OptionType>(
                  value: draft.type,
                  items: const [
                    DropdownMenuItem(
                      value: OptionType.single,
                      child: Text('Choix unique'),
                    ),
                    DropdownMenuItem(
                      value: OptionType.multiple,
                      child: Text('Choix multiple'),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => draft.type = v ?? OptionType.multiple);
                    _emit();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: errorColor),
                  tooltip: 'Supprimer le groupe',
                  onPressed: () => _removeGroup(index),
                ),
              ],
            ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: draft.required,
                      onChanged: (v) {
                        setState(() => draft.required = v ?? false);
                        _emit();
                      },
                    ),
                    const Text('Obligatoire'),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: draft.free,
                      onChanged: (v) {
                        setState(() {
                          draft.free = v ?? false;
                          // Gratuit : on remet tous les suppléments à 0.
                          if (draft.free) {
                            for (final c in draft.choices) {
                              c.price = 0;
                            }
                          }
                        });
                        _emit();
                      },
                    ),
                    const Text('Gratuit (sans supplément)'),
                  ],
                ),
              ],
            ),
            const Divider(),
            for (int j = 0; j < draft.choices.length; j++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        initialValue: draft.choices[j].name,
                        decoration: InputDecoration(
                          labelText: draft.free ? 'Choix (gratuit)' : 'Choix',
                          isDense: true,
                        ),
                        onChanged: (v) {
                          draft.choices[j].name = v;
                          _emit();
                        },
                      ),
                    ),
                    // Champ prix masqué pour les groupes gratuits.
                    if (!draft.free) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          initialValue: draft.choices[j].price == 0
                              ? ''
                              : draft.choices[j].price.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Supplément',
                            suffixText: 'FDJ',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            draft.choices[j].price = int.tryParse(v) ?? 0;
                            _emit();
                          },
                        ),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        setState(() => draft.choices.removeAt(j));
                        _emit();
                      },
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() => draft.choices.add(_ChoiceDraft('', 0)));
                  _emit();
                },
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Ajouter un choix'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupDraft {
  String name;
  OptionType type;
  bool required;
  bool free; // choix gratuits (sans supplément) : masque le champ prix
  List<_ChoiceDraft> choices;

  _GroupDraft({
    required this.name,
    required this.type,
    required this.required,
    required this.choices,
    this.free = false,
  });

  factory _GroupDraft.empty() => _GroupDraft(
        name: '',
        type: OptionType.multiple,
        required: false,
        choices: [],
      );

  /// Groupe pré-configuré « gratuit » (sauces, légumes…) : multiple, non requis,
  /// choix sans supplément.
  factory _GroupDraft.free(String name) => _GroupDraft(
        name: name,
        type: OptionType.multiple,
        required: false,
        free: true,
        choices: [],
      );

  factory _GroupDraft.fromGroup(OptionGroup g) => _GroupDraft(
        name: g.name,
        type: g.type,
        required: g.required,
        // Un groupe dont tous les choix sont à 0 est considéré « gratuit ».
        free: g.choices.isNotEmpty && g.choices.every((c) => c.price == 0),
        choices:
            g.choices.map((c) => _ChoiceDraft(c.name, c.price)).toList(),
      );

  OptionGroup toGroup() => OptionGroup(
        name: name.trim(),
        type: type,
        required: required,
        choices: choices
            .where((c) => c.name.trim().isNotEmpty)
            .map((c) => OptionChoice(name: c.name.trim(), price: c.price))
            .toList(),
      );
}

class _ChoiceDraft {
  String name;
  int price;
  _ChoiceDraft(this.name, this.price);
}
