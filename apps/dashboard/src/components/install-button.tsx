'use client';

import { useEffect, useState } from 'react';

type InstallEvent = Event & { prompt: () => Promise<void>; userChoice: Promise<unknown> };

/** زرار "تثبيت البرنامج" العائم زي سنام: بيظهر لوحده لما الموبايل يسمح بالتثبيت */
export function InstallButton() {
  const [evt, setEvt] = useState<InstallEvent | null>(null);

  useEffect(() => {
    if ('serviceWorker' in navigator && location.protocol === 'https:') {
      navigator.serviceWorker.register(`${process.env.NEXT_PUBLIC_BASE_PATH || ''}/sw.js`).catch(() => {});
    }
    const onPrompt = (e: Event) => {
      e.preventDefault();
      setEvt(e as InstallEvent);
    };
    const onInstalled = () => setEvt(null);
    window.addEventListener('beforeinstallprompt', onPrompt);
    window.addEventListener('appinstalled', onInstalled);
    return () => {
      window.removeEventListener('beforeinstallprompt', onPrompt);
      window.removeEventListener('appinstalled', onInstalled);
    };
  }, []);

  if (!evt) return null;
  return (
    <button
      onClick={async () => {
        await evt.prompt();
        try {
          await evt.userChoice;
        } catch {}
        setEvt(null);
      }}
      className="fixed bottom-6 left-3 z-[9999] flex items-center gap-2 rounded-full bg-orange-600 px-5 py-3 text-[15px] font-bold text-white shadow-xl"
    >
      ⬇ تثبيت البرنامج
    </button>
  );
}
