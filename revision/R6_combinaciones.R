# R6 · Combinaciones (promedio de modelos): suelen ser más estables que uno solo
source("revision/R0_base_revision.R")
sink("revision/salidas/R6.txt", split = TRUE)
lee <- function(m) readRDS(file.path("revision/salidas", paste0("pred_", make.names(m), ".rds")))$prediccion
combina <- function(nombre, modelos) {
  titulo(paste("R6 ·", nombre))
  registrar(nombre, Reduce(`+`, lapply(modelos, lee)) / length(modelos))
}
combina("Comb RF + XGB", c("RF separado", "XGB juntas"))
combina("Comb RF + XGB + BinNeg", c("RF separado", "XGB juntas", "BinNeg juntas"))
combina("Comb Poisson + Prom12", c("Poisson juntas", "Base promedio 12"))
combina("Comb Poisson + Prom12 + XGBrural", c("Poisson juntas", "Base promedio 12", "XGB rural aparte"))
if (file.exists("revision/salidas/pred_TS.ETS.rds"))
  combina("Comb Poisson + Prom12 + ETS", c("Poisson juntas", "Base promedio 12", "TS ETS"))
sink()
