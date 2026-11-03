# Corre 10, 11 y 12 con los modelos elegidos y deja un registro
setwd("C:/Users/RubenC/Desktop/PROYECTO STANFORD")
log <- "revision/salidas/registro_final.txt"
cat("Inicio:", format(Sys.time()), "\n", file = log)
for (s in c("scripts/10_modelos.R", "scripts/11_mapas_riesgo.R", "scripts/12_tendencia_2029.R")) {
  t0 <- Sys.time()
  r <- tryCatch({ source(s, encoding = "UTF-8"); "OK" },
                error = function(e) paste("ERROR:", conditionMessage(e)))
  while (sink.number() > 0) sink()
  cat(sprintf("%-32s %5.1f min  %s\n", s, as.numeric(difftime(Sys.time(), t0, units = "mins")), r),
      file = log, append = TRUE)
  message(">>> ", s, ": ", r)
}
message("LISTO FINAL")
