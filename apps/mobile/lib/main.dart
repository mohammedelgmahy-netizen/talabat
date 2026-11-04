import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');

  if (!Env.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseKey,
    postgrestOptions: const PostgrestClientOptions(schema: Env.dbSchema),
  );
  runApp(const ProviderScope(child: DeliveryApp()));
}

class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Missing Supabase config.\nRun with:\n--dart-define=SUPABASE_URL=...\n--dart-define=SUPABASE_KEY=...',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
}
