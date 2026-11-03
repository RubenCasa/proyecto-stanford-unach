# =============================================================================
# PROYECTO STANFORD · ejecutar_todo.R
# Corre todo el flujo en orden (días 4 a 19). Tarda unos 20-40 minutos
# (importar 63 archivos y la validación cruzada de modelos son lo más lento).
# Abre primero proyecto_stanford.Rproj. La primera vez, corre antes
# scripts/00_instalar_paquetes.R
# =============================================================================
pasos <- c("scripts/01_importar_unir.R",      # Días 4-5  · Nelcy, Melanie, Sonia, Rubén
           "scripts/02_limpieza.R",           # Día 6     · Nelcy, Melanie, Sonia, Rubén
           "scripts/03_filtro_geografico.R",  # Día 7     · Nelcy, Melanie, Sonia, Rubén
           "scripts/04_fechas_diccionario.R", # Días 8-10 · Melanie, Sonia, Nelcy
           "scripts/05_eda_frecuencias.R",    # Día 9     · Nelcy, Sonia
           "scripts/06_eda_temporal.R",       # Día 10    · Nelcy, Sonia
           "scripts/07_conteos_variables.R",  # Días 8-10 · Rubén
           "scripts/08_mapas.R",              # Días 4-11 · Edgar (internet la 1.a vez)
           "scripts/09_features.R",           # Días 11-13· Rubén, Nelcy, Melanie, Edgar, Sonia
           "scripts/10_modelos.R",            # Días 14-19· Rubén, Nelcy, Sonia, Melanie
           "scripts/11_mapas_riesgo.R",       # Días 14-18· Edgar
           "scripts/12_tendencia_2029.R")     # Tendencia mensual hasta 2029 · Rubén, Sonia, Edgar
for (p in pasos) {
  message("\n\n######## EJECUTANDO ", p, " ########")
  t0 <- Sys.time()
  source(p, echo = FALSE, encoding = "UTF-8")
  message("######## ", p, " terminado en ", round(difftime(Sys.time(), t0, units = "mins"), 1), " min")
}
message("\nTodo listo.\n - Reporte EDA (Sonia): abrir reporte_EDA.qmd y pulsar Render\n",
        " - Dashboard (Anthony): shiny::runApp('dashboard')")
