# Proyecto STANFORD · UNACH

**Análisis predictivo de patrones delictivos mediante técnicas de Ciencia de Datos e Inteligencia Artificial para el fortalecimiento de la seguridad ciudadana 2026–2029**

Universidad Nacional de Chimborazo · Carrera de Ciencia de Datos e Inteligencia Artificial
Zona de estudio: cantón Riobamba (Chimborazo), con foco en las parroquias **Flores** y **Cubijíes**.

## Qué contiene

| Carpeta | Contenido |
|---|---|
| `scripts/` | Código R del proyecto, del 01 al 12 (importación → limpieza → EDA → objetivo delictivo (07b) → mapas → features → modelos → riesgo → tendencia 2029). `_comun.R` tiene rutas y funciones compartidas. |
| `revision/` | Revisión de modelos uno por uno (R0–R7) y sus salidas. |
| `dashboard/` | Dashboard Shiny (`app.R`) y script de capturas. |
| `02_datos_limpios/` | Bases depuradas en `.rds` y el Feature Store (lo necesario para el dashboard). |
| `03_resultados/` | Gráficos, tablas y modelos (pronósticos, tendencia 2029). |
| `04_mapas/` | Mapas interactivos y capas de parroquias (`.gpkg`). |
| `05_documentos/` | Informe técnico, manuales, guía por estudiante, diccionarios, matriz y tablero de control. |
| `reporte_EDA.qmd/.html` | Reporte exploratorio en Quarto. |

## Cómo usarlo

1. Clonar el repositorio (o *Code → Download ZIP*) y abrir `proyecto_stanford.Rproj` en RStudio.
2. Instalar paquetes una sola vez: `source("scripts/00_instalar_paquetes.R")`.
3. **Ver el dashboard** (no requiere los datos crudos):
   ```r
   shiny::runApp("dashboard", launch.browser = TRUE)
   ```
4. **Reproducir todo desde cero** (opcional): descargar las bases mensuales del ECU 911 desde
   [datosabiertos.gob.ec](https://www.datosabiertos.gob.ec/) (archivos `emergencias_*.csv` 2021–2023 e `incidentes_*.csv/xlsx` 2024–2026),
   copiarlas en la carpeta raíz del proyecto y ejecutar `source("ejecutar_todo.R")`.
   Los datos crudos (≈2,2 GB) no se suben a GitHub por su tamaño.

Más detalle en `LEEME_INSTRUCCIONES.txt` y en `05_documentos/Manual_tecnico_borrador.docx`.

## Qué se predice (desde el día 14, 9-nov-2026)

Seguridad Ciudadana del ECU 911 mezcla hechos con pedidos de servicio y trámites. Solo cerca del 13 % son delitos:
el 46 % son pedidos de patrullaje y alarmas, el 16 % trámites (fichas de datos, boletas, resguardo de valores).
Por eso la variable objetivo es **incidentes delictivos = delitos + convivencia y orden público** por parroquia y semana
(`scripts/07b_objetivo_delictivo.R`). Lo que bajó entre 2021 y 2026 fueron sobre todo los pedidos de patrullaje (de 82 a 52 por día) y, hasta 2023,
la convivencia; los delitos se mantienen (entre 16 y 21 por día en el cantón).

## Resultados principales

- Unidad de análisis: parroquia × semana. Prueba: últimas 52 semanas; validación temporal en 5 pliegues.
- Pronóstico de 4 semanas con modelo elegido por zona (urbana: RF + XGBoost + BinNeg; rural: Poisson + promedio 12 semanas), rangos probables y alertas (índice ≥110 media, ≥125 alta).
- Tendencia mensual hasta diciembre de 2029 seleccionada por backtest de 24 meses.

## Datos y privacidad

- Fuente: Servicio Integrado de Seguridad ECU 911 (datos abiertos, anonimizados), licencia CC BY 4.0. Periodo: julio 2021 – septiembre 2026.
- Los resultados se publican solo agregados por parroquia y semana/mes.
- **Datos de Fiscalía:** cuando lleguen, se guardan en `01_datos_fiscalia/` (excluida del repositorio) y se anonimizan antes de cualquier análisis. Nunca subir datos personales.
- Repositorio privado: no subir correos, teléfonos ni cédulas del equipo o de terceros.

## Cómo colaborar

```bash
git pull                  # traer lo último antes de trabajar
# ... editar tus scripts ...
git add scripts/mi_script.R
git commit -m "Día X: descripción de mi aporte"
git push
```
Cada estudiante trabaja en los scripts de su día según `05_documentos/Guia_por_estudiante.docx`.
