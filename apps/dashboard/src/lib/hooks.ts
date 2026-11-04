'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { DB_SCHEMA, errorMessage, supabase } from './supabase';

/**
 * يجلب البيانات ثم يعيد الجلب تلقائياً عند أي تغيير في الجداول المحددة
 * (Supabase Realtime). الـ RLS بيتطبق على الأحداث اللي بتوصل.
 */
export function useLiveQuery<T>(
  fetcher: () => Promise<T>,
  deps: unknown[],
  realtime?: { table: string; filter?: string }[],
) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const fetcherRef = useRef(fetcher);
  useEffect(() => {
    fetcherRef.current = fetcher;
  });

  const load = useCallback(async () => {
    setLoading(true);
    try {
      const result = await fetcherRef.current();
      setData(result);
      setError(null);
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setLoading(false);
    }
  }, []);

  const realtimeKey = JSON.stringify(realtime ?? []);

  useEffect(() => {
    load();
    const tables: { table: string; filter?: string }[] = JSON.parse(realtimeKey);
    if (tables.length === 0) return;
    let timer: ReturnType<typeof setTimeout> | undefined;
    const client = supabase();
    let channel = client.channel(`live-${Math.random().toString(36).slice(2)}`);
    for (const t of tables) {
      channel = channel.on(
        'postgres_changes',
        { event: '*', schema: DB_SCHEMA, table: t.table, ...(t.filter ? { filter: t.filter } : {}) },
        () => {
          clearTimeout(timer);
          timer = setTimeout(load, 400);
        },
      );
    }
    channel.subscribe();
    return () => {
      clearTimeout(timer);
      client.removeChannel(channel);
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [load, realtimeKey, ...deps]);

  return { data, error, loading, reload: load, setData };
}

/** تنفيذ عملية مع حالة انتظار ورسالة خطأ */
export function useAction() {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const run = useCallback(async (fn: () => Promise<unknown>) => {
    setBusy(true);
    setError(null);
    try {
      await fn();
      return true;
    } catch (e) {
      setError(errorMessage(e));
      return false;
    } finally {
      setBusy(false);
    }
  }, []);
  return { busy, error, run, setError };
}

/** يرمي الخطأ لو استعلام Supabase رجع error */
export function must<T>(res: { data: T | null; error: { message: string } | null }): T {
  if (res.error) throw res.error;
  return res.data as T;
}
