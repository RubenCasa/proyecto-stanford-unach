# Muestra los resultados del proyecto en RStudio (panel Plots y consola).
# Uso: source("mostrar_resultados.R", encoding = "UTF-8")  ->  ver(1), ver(2), ... ver(8)
suppressWarnings(if (!requireNamespace("png", quietly = TRUE)) install.packages("png"))
library(grid)
.G <- "03_resultados/graficos/"
.LISTA <- c(
  "07b_1_tipo_registro_anual.png"     = "1 · Qué baja realmente: pedidos de patrullaje vs delitos",
  "08_2_mapa_incidentes_parroquia.png"= "2 · Mapa de incidentes por parroquia",
  "10_5_metricas_modelos.png"         = "3 · Comparación de modelos (error medio)",
  "10_6_real_vs_prediccion.png"       = "4 · Real vs predicción por parroquia",
  "10_3_series_tiempo_foco.png"       = "5 · Series de tiempo en Flores y Cubijíes",
  "11_1_mapa_riesgo_pronostico.png"   = "6 · Mapa de riesgo: próximas 4 semanas",
  "12_2_tendencia_2029_foco.png"      = "7 · Tendencia hasta 2029",
  "12_4_mapa_cambio_2029.png"         = "8 · Mapa del cambio esperado 2025-2029")
ver <- function(n = 1) {
  f <- names(.LISTA)[n]; cat("\n>>", .LISTA[[n]], "\n   archivo:", paste0(.G, f), "\n")
  grid.newpage(); grid.raster(png::readPNG(paste0(.G, f)))
  invisible(n)
}
tablas <- function() {
  cat("\n== Resumen del modelo (10_resultados_modelos.xlsx, hoja 'Resumen MAE') ==\n")
  print(as.data.frame(readxl::read_excel("03_resultados/modelos/10_resultados_modelos.xlsx", sheet = "Resumen MAE")[1:6, ]))
  cat("\n== Reales vs predichos del último año ==\n")
  print(as.data.frame(readxl::read_excel("03_resultados/modelos/10_resultados_modelos.xlsx", sheet = "Reales vs prediccion")))
  cat("\n== Catálogo COIP (07b_objetivo_delictivo.xlsx) ==\n")
  print(as.data.frame(readxl::read_excel("03_resultados/tablas/07b_objetivo_delictivo.xlsx", sheet = "Codigo COIP")))
}
cat("Listo. Escribe ver(1) ... ver(8) para los gráficos y tablas() para las tablas.\n")
