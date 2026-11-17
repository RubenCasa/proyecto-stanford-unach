import 'leaflet/dist/leaflet.css';
import './globals.css';

export const metadata = {
  title: 'Proyecto STANFORD · Tablero predictivo de delitos · Riobamba',
  description: 'Predicción de delitos explícitos (COIP) con datos del ECU 911 · Riobamba, Flores y Cubijíes · UNACH',
  robots: { index: false },
};
export const viewport = { width: 'device-width', initialScale: 1 };

export default function RootLayout({ children }) {
  return (
    <html lang="es">
      <body>{children}</body>
    </html>
  );
}
