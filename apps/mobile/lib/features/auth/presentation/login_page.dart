import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/common.dart';
import 'session_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await runWithFeedback(context, () => ref.read(authRepositoryProvider).signIn(email: _email.text, password: _password.text));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _forgot() async {
    if (_email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اكتب بريدك الإلكتروني أولاً')));
      return;
    }
    await runWithFeedback(context, () => ref.read(authRepositoryProvider).resetPassword(_email.text),
        success: 'تم إرسال رابط إعادة تعيين كلمة المرور لبريدك');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.delivery_dining, size: 80, color: theme.colorScheme.primary),
                  const SizedBox(height: 8),
                  Text('طلبات', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('سجّل دخولك للمتابعة', textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  ListenableBuilder(
                    listenable: ref.watch(sessionProvider),
                    builder: (_, _) {
                      final err = ref.read(sessionProvider).error;
                      return err == null
                          ? const SizedBox(height: 8)
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(err, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                            );
                    },
                  ),
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
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? '6 أحرف على الأقل' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(onPressed: _forgot, child: const Text('نسيت كلمة المرور؟')),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('دخول'),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => context.push('/register'), child: const Text('ليس لديك حساب؟ أنشئ حساباً جديداً')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
