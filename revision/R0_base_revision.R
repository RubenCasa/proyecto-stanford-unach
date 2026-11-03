# =============================================================================
# PROYECTO STANFORD · revision/R0_base_revision.R
# Base común para revisar los modelos UNO POR UNO (lo carga cada R1..R7).
# Misma partición que 10_modelos.R: últimas 52 semanas = prueba.
# =============================================================================
source("scripts/_comun.R")
suppressPackageStartupMessages(library(tidymodels))
tidymodels_prefer()
if (requireNamespace("conflicted", quietly = TRUE))
  conflicted::conflicts_prefer(dplyr::lag, dplyr::filter, dplyr::select, .quiet = TRUE)
set.seed(2026)
dir.create("revision/salidas", recursive = TRUE, showWarnings = FALSE)

fs <- readRDS(file.path(DIR_LIMPIOS, "feature_store.rds")) %>%
  mutate(parroquia = factor(cod_parroquia),
         across(where(is.logical) & !any_of("zona_foco"), as.integer))
CONTEOS <- c("lag1", "lag2", "lag3", "lag4", "lag52", "ma4", "ma8", "ma12",
             "robos_lag1", "violencia_lag1")
CALENDARIO <- c("semana_iso", "mes_num", "trimestre", "sin_semana", "cos_semana",
                "n_feriados", "semana_pago", "fin_de_mes", "tendencia")
CORTE <- max(fs$semana_inicio) - weeks(51)
train <- fs %>% filter(semana_inicio < CORTE)
test  <- fs %>% filter(semana_inicio >= CORTE)
URB <- "060150"

# Evalúa un vector de predicciones sobre `test` y lo guarda en el registro
registrar <- function(modelo, pred, datos = test, nota = "") {
  d <- datos %>% transmute(cod_parroquia, semana_inicio, real = incidentes,
                           prediccion = pmax(pred, 0))
  g <- bind_rows(
    d %>% filter(cod_parroquia == URB) %>% mutate(grupo = "Urbana"),
    d %>% filter(cod_parroquia != URB) %>% mutate(grupo = "Rurales"),
    d %>% filter(cod_parroquia == "060153") %>% mutate(grupo = "Cubijies"),
    d %>% filter(cod_parroquia == "060154") %>% mutate(grupo = "Flores")) %>%
    group_by(grupo) %>%
    summarise(MAE = mean(abs(real - prediccion)), RMSE = sqrt(mean((real - prediccion)^2)),
              sesgo = mean(prediccion - real), n = n(), .groups = "drop") %>%
    mutate(modelo = modelo, nota = nota, hora = format(Sys.time(), "%H:%M"))
  ruta <- "revision/salidas/metricas.csv"
  write_csv(g, ruta, append = file.exists(ruta))
  saveRDS(d, file.path("revision/salidas", paste0("pred_", make.names(modelo), ".rds")))
  print(g %>% select(grupo, MAE, RMSE, sesgo) %>% mutate(across(where(is.numeric), ~ round(.x, 2))))
  invisible(g)
}
message("Base lista: train ", nrow(train), " filas · test ", nrow(test), " filas · corte ", CORTE)
