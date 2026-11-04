'use client';

import { useEffect, useState } from 'react';

type InstallEvent = Event & { prompt: () => Promise<void>; userChoice: Promise<unknown> };

const APK = 'https://github.com/mohammedelgmahy-netizen/talabat/releases/download/latest/talabat.apk';

/** زرار "تنزيل البرنامج" العائم زي سنام: ظاهر دايماً، يثبت اللوحة لو الموبايل يسمح، وإلا ينزل برنامج الأندرويد */
export function InstallButton() {
  const [evt, setEvt] = useState<InstallEvent | null>(null);
  const [hidden, setHidden] = useState(true);

  useEffect(() => {
    if ('serviceWorker' in navigator && location.protocol === 'https:') {
      navigator.serviceWorker.register(`${process.env.NEXT_PUBLIC_BASE_PATH || ''}/sw.js`).catch(() => {});
    }
    const onPrompt = (e: Event) => {
      e.preventDefault();
      setEvt(e as InstallEvent);
    };
    // لو فاتح من البرنامج المثبت خلاص، مفيش داعي للزرار
    setHidden(window.matchMedia('(display-mode: standalone)').matches || sessionStorage.getItem('talabat-hide-dl') === '1');
    const onInstalled = () => setHidden(true);
    window.addEventListener('beforeinstallprompt', onPrompt);
    window.addEventListener('appinstalled', onInstalled);
    return () => {
      window.removeEventListener('beforeinstallprompt', onPrompt);
      window.removeEventListener('appinstalled', onInstalled);
    };
  }, []);

  if (hidden) return null;
  const cls =
    'fixed bottom-6 left-3 z-[9999] flex items-center gap-2 rounded-full bg-orange-600 px-5 py-3 text-[15px] font-bold text-white shadow-xl';
  return (
    <div className="fixed bottom-6 left-3 z-[9999] flex items-center gap-1">
      {evt ? (
        <button
          onClick={async () => {
            await evt.prompt();
            try {
              await evt.userChoice;
            } catch {}
            setEvt(null);
          }}
          className={cls.replace('fixed bottom-6 left-3 z-[9999] ', '')}
        >
          ⬇ تنزيل البرنامج
        </button>
      ) : (
        <a href={APK} className={cls.replace('fixed bottom-6 left-3 z-[9999] ', '')}>
          ⬇ تنزيل البرنامج
        </a>
      )}
      <button
        aria-label="إخفاء"
        onClick={() => {
          try {
            sessionStorage.setItem('talabat-hide-dl', '1');
          } catch {}
          setHidden(true);
        }}
        className="flex size-8 items-center justify-center rounded-full bg-white text-sm font-bold text-gray-700 shadow"
      >
        ✕
      </button>
    </div>
  );
}
