# =============================================================================
# PROYECTO STANFORD · revision/correr_revision.R
# Corre la revisión de modelos uno por uno (R1 a R5) y guarda todo en
# revision/salidas/. Si un modelo falla, anota el error y sigue con el siguiente.
# Uso (con el proyecto abierto):  source("revision/correr_revision.R")
# =============================================================================
setwd("C:/Users/RubenC/Desktop/PROYECTO STANFORD")
dir.create("revision/salidas", recursive = TRUE, showWarnings = FALSE)
unlink("revision/salidas/metricas.csv")
log <- "revision/salidas/registro.txt"
cat("Revisión iniciada:", format(Sys.time()), "\n", file = log)
for (s in c("R1_bases", "R2_glm", "R3_random_forest", "R4_xgboost", "R5_series_tiempo")) {
  t0 <- Sys.time()
  r <- tryCatch({ source(file.path("revision", paste0(s, ".R")), encoding = "UTF-8"); "OK" },
                error = function(e) paste("ERROR:", conditionMessage(e)))
  while (sink.number() > 0) sink()
  cat(sprintf("%-20s %-6s %5.1f min  %s\n", s, substr(r, 1, 5),
              as.numeric(difftime(Sys.time(), t0, units = "mins")), r), file = log, append = TRUE)
  message(">>> ", s, ": ", r)
}
cat("Revisión terminada:", format(Sys.time()), "\n", file = log, append = TRUE)
message("LISTO. Avísale a Claude.")
