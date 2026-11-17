# Tablero web · Proyecto STANFORD (v2: mapa real + API)

Usa solo **resultados agregados** (sin datos personales ni de Fiscalía). El ECU 911 entrega la ubicación solo a nivel de **parroquia** (no hay coordenadas de cada incidente), por eso el mapa es por parroquia sobre un mapa base real (calles, oscuro o satélite).

## Qué incluye
- `index.html` — la aplicación (mapa Leaflet con teselas reales, línea de tiempo, alertas ajustables, comparación, modo oscuro).
- `api/` — funciones serverless de Vercel: `/api/datos`, `/api/pronostico?umbral=25`, `/api/tendencia?parroquia=CUBIJIES`, `/api/mapa`, `/api/resumen`.
- `lib/logica.js` — cálculos compartidos (la API y el navegador usan el mismo código).
- `data/data.json` — datos que leen las funciones. `data.js` — copia para abrir sin internet.
- `vendor/leaflet/` — librería de mapas incluida (no depende de CDN).

## Ver en el computador
Doble clic en `index.html` (los gráficos y el mapa funcionan; el mapa base necesita internet).

## Publicar en Vercel
**Opción A (arrastrar):** vercel.com/new → arrastrar la carpeta `dashboard_web` → Framework **Other** → Deploy.
**Opción B (GitHub):** subir la carpeta al repositorio, importarlo en Vercel y poner **Root Directory = `dashboard_web`**. Cada `git push` republica.
Al abrir el enlace aparece «API en vivo» arriba: los datos llegan desde `/api`.

## Actualizar los números
1. Correr los scripts de R (10 y 12 como mínimo).
2. `python dashboard_web/actualizar_datos.py` (necesita pandas y openpyxl) → regenera `data/data.json` y `data.js`.
3. Volver a subir.

## Mapa base
Teselas © OpenStreetMap / CARTO y Esri (satélite). Son servicios públicos gratuitos para uso moderado; para mucho tráfico conviene una clave propia (MapTiler, Mapbox).
