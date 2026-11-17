# Tablero predictivo · Proyecto STANFORD (versión Next.js)

Next.js 15 (App Router) + React 19 + Leaflet. Rutas de API en `app/api/*` (funciones serverless de Vercel).
Solo usa resultados agregados (sin datos personales ni de Fiscalía).

## Estructura
- `app/page.js` — el servidor entrega los datos y las alertas iniciales.
- `app/api/{datos,pronostico,tendencia,mapa,resumen}/route.js` — API (`/api/pronostico?umbral=25`, `/api/tendencia?parroquia=CUBIJIES`…).
- `components/Dashboard.jsx` — pantalla (inicio guiado, alertas, tendencia, modelos, abigeato), buscador Ctrl+K, modo oscuro.
- `components/MapaVivo.jsx` — mapa real (calles / oscuro / satélite), línea de tiempo y panel por parroquia.
- `lib/logica.js` — cálculos compartidos por la API y el navegador.
- `data/data.json` — datos (se regeneran con `python dashboard_web/actualizar_datos.py`).

## Probar en el computador (necesita Node 18+)
```
cd dashboard_next
npm install
npm run dev        # http://localhost:3000
```

## Publicar en Vercel
1. Subir el repositorio a GitHub (o arrastrar la carpeta en vercel.com/new).
2. Importar el proyecto y poner **Root Directory = `dashboard_next`**. Framework: Next.js (se detecta solo). Deploy.
3. Cada `git push` vuelve a publicar.

## Actualizar los números
Correr los scripts de R, luego `python dashboard_web/actualizar_datos.py` (escribe también `dashboard_next/data/data.json`) y volver a subir.

## Próximos pasos posibles
Base de datos (Supabase/Postgres) para guardar los pronósticos semanales y validar contra la Fiscalía; Tailwind si el equipo prefiere ese estilo.
