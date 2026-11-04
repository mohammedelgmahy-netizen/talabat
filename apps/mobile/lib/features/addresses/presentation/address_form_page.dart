import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../core/service_area.dart';
import '../../../core/widgets/app_map.dart';
import '../../../core/widgets/common.dart';
import '../domain/address.dart';
import 'address_providers.dart';

/// إضافة/تعديل عنوان مع تحديد الموقع على الخريطة
class AddressFormPage extends ConsumerStatefulWidget {
  const AddressFormPage({super.key, this.initial});

  final Address? initial;

  @override
  ConsumerState<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends ConsumerState<AddressFormPage> {
  final _form = GlobalKey<FormState>();
  final _map = MapController();
  late final _line = TextEditingController(text: widget.initial?.addressLine);
  late final _building = TextEditingController(text: widget.initial?.building);
  late final _floor = TextEditingController(text: widget.initial?.floor);
  late final _apartment = TextEditingController(text: widget.initial?.apartment);
  late final _landmark = TextEditingController(text: widget.initial?.landmark);
  late String _label = widget.initial?.label ?? 'home';
  late bool _isDefault = widget.initial?.isDefault ?? false;
  late LatLng _point = widget.initial == null
      ? ServiceArea.fallback.center // وسط منطقة الشغل كنقطة بداية
      : LatLng(widget.initial!.latitude, widget.initial!.longitude);
  bool _busy = false;
  bool _gotGps = false;

  @override
  void initState() {
    super.initState();
    if (widget.initial == null) {
      ref.read(serviceAreaProvider.future).then((a) {
        if (!mounted || _gotGps) return;
        setState(() => _point = a.center);
        try {
          _map.move(a.center, 14);
        } catch (_) {}
      });
      _locateMe();
    }
  }

  @override
  void dispose() {
    for (final c in [_line, _building, _floor, _apartment, _landmark]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _locateMe() async {
    await runWithFeedback(context, () async {
      final p = await ref.read(locationServiceProvider).current();
      if (!mounted) return;
      _gotGps = true;
      setState(() => _point = p);
      _map.move(p, 16);
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await runWithFeedback(
      context,
      () => ref.read(addressRepositoryProvider).save(Address(
            id: widget.initial?.id,
            label: _label,
            addressLine: _line.text.trim(),
            building: _building.text.trim(),
            floor: _floor.text.trim(),
            apartment: _apartment.text.trim(),
            landmark: _landmark.text.trim(),
            latitude: _point.latitude,
            longitude: _point.longitude,
            isDefault: _isDefault,
          )),
      success: 'تم حفظ العنوان',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      ref.invalidate(addressesProvider);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.initial == null ? 'عنوان جديد' : 'تعديل العنوان')),
      body: Form(
        key: _form,
        child: ListView(
          children: [
            SizedBox(
              height: 260,
              child: Stack(
                children: [
                  AppMap(
                    controller: _map,
                    center: _point,
                    zoom: 16,
                    pins: [MapPin(point: _point, icon: Icons.location_on, color: Colors.red)],
                    onTap: (p) => setState(() => _point = p),
                  ),
                  PositionedDirectional(
                    bottom: 12,
                    end: 12,
                    child: FloatingActionButton.small(heroTag: 'locate', onPressed: _locateMe, child: const Icon(Icons.my_location)),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text('اضغط على الخريطة لتحديد موقعك بدقة', style: TextStyle(color: Colors.grey)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'home', label: Text('المنزل'), icon: Icon(Icons.home_outlined)),
                      ButtonSegment(value: 'work', label: Text('العمل'), icon: Icon(Icons.work_outline)),
                      ButtonSegment(value: 'other', label: Text('آخر'), icon: Icon(Icons.place_outlined)),
                    ],
                    selected: {_label},
                    onSelectionChanged: (s) => setState(() => _label = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _line,
                    decoration: const InputDecoration(labelText: 'الشارع والمنطقة'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: _building, decoration: const InputDecoration(labelText: 'عمارة'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _floor, decoration: const InputDecoration(labelText: 'دور'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextFormField(controller: _apartment, decoration: const InputDecoration(labelText: 'شقة'))),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(controller: _landmark, decoration: const InputDecoration(labelText: 'علامة مميزة (اختياري)')),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v),
                    title: const Text('العنوان الافتراضي'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(onPressed: _busy ? null : _save, child: const Text('حفظ العنوان')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
