'use client';

import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';
import { supabase } from '@/lib/supabase';
import type { Profile } from '@/lib/types';

interface AuthState {
  loading: boolean;
  session: Session | null;
  profile: Profile | null;
  configError: string | null;
  signOut: () => Promise<void>;
  reload: () => Promise<void>;
}

const AuthContext = createContext<AuthState | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [loading, setLoading] = useState(true);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [configError, setConfigError] = useState<string | null>(null);

  const loadProfile = useCallback(async (s: Session | null) => {
    if (!s) {
      setProfile(null);
      return;
    }
    const { data, error } = await supabase().from('profiles').select('id, role, full_name, phone, email, status').eq('id', s.user.id).maybeSingle();
    if (error) {
      setProfile(null);
      return;
    }
    if (!data) {
      // حساب من برنامج تاني في نفس مشروع Supabase
      await supabase().auth.signOut();
      setProfile(null);
      setSession(null);
      alert('الحساب ده مش مسجل في منصة طلبات');
      return;
    }
    setProfile(data as Profile);
  }, []);

  useEffect(() => {
    let client;
    try {
      client = supabase();
    } catch (e) {
      setConfigError((e as Error).message);
      setLoading(false);
      return;
    }
    client.auth.getSession().then(async ({ data }) => {
      setSession(data.session);
      await loadProfile(data.session);
      setLoading(false);
    });
    const { data: sub } = client.auth.onAuthStateChange((_event, s) => {
      setSession(s);
      // تأجيل الاستعلام خارج callback الخاص بـ Supabase لتجنب deadlock
      setTimeout(() => loadProfile(s), 0);
    });
    return () => sub.subscription.unsubscribe();
  }, [loadProfile]);

  const signOut = useCallback(async () => {
    await supabase().auth.signOut();
    setProfile(null);
  }, []);

  const reload = useCallback(() => loadProfile(session), [loadProfile, session]);

  return (
    <AuthContext.Provider value={{ loading, session, profile, configError, signOut, reload }}>{children}</AuthContext.Provider>
  );
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}
