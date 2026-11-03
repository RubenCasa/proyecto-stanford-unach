# R5 · Series de tiempo por parroquia (fable): ETS, ARIMA, pronóstico a 1 semana
source("revision/R0_base_revision.R")
suppressPackageStartupMessages({ library(tsibble); library(fable); library(fabletools) })
sink("revision/salidas/R5.txt", split = TRUE)
semanal <- readRDS(file.path(DIR_LIMPIOS, "conteo_parroquia_semana.rds")) %>% filter(semana_completa)
serie <- as_tsibble(semanal %>% transmute(cod_parroquia, semana = yearweek(semana_inicio), incidentes),
                    key = cod_parroquia, index = semana)
cs <- yearweek(CORTE)
fit <- serie %>% filter(semana < cs) %>%
  model(ETS = ETS(incidentes), ARIMA = ARIMA(incidentes),
        ETS_log = ETS(log(incidentes + 1)))
f1 <- refit(fit, serie, reestimate = FALSE) %>% fitted() %>% as_tibble() %>%
  filter(semana >= cs) %>% transmute(cod_parroquia, semana_inicio = as.Date(semana), .model, .fitted)
for (mname in unique(f1$.model)) {
  titulo(paste("R5 ·", mname))
  pr <- test %>% select(cod_parroquia, semana_inicio) %>%
    left_join(f1 %>% filter(.model == mname), by = c("cod_parroquia", "semana_inicio"))
  registrar(paste("TS", mname), pr$.fitted)
}
sink()
