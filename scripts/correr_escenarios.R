# Corre 07b + 09 + 10 para los escenarios A y AB, guarda cada resultado y restaura la base de Sonia
log <- "_github/log_escenarios.txt"; w <- function(...) { con <- file(log, "a"); writeLines(paste0(format(Sys.time(), "%H:%M:%S "), ...), con); close(con); message(...) }
cat("", file = log)
copiar <- function(a, b, patron = NULL) { dir.create(b, recursive = TRUE, showWarnings = FALSE)
  fs <- list.files(a, pattern = patron, full.names = TRUE); file.copy(fs, b, overwrite = TRUE) }
for (esc in strsplit(Sys.getenv("ESCENARIOS", "A,AB"), ",")[[1]]) {
  Sys.setenv(ESCENARIO = esc); w("== Escenario ", esc, " ==")
  for (s in c("07b_objetivo_delictivo.R", "09_features.R", "10_modelos.R")) {
    t0 <- Sys.time()
    rs <- file.path(R.home("bin"), "Rscript.exe"); lg <- file.path("_escenarios", paste0("salida_", esc, "_", s, ".txt")); dir.create("_escenarios", showWarnings = FALSE)
    cod <- system2(rs, c("-e", shQuote(sprintf("source('scripts/%s', encoding='UTF-8')", s))), stdout = lg, stderr = lg)
    r <- if (cod == 0) "OK" else paste("ERROR (ver", lg, ")")
    w(s, "  ", r, "  (", round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1), " min)")
    if (r != "OK") break
  }
  d <- file.path("_escenarios", esc)
  copiar("03_resultados/modelos", file.path(d, "modelos")); copiar("03_resultados/tablas", file.path(d, "tablas"), "^(07b|09)_")
  copiar("03_resultados/graficos", file.path(d, "graficos"), "^(07b|09|10)_"); copiar("02_datos_limpios", file.path(d, "datos"), "(riobamba_depurada.rds|conteo_parroquia_semana.rds)")
}
Sys.setenv(ESCENARIO = "")
b <- "_escenarios/base"
file.copy(list.files(b, full.names = TRUE, pattern = "\\.(rds|csv)$"), "02_datos_limpios", overwrite = TRUE)
file.copy(list.files(file.path(b, "modelos"), full.names = TRUE), "03_resultados/modelos", overwrite = TRUE)
file.copy(list.files(file.path(b, "tablas"), full.names = TRUE), "03_resultados/tablas", overwrite = TRUE)
file.copy(list.files(file.path(b, "graficos"), full.names = TRUE), "03_resultados/graficos", overwrite = TRUE)
w("FIN: base de Sonia restaurada")
