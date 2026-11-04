import type { MetadataRoute } from 'next';

export const dynamic = 'force-static';

const base = process.env.NEXT_PUBLIC_BASE_PATH || '';

// يخلي لوحة التحكم تتثبّت على الموبايل كأنها تطبيق (إضافة إلى الشاشة الرئيسية)
export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'طلبات | لوحة التحكم',
    short_name: 'طلبات',
    description: 'لوحة تحكم منصة التوصيل',
    lang: 'ar',
    dir: 'rtl',
    start_url: `${base}/`,
    scope: `${base}/`,
    display: 'standalone',
    background_color: '#fff7ed',
    theme_color: '#ea580c',
    icons: [
      { src: `${base}/icon-192.png`, sizes: '192x192', type: 'image/png', purpose: 'any' },
      { src: `${base}/icon-512.png`, sizes: '512x512', type: 'image/png', purpose: 'any' },
      { src: `${base}/icon-512.png`, sizes: '512x512', type: 'image/png', purpose: 'maskable' },
    ],
  };
}
