import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common.dart';
import '../domain/app_user.dart';
import 'session_controller.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.client;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final ok = await runWithFeedback(
      context,
      () => ref.read(authRepositoryProvider).signUp(
            email: _email.text,
            password: _password.text,
            fullName: _name.text,
            phone: _phone.text,
            role: _role,
          ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    // لو تأكيد البريد مفعّل في Supabase مش هيكون فيه جلسة لسه
    if (ok && !ref.read(authRepositoryProvider).isSignedIn) {
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تم إنشاء الحساب'),
          content: const Text('أرسلنا رابط تأكيد لبريدك الإلكتروني. أكّد الحساب ثم سجّل الدخول.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حساب جديد')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text('نوع الحساب', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SegmentedButton<UserRole>(
              segments: const [
                ButtonSegment(value: UserRole.client, label: Text('عميل'), icon: Icon(Icons.person)),
                ButtonSegment(value: UserRole.driver, label: Text('سائق'), icon: Icon(Icons.two_wheeler)),
                ButtonSegment(value: UserRole.storeOwner, label: Text('متجر'), icon: Icon(Icons.storefront)),
              ],
              selected: {_role},
              onSelectionChanged: (s) => setState(() => _role = s.first),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'الاسم بالكامل', prefixIcon: Icon(Icons.badge_outlined)),
              validator: (v) => (v == null || v.trim().length < 2) ? 'اكتب اسمك' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'رقم الموبايل', hintText: '+2010xxxxxxxx', prefixIcon: Icon(Icons.phone)),
              validator: (v) => RegExp(r'^\+?[0-9]{8,15}$').hasMatch(v?.trim() ?? '') ? null : 'رقم غير صحيح',
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
              validator: (v) => (v == null || !v.contains('@')) ? 'بريد غير صحيح' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline)),
              validator: (v) => (v == null || v.length < 6) ? '6 أحرف على الأقل' : null,
            ),
            if (_role == UserRole.driver) ...[
              const SizedBox(height: 12),
              const Text('حساب السائق يحتاج توثيق من الإدارة قبل استلام الطلبات.', style: TextStyle(color: Colors.grey)),
            ],
            if (_role == UserRole.storeOwner) ...[
              const SizedBox(height: 12),
              const Text('بعد التسجيل أضف بيانات متجرك من لوحة التحكم، وسيظهر للعملاء بعد موافقة الإدارة.',
                  style: TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('إنشاء الحساب'),
            ),
          ],
        ),
      ),
    );
  }
}
