import type { Metadata, Viewport } from 'next';
import { AuthProvider } from '@/components/auth-provider';
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
      <body className="bg-gray-50 text-gray-900 antialiased">
        <AuthProvider>{children}</AuthProvider>
      </body>
    </html>
  );
}
