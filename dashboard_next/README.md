# Tablero de delitos · Proyecto STANFORD (Next.js)

Tablero público del proyecto: pronóstico semanal y tendencia a 2029 de delitos explícitos (COIP) en el cantón Riobamba,
con foco en Flores y Cubijíes. Solo usa resultados agregados por parroquia (sin datos personales).

Next.js 15 (App Router) + React 19 + Leaflet. Los mapas usan Leaflet sobre mapas base de Esri (gris claro, gris oscuro y satélite, sin clave); los gráficos se dibujan en SVG sin librerías.

## Secciones
- **Esta semana**: una frase con lo que se espera, las parroquias foco, el mapa con el estado de cada parroquia y la lista.
- **Mapas**: cinco capas sobre el mismo mapa (estado de la semana, probabilidad de un delito, delitos por km² mes a mes 2022–2029 con reproducción, cambio hacia 2029 y abigeato) y un ranking de parroquias.
- **Parroquias**: todo sobre un lugar (próximas semanas, mes a mes hasta 2029, años, confiabilidad del modelo).
- **Hacia 2029**: mapa del cambio 2025→2029, total del cantón por año y cambio por parroquia.
- **Cómo se calcula**: qué cuenta como delito, otras definiciones (escenarios A, A+B y reglas del equipo), sensibilidad de la alerta, confiabilidad, abigeato, método y límites.

## Estructura
- `app/page.js`: el servidor entrega los datos y las alertas iniciales.
- `app/api/{datos,pronostico,tendencia,mapa,resumen}/route.js`: API (`/api/pronostico?umbral=25&esc=A`, `/api/tendencia?parroquia=CUBIJIES`…).
- `components/Dashboard.jsx`: las cuatro secciones.
- `components/MapaLeaflet.jsx`: mapa Leaflet de las 12 parroquias (geometría de `04_mapas/parroquias_riobamba.gpkg`), con fondo normal o satélite.
- `lib/mapas.js`: escalas de color de los mapas (tema claro y oscuro).
- `components/Charts.jsx`: líneas con rango, columnas y barras.
- `lib/logica.js`: cálculos compartidos por la API y el navegador (alertas, tendencias).
- `data/data.json`: resultados de R (se regeneran con `python scripts/actualizar_dashboard.py`).

## Probar en el computador (Node 18.18 o superior)
```
cd dashboard_next
npm install
npm run dev        # http://localhost:3000
```

## Publicar en Vercel
Root Directory = `dashboard_next` (Framework: Next.js). Cada `git push` a `main` vuelve a publicar.

## Actualizar los números
1. Correr los scripts de R (07b, 10, 12 y 13 como mínimo).
2. `python scripts/actualizar_dashboard.py` (escribe `dashboard_next/data/data.json`).
3. Subir los cambios con `git push`.
