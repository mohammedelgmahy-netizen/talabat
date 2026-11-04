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

// نسخة محفوظة من بيانات الحساب عشان اللوحة تفتح على طول من غير ما تستنى النت
const PKEY = 'talabat-profile';
function readCached(uid: string): Profile | null {
  try {
    const p = JSON.parse(localStorage.getItem(PKEY) || 'null') as Profile | null;
    return p && p.id === uid ? p : null;
  } catch {
    return null;
  }
}
function writeCached(p: Profile | null) {
  try {
    if (p) localStorage.setItem(PKEY, JSON.stringify(p));
    else localStorage.removeItem(PKEY);
  } catch {}
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const [loading, setLoading] = useState(true);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<Profile | null>(null);
  const [configError, setConfigError] = useState<string | null>(null);

  const loadProfile = useCallback(async (s: Session | null) => {
    if (!s) {
      setProfile(null);
      writeCached(null);
      return;
    }
    const { data, error } = await supabase().from('profiles').select('id, role, full_name, phone, email, status').eq('id', s.user.id).maybeSingle();
    if (error) {
      // لو النت وقع نسيب النسخة المحفوظة
      if (!readCached(s.user.id)) setProfile(null);
      return;
    }
    if (!data) {
      // حساب من برنامج تاني في نفس مشروع Supabase
      await supabase().auth.signOut();
      writeCached(null);
      setProfile(null);
      setSession(null);
      alert('الحساب ده مش مسجل في منصة طلبات');
      return;
    }
    setProfile(data as Profile);
    writeCached(data as Profile);
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
      const cached = data.session ? readCached(data.session.user.id) : null;
      if (cached) {
        setProfile(cached);
        setLoading(false);
        loadProfile(data.session);
        return;
      }
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
    writeCached(null);
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
