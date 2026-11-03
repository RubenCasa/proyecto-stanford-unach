# R7 · Revisión de métodos para la TENDENCIA MENSUAL hasta 2029
# Backtest: se entrena hasta hace 24 meses y se compara con lo ocurrido.
source("scripts/_comun.R")
suppressPackageStartupMessages({ library(tsibble); library(fable); library(fabletools) })
if (requireNamespace("conflicted", quietly = TRUE))
  conflicted::conflicts_prefer(dplyr::lag, dplyr::filter, dplyr::select, .quiet = TRUE)
sink("revision/salidas/R7.txt", split = TRUE)
diario <- readRDS(file.path(DIR_LIMPIOS, "conteo_parroquia_fecha.rds"))
mensual <- diario %>% mutate(mes = yearmonth(fecha)) %>%
  group_by(cod_parroquia, parroquia_corta, mes) %>%
  summarise(incidentes = sum(incidentes), dias = n(), .groups = "drop") %>%
  filter(dias == days_in_month(as.Date(mes))) %>% select(-dias)
serie <- as_tsibble(mensual, key = c(cod_parroquia, parroquia_corta), index = mes)
corte <- max(serie$mes) - 24
fit <- serie %>% filter(mes <= corte) %>% model(
  `Promedio historico` = MEAN(incidentes),
  `Ingenuo estacional` = SNAIVE(incidentes),
  `Tendencia log-lineal` = TSLM(log(incidentes + 1) ~ trend() + season()),
  `ETS amortiguado` = ETS(incidentes ~ error("A") + trend("Ad") + season(c("N", "A"))),
  `ETS auto` = ETS(incidentes),
  `ARIMA` = ARIMA(incidentes))
fc <- forecast(fit, h = 24) %>% as_tibble() %>%
  select(cod_parroquia, parroquia_corta, mes, modelo = .model, pron = .mean) %>%
  inner_join(as_tibble(serie) %>% select(cod_parroquia, mes, real = incidentes), by = c("cod_parroquia", "mes"))
res <- fc %>% mutate(grupo = case_when(cod_parroquia == "060150" ~ "Urbana",
                                       TRUE ~ "Rurales")) %>%
  bind_rows(fc %>% filter(cod_parroquia %in% c("060153", "060154")) %>% mutate(grupo = parroquia_corta)) %>%
  group_by(grupo, modelo) %>%
  summarise(MAE_mensual = round(mean(abs(real - pron)), 2),
            error_pct = round(100 * sum(abs(real - pron)) / sum(real), 1),
            sesgo_pct = round(100 * (sum(pron) - sum(real)) / sum(real), 1), .groups = "drop") %>%
  arrange(grupo, MAE_mensual)
print(res, n = Inf)
write_csv(res, "revision/salidas/R7_tendencia_backtest.csv")
sink()
