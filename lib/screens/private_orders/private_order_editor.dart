import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../constants.dart';
import '../../models/private_order.dart';

/// Ouvre le formulaire de saisie (nouvelle commande ou [existing] à modifier).
Future<void> openPrivateOrderEditor(BuildContext context,
    {PrivateOrder? existing}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => PrivateOrderEditor(existing: existing),
  );
}

class _Line {
  final name = TextEditingController();
  final qty = TextEditingController(text: '1');
  final price = TextEditingController();
  final focus = FocusNode();

  _Line();

  _Line.from(PrivateOrderLine l) {
    name.text = l.name;
    qty.text = '${l.quantity}';
    price.text = _num(l.unitPrice);
  }

  static String _num(num v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  int get quantity => int.tryParse(qty.text.trim()) ?? 0;
  num get unitPrice => num.tryParse(price.text.trim().replaceAll(' ', '')) ?? 0;
  bool get isEmpty => name.text.trim().isEmpty;

  PrivateOrderLine toLine() => PrivateOrderLine(
      name: name.text.trim(), quantity: quantity, unitPrice: unitPrice);

  void dispose() {
    name.dispose();
    qty.dispose();
    price.dispose();
    focus.dispose();
  }
}

class _Option {
  final String id;
  final String name;
  const _Option(this.id, this.name);
}

class _Dish {
  final String name;
  final num price;
  const _Dish(this.name, this.price);
}

class PrivateOrderEditor extends StatefulWidget {
  final PrivateOrder? existing;
  const PrivateOrderEditor({super.key, this.existing});

  @override
  State<PrivateOrderEditor> createState() => _PrivateOrderEditorState();
}

class _PrivateOrderEditorState extends State<PrivateOrderEditor> {
  final _db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _money = NumberFormat('#,##0');

  final _clientName = TextEditingController();
  final _clientPhone = TextEditingController();
  final _address = TextEditingController();
  final _deliveryFee = TextEditingController(text: '0');
  final _notes = TextEditingController();
  final List<_Line> _lines = [];

  late DateTime _date;
  String _source = 'whatsapp';
  String _payment = 'cash';
  String _status = PrivateOrderStatus.pending;
  String? _restaurantId;
  String _restaurantName = '';
  String _livreurId = '';
  String _livreurName = '';

  List<_Option> _restaurants = [];
  List<_Option> _livreurs = [];
  List<_Dish> _dishes = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _date = e?.orderDate ?? DateTime.now();
    if (e != null) {
      _clientName.text = e.clientName;
      _clientPhone.text = e.clientPhone;
      _address.text = e.deliveryAddress;
      _deliveryFee.text = _Line._num(e.deliveryFee);
      _notes.text = e.notes;
      _source = e.source;
      _payment = e.paymentMethod;
      _status = e.status;
      _restaurantId = e.restaurantId.isEmpty ? null : e.restaurantId;
      _restaurantName = e.restaurantName;
      _livreurId = e.livreurId;
      _livreurName = e.livreurName;
      _lines.addAll(e.items.map(_Line.from));
    }
    if (_lines.isEmpty) _lines.add(_Line());
    _loadLists();
  }

  @override
  void dispose() {
    for (final c in [
      _clientName,
      _clientPhone,
      _address,
      _deliveryFee,
      _notes
    ]) {
      c.dispose();
    }
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  Future<void> _loadLists() async {
    try {
      final r = await _db.collection('restaurants').get();
      final l = await _db.collection('livreurs').get();
      _restaurants = r.docs
          .map((d) => _Option(d.id, (d.data()['name'] ?? '').toString()))
          .where((o) => o.name.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _livreurs = l.docs
          .map((d) => _Option(d.id, (d.data()['name'] ?? '').toString()))
          .where((o) => o.name.isNotEmpty)
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      // Restaurant supprimé depuis : on le garde dans la liste pour l'édition.
      if (_restaurantId != null &&
          !_restaurants.any((o) => o.id == _restaurantId)) {
        _restaurants.insert(0, _Option(_restaurantId!, _restaurantName));
      }
      if (_restaurantId != null) await _loadDishes(_restaurantId!);
    } catch (e) {
      _error = 'Chargement des listes impossible : $e';
    }
    if (mounted) setState(() => _loading = false);
  }

  /// Plats du restaurant, pour proposer nom + prix pendant la saisie.
  Future<void> _loadDishes(String restaurantId) async {
    final snap = await _db
        .collection('menuItems')
        .where('restaurantId', isEqualTo: restaurantId)
        .get();
    _dishes = snap.docs
        .map((d) => _Dish((d.data()['name'] ?? '').toString(),
            (d.data()['price'] as num?) ?? 0))
        .where((d) => d.name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  num get _subtotal => _lines
      .where((l) => !l.isEmpty)
      .fold<num>(0, (s, l) => s + l.quantity * l.unitPrice);
  num get _fee =>
      num.tryParse(_deliveryFee.text.trim().replaceAll(' ', '')) ?? 0;

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(_date));
    setState(() => _date = DateTime(d.year, d.month, d.day,
        t?.hour ?? _date.hour, t?.minute ?? _date.minute));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final lines =
        _lines.where((l) => !l.isEmpty).map((l) => l.toLine()).toList();
    if (lines.isEmpty) {
      setState(() => _error = 'Ajoutez au moins un plat.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final order = PrivateOrder(
      id: widget.existing?.id ?? '',
      orderDate: _date,
      source: _source,
      clientName: _clientName.text.trim(),
      clientPhone: _clientPhone.text.trim(),
      deliveryAddress: _address.text.trim(),
      restaurantId: _restaurantId!,
      restaurantName: _restaurantName,
      items: lines,
      deliveryFee: _fee,
      livreurId: _livreurId,
      livreurName: _livreurName,
      paymentMethod: _payment,
      status: _status,
      notes: _notes.text.trim(),
      createdByEmail: widget.existing?.createdByEmail ??
          FirebaseAuth.instance.currentUser?.email ??
          '',
    );
    try {
      final col = _db.collection('privateOrders');
      final data = order.toMap()..['updatedAt'] = FieldValue.serverTimestamp();
      if (widget.existing == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await col.add(data);
      } else {
        await col.doc(order.id).update(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Enregistrement impossible : $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Nouvelle commande privée'
          : 'Modifier la commande privée'),
      content: SizedBox(
        width: 720,
        child: _loading
            ? const SizedBox(
                height: 200,
                child: Center(
                    child: CircularProgressIndicator(color: primaryColor)))
            : Form(
                key: _formKey,
                child: SingleChildScrollView(child: _form()),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _saving || _loading ? null : _save,
          style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor, foregroundColor: Colors.black),
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: textDarkColor)),
      );

  Widget _pair(Widget a, Widget b) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          const SizedBox(width: 12),
          Expanded(child: b),
        ],
      );

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(_error!, style: const TextStyle(color: errorColor)),
          ),
        _section('Commande'),
        _pair(
          InkWell(
            onTap: _pickDate,
            child: InputDecorator(
              decoration: const InputDecoration(
                  labelText: 'Date et heure', border: OutlineInputBorder()),
              child: Text(DateFormat('dd/MM/yyyy HH:mm').format(_date)),
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue: _source,
            decoration: const InputDecoration(
                labelText: 'Reçue par', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
              DropdownMenuItem(value: 'phone', child: Text('Téléphone')),
              DropdownMenuItem(value: 'other', child: Text('Autre')),
            ],
            onChanged: (v) => setState(() => _source = v ?? 'whatsapp'),
          ),
        ),
        const SizedBox(height: 12),
        _pair(
          DropdownButtonFormField<String>(
            initialValue: _restaurantId,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Restaurant *', border: OutlineInputBorder()),
            items: _restaurants
                .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                .toList(),
            validator: (v) => v == null ? 'Choisissez le restaurant' : null,
            onChanged: (v) async {
              if (v == null) return;
              setState(() {
                _restaurantId = v;
                _restaurantName =
                    _restaurants.firstWhere((r) => r.id == v).name;
                _dishes = [];
              });
              await _loadDishes(v);
              if (mounted) setState(() {});
            },
          ),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(
                labelText: 'Statut', border: OutlineInputBorder()),
            items: PrivateOrderStatus.all
                .map((s) => DropdownMenuItem(
                    value: s, child: Text(PrivateOrderStatus.label(s))))
                .toList(),
            onChanged: (v) =>
                setState(() => _status = v ?? PrivateOrderStatus.pending),
          ),
        ),
        _section('Client'),
        _pair(
          TextFormField(
            controller: _clientName,
            decoration: const InputDecoration(
                labelText: 'Nom du client', border: OutlineInputBorder()),
          ),
          TextFormField(
            controller: _clientPhone,
            decoration: const InputDecoration(
                labelText: 'Téléphone (WhatsApp)',
                border: OutlineInputBorder()),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _address,
          decoration: const InputDecoration(
              labelText: 'Adresse / quartier de livraison',
              border: OutlineInputBorder()),
        ),
        _section('Détail de la commande'),
        for (var i = 0; i < _lines.length; i++) _lineRow(i),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _lines.add(_Line())),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter un plat'),
          ),
        ),
        _section('Livraison et paiement'),
        _pair(
          TextFormField(
            controller: _deliveryFee,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
                labelText: 'Frais de livraison (FDJ)',
                border: OutlineInputBorder()),
            onChanged: (_) => setState(() {}),
          ),
          DropdownButtonFormField<String>(
            initialValue: _payment,
            decoration: const InputDecoration(
                labelText: 'Paiement', border: OutlineInputBorder()),
            items: PrivatePayment.all
                .map((p) => DropdownMenuItem(
                    value: p, child: Text(PrivatePayment.label(p))))
                .toList(),
            onChanged: (v) => setState(() => _payment = v ?? 'cash'),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue:
              _livreurs.any((l) => l.id == _livreurId) ? _livreurId : '',
          isExpanded: true,
          decoration: const InputDecoration(
              labelText: 'Livreur (optionnel)', border: OutlineInputBorder()),
          items: [
            const DropdownMenuItem(value: '', child: Text('— Aucun —')),
            ..._livreurs
                .map((l) => DropdownMenuItem(value: l.id, child: Text(l.name))),
          ],
          onChanged: (v) => setState(() {
            _livreurId = v ?? '';
            _livreurName = _livreurId.isEmpty
                ? ''
                : _livreurs.firstWhere((l) => l.id == _livreurId).name;
          }),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _notes,
          maxLines: 2,
          decoration: const InputDecoration(
              labelText: 'Notes (sauces, remarques…)',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(smallRadius),
          ),
          child: Column(
            children: [
              _totalRow('Prix menu', _subtotal),
              _totalRow('Frais de livraison', _fee),
              const Divider(),
              _totalRow('Total payé par le client', _subtotal + _fee,
                  bold: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _totalRow(String label, num v, {bool bold = false}) {
    final style = TextStyle(
        color: textDarkColor,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontSize: bold ? 16 : 14);
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text('${_money.format(v)} FDJ', style: style),
      ],
    );
  }

  Widget _lineRow(int i) {
    final line = _lines[i];
    return Padding(
      key: ObjectKey(line),
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: RawAutocomplete<_Dish>(
              textEditingController: line.name,
              focusNode: line.focus,
              displayStringForOption: (d) => d.name,
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                if (q.isEmpty) return const Iterable<_Dish>.empty();
                return _dishes
                    .where((d) => d.name.toLowerCase().contains(q))
                    .take(12);
              },
              onSelected: (d) => setState(() {
                line.price.text = _Line._num(d.price);
              }),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  color: cardColor,
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(maxHeight: 260, maxWidth: 380),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final d in options)
                          ListTile(
                            dense: true,
                            title: Text(d.name),
                            trailing: Text('${_money.format(d.price)} FDJ'),
                            onTap: () => onSelected(d),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              fieldViewBuilder: (context, ctrl, focus, onSubmit) =>
                  TextFormField(
                controller: ctrl,
                focusNode: focus,
                decoration: InputDecoration(
                  labelText: 'Plat',
                  hintText:
                      _dishes.isEmpty ? null : 'Tapez pour chercher au menu',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: TextFormField(
              controller: line.qty,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'Qté',
                  border: OutlineInputBorder(),
                  isDense: true),
              validator: (v) =>
                  !line.isEmpty && (int.tryParse(v ?? '') ?? 0) < 1
                      ? '≥ 1'
                      : null,
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: TextFormField(
              controller: line.price,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  labelText: 'Prix unit.',
                  suffixText: 'FDJ',
                  border: OutlineInputBorder(),
                  isDense: true),
              validator: (v) =>
                  !line.isEmpty && (v ?? '').trim().isEmpty ? 'Prix ?' : null,
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            tooltip: 'Retirer',
            onPressed: _lines.length == 1
                ? null
                : () => setState(() => _lines.removeAt(i).dispose()),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
