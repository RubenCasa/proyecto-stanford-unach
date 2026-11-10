# =============================================================================
# PROYECTO STANFORD · 12_tendencia_2029.R
# Tendencia mensual de incidentes delictivos (delitos + convivencia) por parroquia hasta DICIEMBRE 2029
# (horizonte del proyecto "... seguridad ciudadana 2026–2029")
#
#   [RUBÉN]  Prueba retrospectiva (backtest), elección del método por zona y
#            pronóstico mensual con rangos de incertidumbre (80 % y 95 %).
#   [SONIA]  Gráficos de tendencia (histórico + pronóstico) y del backtest.
#   [EDGAR]  Mapa del cambio esperado 2025 -> 2029 por parroquia.
#   [WALTER/GABRIELA] Tabla anual para el informe.
#
# IMPORTANTE: un pronóstico a 3 años NO dice cuántos incidentes habrá un mes
# concreto; muestra la TENDENCIA más probable y un rango. Cuanto más lejos,
# más ancho el rango. Se debe actualizar cada mes con datos nuevos.
#
# Entrada: 02_datos_limpios/conteo_parroquia_fecha.rds (de 07_conteos_variables.R)
# Salida:  03_resultados/modelos/tendencia_2029.rds y 12_tendencia_2029.xlsx
# =============================================================================
source("scripts/_comun.R")
suppressPackageStartupMessages({ library(tsibble); library(fable); library(fabletools) })
if (requireNamespace("conflicted", quietly = TRUE))
  conflicted::conflicts_prefer(dplyr::filter, dplyr::lag, dplyr::select, .quiet = TRUE)

HASTA <- yearmonth("2029-12")

# ---- Serie mensual por parroquia (solo meses completos) ----------------------
diario <- readRDS(file.path(DIR_LIMPIOS, "conteo_parroquia_fecha.rds"))
mensual <- diario %>%
  mutate(mes = yearmonth(fecha)) %>%
  group_by(cod_parroquia, parroquia_corta, zona_foco, mes) %>%
  summarise(incidentes = sum(incidentes), dias = n(), .groups = "drop") %>%
  filter(dias == days_in_month(as.Date(mes))) %>% select(-dias)
serie <- as_tsibble(mensual, key = c(cod_parroquia, parroquia_corta, zona_foco), index = mes)
message("Serie mensual: ", min(serie$mes), " a ", max(serie$mes), " · ",
        n_distinct(serie$cod_parroquia), " parroquias")

modelos <- function(d) d %>% model(
  `Promedio histórico`          = MEAN(incidentes),
  `Tendencia log-lineal`        = TSLM(log(incidentes + 1) ~ trend() + season()),
  `ETS (tendencia amortiguada)` = ETS(incidentes ~ error("A") + trend(c("N", "Ad")) + season(c("N", "A"))),
  `ARIMA`                       = ARIMA(incidentes),
  `Combinación ARIMA + ETS`     = (ARIMA(incidentes) +
                                     ETS(incidentes ~ error("A") + trend(c("N", "Ad")) + season(c("N", "A")))) / 2
)
zona_de <- function(cod) if_else(cod == "060150", "Urbana", "Rurales")

# =============================================================================
# [RUBÉN] Prueba retrospectiva: se entrena hasta hace 24 meses y se compara
# el pronóstico a 24 meses con lo que de verdad pasó.
# =============================================================================
titulo("[RUBÉN] Backtest a 24 meses")
corte_bt <- max(serie$mes) - 24
fit_bt <- modelos(serie %>% filter(mes <= corte_bt))
fc_bt <- forecast(fit_bt, h = 24) %>% as_tibble() %>%
  select(cod_parroquia, parroquia_corta, mes, modelo = .model, pronostico = .mean) %>%
  inner_join(as_tibble(serie) %>% select(cod_parroquia, mes, real = incidentes),
             by = c("cod_parroquia", "mes"))
metr_bt <- fc_bt %>% mutate(zona = zona_de(cod_parroquia)) %>%
  group_by(zona, modelo) %>%
  summarise(MAE_mensual = round(mean(abs(real - pronostico)), 2),
            error_relativo_pct = round(100 * sum(abs(real - pronostico)) / sum(real), 1),
            .groups = "drop") %>% arrange(zona, MAE_mensual)
print(metr_bt)

elegido_urbana <- metr_bt %>% filter(zona == "Urbana") %>% slice(1) %>% pull(modelo)
# Rurales: se prioriza a las parroquias BENEFICIARIAS. Se elige el método con
# mejor puesto promedio en Cubijíes y Flores; el error del conjunto rural
# desempata. (Revisión del 02-nov: ARIMA quedaba bien pero proyectaba -50 % en
# Cubijíes; el promedio histórico era el peor en Cubijíes.)
puestos_rural <- fc_bt %>% filter(cod_parroquia != "060150") %>%
  mutate(grupo = "Rurales") %>%
  bind_rows(fc_bt %>% filter(cod_parroquia %in% names(PARROQUIAS_FOCO)) %>%
              mutate(grupo = parroquia_corta)) %>%
  group_by(grupo, modelo) %>% summarise(MAE = mean(abs(real - pronostico)), .groups = "drop") %>%
  group_by(grupo) %>% mutate(puesto = rank(MAE, ties.method = "min")) %>% ungroup()
print(puestos_rural %>% arrange(grupo, puesto))
ranking_rural <- function(excluir = character()) puestos_rural %>%
  filter(!modelo %in% excluir) %>% group_by(modelo) %>%
  summarise(puesto_beneficiarias = mean(puesto[grupo != "Rurales"]),
            MAE_rurales = MAE[grupo == "Rurales"], .groups = "drop") %>%
  arrange(puesto_beneficiarias, MAE_rurales)
print(ranking_rural())
elegido_rural <- ranking_rural()$modelo[1]
message(">>> Tendencia URBANA: ", elegido_urbana, " · RURALES: ", elegido_rural)

titulo("[SONIA] Gráfico del backtest")
g <- fc_bt %>% filter(cod_parroquia %in% c("060150", names(PARROQUIAS_FOCO))) %>%
  ggplot(aes(as.Date(mes))) +
  geom_line(aes(y = pronostico, colour = modelo), linewidth = 0.8) +
  geom_point(data = ~ distinct(.x, parroquia_corta, mes, real), aes(y = real), size = 1.2) +
  facet_wrap(~parroquia_corta, ncol = 1, scales = "free_y") +
  labs(title = "Prueba retrospectiva: pronóstico a 24 meses vs real (puntos)",
       x = NULL, y = "Incidentes por mes", colour = NULL) + tema_stanford +
  theme(legend.position = "bottom")
guardar_grafico(g, "12_1_backtest_24_meses.png", ancho = 10, alto = 9)

# =============================================================================
# [RUBÉN] Pronóstico mensual hasta diciembre 2029
# =============================================================================
titulo("[RUBÉN] Pronóstico mensual hasta diciembre 2029")
h_meses <- as.integer(HASTA - max(serie$mes))
fit <- modelos(serie)
fc <- forecast(fit, h = h_meses)

# Filtro de sentido común (rurales): en parroquias pequeñas una tendencia lineal
# proyectada 3 años puede volverse absurda. Se descartan los métodos que cambien
# más de ±40 % entre los últimos 12 meses reales y 2029 en Flores o Cubijíes.
ultimo_anio <- as_tibble(serie) %>% filter(mes > max(mes) - 12) %>%
  group_by(cod_parroquia) %>% summarise(real_12m = sum(incidentes), .groups = "drop")
plausibilidad <- fc %>% as_tibble() %>% filter(year(as.Date(mes)) == 2029,
                                              cod_parroquia %in% names(PARROQUIAS_FOCO)) %>%
  group_by(modelo = .model, cod_parroquia) %>% summarise(total_2029 = sum(.mean), .groups = "drop") %>%
  left_join(ultimo_anio, by = "cod_parroquia") %>%
  mutate(cambio_pct = round(100 * (total_2029 / real_12m - 1), 1))
print(plausibilidad)
descartados <- plausibilidad %>% filter(abs(cambio_pct) > 40) %>% pull(modelo) %>% unique()
if (elegido_rural %in% descartados) {
  ranking <- ranking_rural(excluir = descartados)
  message("El método ", elegido_rural, " proyecta un cambio > 40 % en Flores/Cubijíes: se descarta.")
  elegido_rural <- ranking$modelo[1]
  message(">>> Tendencia RURALES (tras el filtro): ", elegido_rural)
}
tendencia <- fc %>% hilo(level = c(80, 95)) %>% unpack_hilo(c(`80%`, `95%`)) %>%
  as_tibble() %>%
  filter((cod_parroquia == "060150" & .model == elegido_urbana) |
           (cod_parroquia != "060150" & .model == elegido_rural)) %>%
  transmute(cod_parroquia, parroquia_corta, zona_foco, mes = as.Date(mes), modelo = .model,
            tipo = "Pronóstico", incidentes = round(pmax(.mean, 0), 1),
            bajo80 = round(pmax(`80%_lower`, 0), 1), alto80 = round(`80%_upper`, 1),
            bajo95 = round(pmax(`95%_lower`, 0), 1), alto95 = round(`95%_upper`, 1))
historico <- as_tibble(serie) %>%
  transmute(cod_parroquia, parroquia_corta, zona_foco, mes = as.Date(mes),
            modelo = NA_character_, tipo = "Real", incidentes = as.numeric(incidentes))
tendencia_2029 <- bind_rows(historico, tendencia) %>% arrange(cod_parroquia, mes)

# Tabla anual (2026 = meses reales + meses pronosticados)
anual <- tendencia_2029 %>% mutate(anio = year(mes)) %>%
  group_by(cod_parroquia, parroquia_corta, anio) %>%
  summarise(incidentes = round(sum(incidentes)), meses = n(),
            meses_pronosticados = sum(tipo == "Pronóstico"), .groups = "drop") %>%
  filter(meses == 12)
cambio <- anual %>% select(parroquia_corta, anio, incidentes) %>%
  pivot_wider(names_from = anio, values_from = incidentes) %>%
  mutate(cambio_2025_2029_pct = round(100 * (`2029` / `2025` - 1), 1))
print(cambio, width = Inf)

titulo("[SONIA] Gráficos de tendencia hasta 2029")
graf_tendencia <- function(cods, nombre, titulo_g, alto = 7) {
  d <- tendencia_2029 %>% filter(cod_parroquia %in% cods)
  g <- ggplot(d, aes(mes)) +
    geom_ribbon(data = filter(d, tipo == "Pronóstico"), aes(ymin = bajo95, ymax = alto95),
                fill = "#d4593a", alpha = 0.12) +
    geom_ribbon(data = filter(d, tipo == "Pronóstico"), aes(ymin = bajo80, ymax = alto80),
                fill = "#d4593a", alpha = 0.25) +
    geom_line(data = filter(d, tipo == "Real"), aes(y = incidentes), colour = "grey40") +
    geom_line(data = filter(d, tipo == "Pronóstico"), aes(y = incidentes), colour = "#d4593a",
              linewidth = 0.9) +
    facet_wrap(~parroquia_corta, scales = "free_y", ncol = if (length(cods) > 3) 3 else 1) +
    scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
    labs(title = titulo_g,
         subtitle = paste0("Gris: real · Rojo: tendencia esperada · Bandas: rango 80 % y 95 %\n",
                           "Urbana: ", elegido_urbana, " · Rurales: ", elegido_rural),
         x = NULL, y = "Incidentes delictivos por mes") + tema_stanford
  guardar_grafico(g, nombre, ancho = 11, alto = alto)
}
graf_tendencia(c("060150", names(PARROQUIAS_FOCO)), "12_2_tendencia_2029_foco.png",
               "Tendencia hasta 2029 · Riobamba urbana, Cubijíes y Flores")
graf_tendencia(unique(tendencia_2029$cod_parroquia), "12_3_tendencia_2029_todas.png",
               "Tendencia hasta 2029 · todas las parroquias de Riobamba", alto = 10)

# =============================================================================
# [EDGAR] Mapa del cambio esperado 2025 -> 2029
# =============================================================================
ruta_capa <- file.path(DIR_MAPAS, "parroquias_riobamba.gpkg")
if (file.exists(ruta_capa)) {
  titulo("[EDGAR] Mapa del cambio esperado 2025-2029")
  capa <- sf::st_read(ruta_capa, quiet = TRUE) %>%
    left_join(cambio %>% select(parroquia_corta, cambio_2025_2029_pct), by = "parroquia_corta")
  g <- ggplot(capa) + geom_sf(aes(fill = cambio_2025_2029_pct), colour = "white") +
    geom_sf_text(aes(label = paste0(parroquia_corta, "\n", cambio_2025_2029_pct, " %")), size = 2.4) +
    scale_fill_gradient2(low = "#2b7bba", mid = "white", high = "#d4593a", midpoint = 0,
                         name = "Cambio\n2025-2029") +
    labs(title = "Cambio esperado en incidentes delictivos, 2025 a 2029",
         subtitle = "Azul: baja · Rojo: sube (tendencia, no certeza)") + theme_void()
  guardar_grafico(g, "12_4_mapa_cambio_2029.png", ancho = 8, alto = 8)
}

# ---- Guardar -----------------------------------------------------------------
saveRDS(tendencia_2029, file.path(DIR_MODELOS, "tendencia_2029.rds"))
write_xlsx(list("Backtest 24 meses" = metr_bt, "Puestos rurales" = puestos_rural,
                "Plausibilidad 2029" = plausibilidad, "Anual" = anual, "Cambio 2025-2029" = cambio,
                "Mensual" = tendencia_2029),
           file.path(DIR_MODELOS, "12_tendencia_2029.xlsx"))
message("Listo -> el dashboard muestra la pestaña 'Tendencia 2029'.")
