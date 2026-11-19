# Corre 07b + 09 + 10 para los escenarios de definición de delito (A, AB, ED…), guarda cada resultado
# en _escenarios/<escenario>/ y al final deja la base de Sonia exactamente como estaba ANTES de correr.
#
# Uso: Sys.setenv(ESCENARIOS = "A,AB"); source("scripts/correr_escenarios.R")
#
# Corrección 19-nov: antes se restauraba la base desde una copia fija (_escenarios/base) que no se
# actualizaba. Si los scripts cambiaban después de esa copia (p. ej. la tendencia rural del 17-nov),
# cada corrida de escenarios devolvía en silencio los resultados oficiales a una versión vieja.
# Ahora la copia de la base se toma al empezar, de los resultados vigentes.
log <- "_github/log_escenarios.txt"; dir.create("_github", showWarnings = FALSE)
w <- function(...) { con <- file(log, "a"); writeLines(paste0(format(Sys.time(), "%H:%M:%S "), ...), con); close(con); message(...) }
cat("", file = log)
copiar <- function(a, b, patron = NULL) { dir.create(b, recursive = TRUE, showWarnings = FALSE)
  fs <- list.files(a, pattern = patron, full.names = TRUE); ok <- file.copy(fs, b, overwrite = TRUE)
  if (!all(ok)) stop("No se pudo copiar: ", paste(fs[!ok], collapse = ", ")); invisible(fs) }

# 1. Copia de la base vigente (se borra la anterior para no mezclar versiones)
b <- "_escenarios/base"
unlink(b, recursive = TRUE)
PATRON_DATOS <- "\\.rds$|^feature_store\\.csv$"     # riobamba_depurada.csv (≈100 MB) se regenera; no se copia
copiar("02_datos_limpios", b, PATRON_DATOS)
copiar("03_resultados/modelos", file.path(b, "modelos")); copiar("03_resultados/tablas", file.path(b, "tablas"))
copiar("03_resultados/graficos", file.path(b, "graficos"))
w("Base de Sonia guardada en ", b)

# 2. Cada escenario
on.exit(Sys.setenv(ESCENARIO = ""), add = TRUE)
for (esc in strsplit(Sys.getenv("ESCENARIOS", "A,AB"), ",")[[1]]) {
  Sys.setenv(ESCENARIO = esc); w("== Escenario ", esc, " ==")
  for (s in c("07b_objetivo_delictivo.R", "09_features.R", "10_modelos.R")) {
    t0 <- Sys.time()
    rs <- file.path(R.home("bin"), "Rscript.exe"); lg <- file.path("_escenarios", paste0("salida_", esc, "_", s, ".txt"))
    cod <- system2(rs, c("-e", shQuote(sprintf("source('scripts/%s', encoding='UTF-8')", s))), stdout = lg, stderr = lg)
    r <- if (cod == 0) "OK" else paste("ERROR (ver", lg, ")")
    w(s, "  ", r, "  (", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min)")
    if (r != "OK") break
  }
  d <- file.path("_escenarios", esc)
  copiar("03_resultados/modelos", file.path(d, "modelos")); copiar("03_resultados/tablas", file.path(d, "tablas"), "^(07b|09)_")
  copiar("03_resultados/graficos", file.path(d, "graficos"), "^(07b|09|10)_"); copiar("02_datos_limpios", file.path(d, "datos"), "(riobamba_depurada.rds|conteo_parroquia_semana.rds)")
}

# 3. Restaurar la base guardada en el paso 1
Sys.setenv(ESCENARIO = "")
copiar(b, "02_datos_limpios", PATRON_DATOS)
copiar(file.path(b, "modelos"), "03_resultados/modelos"); copiar(file.path(b, "tablas"), "03_resultados/tablas")
copiar(file.path(b, "graficos"), "03_resultados/graficos")
w("FIN: base de Sonia restaurada (la misma que había antes de correr)")
