import type { Metadata, Viewport } from 'next';
import { AuthProvider } from '@/components/auth-provider';
import { InstallButton } from '@/components/install-button';
import './globals.css';

export const metadata: Metadata = {
  title: 'طلبات | لوحة التحكم',
  description: 'لوحة تحكم منصة التوصيل للإدارة وأصحاب المتاجر',
  appleWebApp: { capable: true, title: 'طلبات', statusBarStyle: 'default' },
  icons: { apple: `${process.env.NEXT_PUBLIC_BASE_PATH || ''}/icon-192.png` },
};

export const viewport: Viewport = { themeColor: '#ea580c' };

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="ar" dir="rtl">
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        {/* eslint-disable-next-line @next/next/no-page-custom-font */}
        <link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Cairo:wght@400;500;600;700;800&display=swap" />
      </head>
      <body className="text-gray-900 antialiased">
        <AuthProvider>{children}</AuthProvider>
        <InstallButton />
      </body>
    </html>
  );
}
