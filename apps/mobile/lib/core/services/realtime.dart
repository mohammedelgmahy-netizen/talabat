import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';

/// يرجع Stream يجيب البيانات أول مرة، ثم يعيد الجلب عند أي تغيير
/// في الجدول (عبر Supabase Realtime / WebSockets). الـ RLS بيتطبق على الأحداث.
Stream<T> liveQuery<T>({
  required SupabaseClient client,
  required String table,
  required Future<T> Function() fetch,
  PostgresChangeFilter? filter,
  Duration debounce = const Duration(milliseconds: 300),
}) {
  late StreamController<T> controller;
  RealtimeChannel? channel;
  Timer? timer;

  Future<void> load() async {
    try {
      final data = await fetch();
      if (!controller.isClosed) controller.add(data);
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
    }
  }

  controller = StreamController<T>(
    onListen: () {
      load();
      channel = client
          .channel('live:$table:${filter?.value ?? 'all'}:${DateTime.now().microsecondsSinceEpoch}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: Env.dbSchema,
            table: table,
            filter: filter,
            callback: (_) {
              timer?.cancel();
              timer = Timer(debounce, load);
            },
          )
          .subscribe();
    },
    onCancel: () async {
      timer?.cancel();
      if (channel != null) await client.removeChannel(channel!);
      await controller.close();
    },
  );
  return controller.stream;
}
