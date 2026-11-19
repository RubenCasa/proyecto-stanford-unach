import { Public_Sans } from 'next/font/google';
import 'leaflet/dist/leaflet.css';
import './globals.css';

const sans = Public_Sans({ subsets: ['latin'], weight: ['400', '500', '600', '700', '800'], display: 'swap', variable: '--font' });

export const metadata = {
  title: 'Delitos en Riobamba · Proyecto STANFORD',
  description: 'Pronóstico semanal y tendencia a 2029 de delitos explícitos (COIP) con datos del ECU 911 · Riobamba, con foco en Flores y Cubijíes · UNACH',
  robots: { index: false },
};
export const viewport = {
  width: 'device-width', initialScale: 1,
  themeColor: [{ media: '(prefers-color-scheme: light)', color: '#f6f4ef' }, { media: '(prefers-color-scheme: dark)', color: '#12171d' }],
};

export default function RootLayout({ children }) {
  return (
    <html lang="es" className={sans.variable} suppressHydrationWarning>
      <body>{children}</body>
    </html>
  );
}
