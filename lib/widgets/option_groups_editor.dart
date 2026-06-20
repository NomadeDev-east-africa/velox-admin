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

  void _removeGroup(int i) {
    setState(() => _drafts.removeAt(i));
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Options (formules, tailles, suppléments…)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: _addGroup,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Groupe'),
            ),
          ],
        ),
        if (_drafts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Aucune option. Ex : « Formule » (Seul/Menu), « Suppléments » (Emmental +100)…',
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
      color: Colors.grey.shade50,
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
            Row(
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
                        decoration: const InputDecoration(
                          labelText: 'Choix',
                          isDense: true,
                        ),
                        onChanged: (v) {
                          draft.choices[j].name = v;
                          _emit();
                        },
                      ),
                    ),
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
  List<_ChoiceDraft> choices;

  _GroupDraft({
    required this.name,
    required this.type,
    required this.required,
    required this.choices,
  });

  factory _GroupDraft.empty() => _GroupDraft(
        name: '',
        type: OptionType.multiple,
        required: false,
        choices: [],
      );

  factory _GroupDraft.fromGroup(OptionGroup g) => _GroupDraft(
        name: g.name,
        type: g.type,
        required: g.required,
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
