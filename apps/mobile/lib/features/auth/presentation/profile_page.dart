import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/common.dart';
import 'session_controller.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late final _name = TextEditingController(text: ref.read(currentUserProvider).fullName);
  late final _phone = TextEditingController(text: ref.read(currentUserProvider).phone ?? '');
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await runWithFeedback(
      context,
      () => ref.read(authRepositoryProvider).updateProfile(fullName: _name.text, phone: _phone.text),
      success: 'تم الحفظ',
    );
    if (ok) await ref.read(sessionProvider).refresh();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          CircleAvatar(radius: 40, child: Text(user.fullName.isEmpty ? '?' : user.fullName.characters.first, style: const TextStyle(fontSize: 32))),
          const SizedBox(height: 8),
          Center(child: Text('${user.role.label} • ${user.email ?? ''}')),
          const SizedBox(height: 24),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم')),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'رقم الموبايل'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('حفظ')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => ref.read(sessionProvider).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
