'use client';

import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import { must } from '@/lib/hooks';
import { DB_SCHEMA, supabase } from '@/lib/supabase';
import type { Store } from '@/lib/types';
import { useAuth } from './auth-provider';

interface StoreState {
  stores: Store[];
  store: Store | null;
  loading: boolean;
  select: (id: string) => void;
  reload: () => Promise<void>;
}

const Ctx = createContext<StoreState | null>(null);
const KEY = 'selected-store';

/** متاجر صاحب المتجر الحالي والمتجر المختار */
export function StoreProvider({ children }: { children: ReactNode }) {
  const { profile } = useAuth();
  const [stores, setStores] = useState<Store[]>([]);
  const [selected, setSelected] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  const reload = useCallback(async () => {
    if (!profile) return;
    const rows = must(await supabase().from('stores').select('*').eq('owner_id', profile.id).order('created_at')) as Store[];
    setStores(rows);
    setLoading(false);
  }, [profile]);

  useEffect(() => {
    try {
      setSelected(localStorage.getItem(KEY));
    } catch {
      /* تجاهل */
    }
    reload().catch(() => setLoading(false));
  }, [reload]);

  useEffect(() => {
    if (!profile) return;
    const client = supabase();
    const channel = client
      .channel(`my-stores-${profile.id}`)
      .on('postgres_changes', { event: '*', schema: DB_SCHEMA, table: 'stores', filter: `owner_id=eq.${profile.id}` }, () => reload())
      .subscribe();
    return () => {
      client.removeChannel(channel);
    };
  }, [profile, reload]);

  const select = (id: string) => {
    setSelected(id);
    try {
      localStorage.setItem(KEY, id);
    } catch {
      /* تجاهل */
    }
  };

  const store = stores.find((s) => s.id === selected) ?? stores[0] ?? null;
  return <Ctx.Provider value={{ stores, store, loading, select, reload }}>{children}</Ctx.Provider>;
}

export function useStore(): StoreState {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error('useStore must be used inside StoreProvider');
  return ctx;
}
