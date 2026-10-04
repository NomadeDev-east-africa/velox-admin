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
    // Plat ancien : des choix viennent de recevoir un identifiant. On le
    // remonte tout de suite au parent, sinon une sauvegarde sans aucune
    // modification des options l'enregistrerait encore sans `id`.
    final hadMissingIds =
        widget.groups.any((g) => g.choices.any((c) => c.id == null));
    if (hadMissingIds) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _emit();
      });
    }
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

  void _removeGroup(_GroupDraft draft) {
    setState(() => _drafts.remove(draft));
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
        for (final draft in _drafts) _buildGroupCard(draft),
      ],
    );
  }

  Widget _buildGroupCard(_GroupDraft draft) {
    return Card(
      // Sans clé, Flutter apparie les cartes par position : supprimer un groupe
      // laisserait les champs de texte des groupes suivants afficher l'ancienne
      // valeur (l'`initialValue` n'est lu qu'à la première construction).
      key: ObjectKey(draft),
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
                  onPressed: () => _removeGroup(draft),
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
                // Plafond de sélection : seulement pour un groupe « multiple »
                // (un groupe « unique » vaut toujours 1 choix). 0 / vide = illimité.
                if (draft.type == OptionType.multiple)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Max :'),
                      const SizedBox(width: 6),
                      SizedBox(
                        width: 56,
                        child: TextFormField(
                          key: ValueKey('max_${draft.hashCode}'),
                          initialValue:
                              draft.maxChoices == 0 ? '' : draft.maxChoices.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            hintText: '∞',
                          ),
                          onChanged: (v) {
                            draft.maxChoices = int.tryParse(v) ?? 0;
                            _emit();
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const Divider(),
            // Chaque ligne est identifiée par son objet, jamais par son index :
            // c'est ce qui permet à Flutter de suivre le bon champ quand un
            // choix est supprimé au milieu de la liste. Les closures capturent
            // le `choice` lui-même, pour la même raison.
            for (final choice in draft.choices)
              Padding(
                key: ObjectKey(choice),
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        initialValue: choice.name,
                        decoration: InputDecoration(
                          labelText: draft.free ? 'Choix (gratuit)' : 'Choix',
                          isDense: true,
                        ),
                        onChanged: (v) {
                          choice.name = v;
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
                          initialValue:
                              choice.price == 0 ? '' : choice.price.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Supplément',
                            suffixText: 'FDJ',
                            isDense: true,
                          ),
                          onChanged: (v) {
                            choice.price = int.tryParse(v) ?? 0;
                            _emit();
                          },
                        ),
                      ),
                    ],
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Supprimer ce choix',
                      onPressed: () {
                        setState(() => draft.choices.remove(choice));
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
                  setState(() => draft.choices.add(_ChoiceDraft.create()));
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
  int maxChoices; // plafond de sélection (multiple) ; 0 = illimité
  List<_ChoiceDraft> choices;

  _GroupDraft({
    required this.name,
    required this.type,
    required this.required,
    required this.choices,
    this.free = false,
    this.maxChoices = 0,
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
        maxChoices: g.maxChoices,
        // Un groupe dont tous les choix sont à 0 est considéré « gratuit ».
        free: g.choices.isNotEmpty && g.choices.every((c) => c.price == 0),
        choices: g.choices.map(_ChoiceDraft.fromChoice).toList(),
      );

  OptionGroup toGroup() => OptionGroup(
        name: name.trim(),
        type: type,
        required: required,
        // Le plafond n'a de sens que pour un groupe multiple.
        maxChoices: type == OptionType.multiple ? maxChoices : 0,
        choices: choices
            .where((c) => c.name.trim().isNotEmpty)
            .map((c) => OptionChoice(
                  id: c.id,
                  name: c.name.trim(),
                  price: c.price,
                  available: c.available,
                ))
            .toList(),
      );
}

class _ChoiceDraft {
  /// Fixé une fois pour toutes : renommer ou changer le prix ne le touche pas.
  final String id;
  final bool available; // rupture posée par l'app resto, conservée telle quelle
  String name;
  int price;

  _ChoiceDraft._(this.id, this.name, this.price, this.available);

  /// Nouveau choix (« Ajouter un choix ») : nouvel identifiant.
  factory _ChoiceDraft.create() =>
      _ChoiceDraft._(OptionChoice.newId(), '', 0, true);

  /// Choix existant : garde son identifiant, ou en reçoit un s'il n'en avait
  /// pas (plat ancien) — attribué ici, une seule fois, pour rester stable
  /// entre deux émissions de l'éditeur.
  factory _ChoiceDraft.fromChoice(OptionChoice c) => _ChoiceDraft._(
      c.id ?? OptionChoice.newId(), c.name, c.price, c.available);
}
