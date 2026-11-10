# =============================================================================
# PROYECTO STANFORD · 10_modelos.R
# DÍAS 14-18 (9 al 13-nov) · Entrenamiento y validación de modelos predictivos
# (+ DÍA 19: predicciones para el dashboard)
#
# Problema: predecir el número de incidentes DELICTIVOS (delitos + convivencia,
# definidos el día 14 en 07b_objetivo_delictivo.R) de la próxima semana en cada
# parroquia de Riobamba. Métricas: MAE y RMSE.
# Validación por fecha: el ÚLTIMO AÑO (52 semanas) es prueba; nunca al azar.
#
# DÍA 14 [SONIA] distribución del objetivo · [RUBÉN] partición + modelo base y
#        Poisson · [NELCY] tamaños · [MELANIE] objetivo y predictores
# DÍA 15 [RUBÉN] binomial negativa y random forest (ranger) · [NELCY] sin fuga
#        de información · [SONIA] residuos por parroquia
# DÍA 16 [RUBÉN] xgboost y series de tiempo (fable) · [NELCY] datos como serie
#        de tiempo · [SONIA] pronósticos vs reales
# DÍA 17 [RUBÉN] validación cruzada temporal y ajuste con tune · [NELCY]
#        pliegues · [SONIA] desempeño por pliegue
# DÍA 18 [RUBÉN] tabla de métricas y modelo elegido · [NELCY] reales vs
#        predicción · [SONIA] gráficos · [MELANIE] variables del modelo elegido
# DÍA 19 [RUBÉN] pronóstico de las próximas 4 semanas (modelo urbano + modelo rural)
#
# Entrada: 02_datos_limpios/feature_store.rds y conteo_parroquia_semana.rds
# Salida:  03_resultados/modelos/  (métricas, predicciones, modelo final)
# Tiempo:  10-20 minutos (la validación cruzada es lo más lento)
# =============================================================================
source("scripts/_comun.R")
suppressPackageStartupMessages(library(tidymodels))
tidymodels_prefer()
conflicted::conflicts_prefer(dplyr::lag, dplyr::filter, dplyr::select, .quiet = TRUE)
set.seed(2026)

fs <- readRDS(file.path(DIR_LIMPIOS, "feature_store.rds")) %>%
  mutate(parroquia = factor(cod_parroquia),
         across(where(is.logical) & !any_of("zona_foco"), as.integer))
# Las variables espaciales solo se usan si existen (dependen del mapa de Edgar)
espaciales <- intersect(c("area_km2", "n_vecinos"), names(fs))
espaciales <- espaciales[sapply(espaciales, function(v) all(!is.na(fs[[v]])))]

CONTEOS <- c("lag1", "lag2", "lag3", "lag4", "lag52", "ma4", "ma8", "ma12",
             "robos_lag1", "violencia_lag1")
CALENDARIO <- c("semana_iso", "mes_num", "trimestre", "sin_semana", "cos_semana",
                "n_feriados", "semana_pago", "fin_de_mes", "tendencia")
PREDICTORES <- c(CONTEOS, CALENDARIO, "urbana", espaciales, "parroquia")

nombres_parroquia <- fs %>% distinct(cod_parroquia, parroquia_corta)
metricas <- function(d) d %>% summarise(MAE = mean(abs(real - prediccion)),
                                        RMSE = sqrt(mean((real - prediccion)^2)), n = n(),
                                        .groups = "drop")

# =============================================================================
# DÍA 14
# =============================================================================
titulo("[SONIA] Día 14 · Distribución de la variable objetivo")
dist_obj <- fs %>% group_by(parroquia_corta) %>%
  summarise(media = mean(incidentes), varianza = var(incidentes),
            pct_ceros = 100 * mean(incidentes == 0), .groups = "drop") %>%
  mutate(sobredispersion = round(varianza / media, 1))
print(dist_obj)
g <- ggplot(fs, aes(incidentes)) + geom_histogram(bins = 30, fill = "#1f5f99") +
  facet_wrap(~parroquia_corta, scales = "free") +
  labs(title = "Distribución semanal de incidentes por parroquia",
       subtitle = "Conteos con sobredispersión -> Poisson / binomial negativa / árboles",
       x = "Incidentes por semana", y = "Semanas") + tema_stanford
guardar_grafico(g, "10_1_distribucion_objetivo.png", ancho = 12, alto = 8)

titulo("[RUBÉN] Día 14 · Partición por fecha")
CORTE <- max(fs$semana_inicio) - weeks(51)          # últimas 52 semanas = prueba
train <- fs %>% filter(semana_inicio <  CORTE)
test  <- fs %>% filter(semana_inicio >= CORTE)

titulo("[NELCY] Día 14 · Tamaños de entrenamiento y prueba")
print(tibble(conjunto = c("Entrenamiento", "Prueba"),
             desde = c(min(train$semana_inicio), min(test$semana_inicio)),
             hasta = c(max(train$semana_inicio), max(test$semana_inicio)),
             semanas = c(n_distinct(train$semana_inicio), n_distinct(test$semana_inicio)),
             filas = c(nrow(train), nrow(test))))

titulo("[MELANIE] Día 14 · Objetivo y predictores")
print(tibble(rol = c("Objetivo", rep("Predictor", length(PREDICTORES))),
             variable = c("incidentes", PREDICTORES)), n = Inf)

titulo("[RUBÉN] Día 14 · Modelos base y regresión Poisson")
pred_test <- bind_rows(
  test %>% transmute(cod_parroquia, semana_inicio, real = incidentes,
                     modelo = "Base: semana anterior", prediccion = lag1),
  test %>% transmute(cod_parroquia, semana_inicio, real = incidentes,
                     modelo = "Base: promedio 4 semanas", prediccion = ma4),
  test %>% transmute(cod_parroquia, semana_inicio, real = incidentes,
                     modelo = "Base: promedio 12 semanas", prediccion = ma12)
)
prep_glm <- function(d) d %>% mutate(across(all_of(CONTEOS), log1p))
formula_glm <- reformulate(c(CONTEOS, "sin_semana", "cos_semana", "n_feriados",
                             "semana_pago", "fin_de_mes", "tendencia", "parroquia"),
                           response = "incidentes")
m_poisson <- glm(formula_glm, family = poisson(), data = prep_glm(train))
pred_test <- bind_rows(pred_test, test %>% transmute(
  cod_parroquia, semana_inicio, real = incidentes, modelo = "Regresión Poisson",
  prediccion = predict(m_poisson, newdata = prep_glm(test), type = "response")))
print(pred_test %>% group_by(modelo) %>% metricas())

# =============================================================================
# DÍA 15
# =============================================================================
titulo("[NELCY] Día 15 · Verificación de fuga de información")
stopifnot("Prueba antes que entrenamiento" = max(train$semana_inicio) < min(test$semana_inicio))
message("OK: entrenamiento termina ", max(train$semana_inicio), " y prueba empieza ",
        min(test$semana_inicio), ". Los rezagos solo usan semanas anteriores.")

titulo("[RUBÉN] Día 15 · Binomial negativa y random forest (ranger)")
m_nb <- tryCatch(MASS::glm.nb(formula_glm, data = prep_glm(train)),
                 error = function(e) { message("Binomial negativa no convergió: ", e$message); NULL })
if (!is.null(m_nb)) {
  pred_test <- bind_rows(pred_test, test %>% transmute(
    cod_parroquia, semana_inicio, real = incidentes, modelo = "Binomial negativa",
    prediccion = predict(m_nb, newdata = prep_glm(test), type = "response")))
}

datos_ml <- function(d) d %>% select(incidentes, semana_inicio, cod_parroquia, all_of(PREDICTORES))
receta <- recipe(incidentes ~ ., data = datos_ml(train)) %>%
  update_role(semana_inicio, cod_parroquia, new_role = "id") %>%
  step_dummy(all_nominal_predictors())

wf_rf <- workflow(receta, rand_forest(mode = "regression", trees = 500) %>%
                    set_engine("ranger", importance = "impurity", seed = 2026))
fit_rf <- fit(wf_rf, datos_ml(train))
pred_test <- bind_rows(pred_test, test %>% transmute(
  cod_parroquia, semana_inicio, real = incidentes, modelo = "Random forest",
  prediccion = predict(fit_rf, datos_ml(test))$.pred))
print(pred_test %>% group_by(modelo) %>% metricas())

titulo("[SONIA] Día 15 · Residuos por parroquia")
g <- pred_test %>% filter(modelo %in% c("Regresión Poisson", "Random forest")) %>%
  left_join(nombres_parroquia, by = "cod_parroquia") %>%
  ggplot(aes(parroquia_corta, real - prediccion, fill = modelo)) +
  geom_hline(yintercept = 0) + geom_boxplot(outlier.size = 0.5) + coord_flip() +
  facet_wrap(~ parroquia_corta == "RIOBAMBA", scales = "free",
             labeller = as_labeller(c(`TRUE` = "Urbana", `FALSE` = "Rurales"))) +
  labs(title = "Residuos (real - predicción) en el año de prueba", x = NULL,
       y = "Residuo", fill = NULL) + tema_stanford
guardar_grafico(g, "10_2_residuos_parroquia.png", ancho = 11, alto = 6)

# =============================================================================
# DÍA 16
# =============================================================================
titulo("[RUBÉN] Día 16 · XGBoost")
wf_xgb <- workflow(receta, boost_tree(mode = "regression", trees = 500, tree_depth = 4,
                                      learn_rate = 0.05) %>%
                     set_engine("xgboost", objective = "count:poisson"))
fit_xgb <- fit(wf_xgb, datos_ml(train))
pred_test <- bind_rows(pred_test, test %>% transmute(
  cod_parroquia, semana_inicio, real = incidentes, modelo = "XGBoost",
  prediccion = predict(fit_xgb, datos_ml(test))$.pred))

titulo("[NELCY] Día 16 · Datos en formato de serie de tiempo por parroquia")
semanal <- readRDS(file.path(DIR_LIMPIOS, "conteo_parroquia_semana.rds")) %>%
  filter(semana_completa)
serie <- tsibble::as_tsibble(
  semanal %>% transmute(cod_parroquia, semana = tsibble::yearweek(semana_inicio), incidentes),
  key = cod_parroquia, index = semana)
print(serie)

titulo("[RUBÉN] Día 16 · Series de tiempo (fable): ETS, ARIMA y estacional ingenuo")
pred_ts <- tryCatch({
  suppressPackageStartupMessages({ library(fable); library(fabletools) })
  corte_sem <- tsibble::yearweek(CORTE)
  fit_ts <- serie %>% filter(semana < corte_sem) %>%
    model(ETS = ETS(incidentes), ARIMA = ARIMA(incidentes),
          SNAIVE = SNAIVE(incidentes ~ lag("year")))
  # Pronóstico a 1 semana en todo el año de prueba, sin re-estimar parámetros
  refit(fit_ts, serie, reestimate = FALSE) %>% fitted() %>% as_tibble() %>%
    filter(semana >= corte_sem) %>%
    transmute(cod_parroquia, semana_inicio = as.Date(semana),
              modelo = paste("Serie de tiempo:", .model), prediccion = pmax(.fitted, 0)) %>%
    filter(!is.na(prediccion))
}, error = function(e) { message("Series de tiempo no disponibles: ", e$message); NULL })
if (!is.null(pred_ts)) {
  pred_test <- bind_rows(pred_test, pred_ts %>%
    inner_join(test %>% select(cod_parroquia, semana_inicio, real = incidentes),
               by = c("cod_parroquia", "semana_inicio")))
}

titulo("[SONIA] Día 16 · Pronósticos de series de tiempo vs reales (Flores y Cubijíes)")
datos_g <- pred_test %>% filter(cod_parroquia %in% names(PARROQUIAS_FOCO),
                                str_detect(modelo, "Serie|promedio")) %>%
  left_join(nombres_parroquia, by = "cod_parroquia")
reales_g <- datos_g %>% distinct(parroquia_corta, semana_inicio, real)   # una barra por semana
g <- ggplot(datos_g, aes(semana_inicio)) +
  geom_col(data = reales_g, aes(y = real), fill = "grey80") +
  geom_line(aes(y = prediccion, colour = modelo), linewidth = 0.8) +
  facet_wrap(~parroquia_corta, ncol = 1, scales = "free_y") +
  labs(title = "Año de prueba: real (barras) vs pronóstico", x = NULL,
       y = "Incidentes por semana", colour = NULL) + tema_stanford +
  theme(legend.position = "bottom")
guardar_grafico(g, "10_3_series_tiempo_foco.png", alto = 7)

# =============================================================================
# DÍA 17
# =============================================================================
titulo("[NELCY] Día 17 · Pliegues de validación cruzada temporal")
# 5 pliegues de 13 semanas al final del entrenamiento; cada pliegue entrena
# con TODO lo anterior (ventana creciente). Nunca se usa el futuro.
semanas_tr <- sort(unique(train$semana_inicio))
n_sem <- length(semanas_tr)
pliegues_def <- lapply(5:1, function(k) {
  fin <- n_sem - (k - 1) * 13; ini <- fin - 12
  list(analysis   = which(train$semana_inicio <  semanas_tr[ini]),
       assessment = which(train$semana_inicio >= semanas_tr[ini] &
                            train$semana_inicio <= semanas_tr[fin]))
})
pliegues <- manual_rset(lapply(pliegues_def, make_splits, data = datos_ml(train)),
                        ids = paste0("Pliegue", 1:5))
print(tibble(pliegue = paste0("Pliegue", 1:5),
             evalua_desde = sapply(pliegues_def, function(p) as.character(min(train$semana_inicio[p$assessment]))),
             evalua_hasta = sapply(pliegues_def, function(p) as.character(max(train$semana_inicio[p$assessment]))),
             filas_entrena = sapply(pliegues_def, function(p) length(p$analysis))))

titulo("[RUBÉN] Día 17 · Ajuste de hiperparámetros con tune")
metr <- metric_set(mae, rmse)
wf_rf_tune <- wf_rf %>% update_model(rand_forest(mode = "regression", trees = 500, mtry = tune(),
                                                 min_n = tune()) %>%
                                       set_engine("ranger", importance = "impurity", seed = 2026))
tune_rf <- tune_grid(
  wf_rf_tune,
  resamples = pliegues, metrics = metr,
  grid = expand_grid(mtry = c(4, 8, 16), min_n = c(5, 20)))
wf_xgb_tune <- wf_xgb %>% update_model(boost_tree(mode = "regression", trees = tune(),
                                                  tree_depth = tune(), learn_rate = tune()) %>%
                                         set_engine("xgboost", objective = "count:poisson"))
tune_xgb <- tune_grid(
  wf_xgb_tune,
  resamples = pliegues, metrics = metr,
  grid = expand_grid(trees = c(300, 700), tree_depth = c(3, 6), learn_rate = c(0.03, 0.1)))
tabla_tuning <- bind_rows(
  collect_metrics(tune_rf) %>% mutate(modelo = "Random forest"),
  collect_metrics(tune_xgb) %>% mutate(modelo = "XGBoost")) %>%
  select(modelo, .metric, mean, std_err, any_of(c("mtry", "min_n", "trees", "tree_depth", "learn_rate")))
print(tabla_tuning %>% filter(.metric == "mae") %>% arrange(modelo, mean), n = 30)

mejor_rf <- select_best(tune_rf, metric = "mae")
mejor_xgb <- select_best(tune_xgb, metric = "mae")
fit_rf_aj <- finalize_workflow(wf_rf_tune, mejor_rf) %>% fit(datos_ml(train))
fit_xgb_aj <- finalize_workflow(wf_xgb_tune, mejor_xgb) %>% fit(datos_ml(train))
pred_test <- bind_rows(pred_test,
  test %>% transmute(cod_parroquia, semana_inicio, real = incidentes,
                     modelo = "Random forest ajustado",
                     prediccion = predict(fit_rf_aj, datos_ml(test))$.pred),
  test %>% transmute(cod_parroquia, semana_inicio, real = incidentes,
                     modelo = "XGBoost ajustado",
                     prediccion = predict(fit_xgb_aj, datos_ml(test))$.pred))

titulo("[SONIA] Día 17 · Desempeño por pliegue")
por_pliegue <- bind_rows(
  collect_metrics(tune_rf, summarize = FALSE) %>% inner_join(mejor_rf, by = c("mtry", "min_n")) %>%
    mutate(modelo = "Random forest"),
  collect_metrics(tune_xgb, summarize = FALSE) %>%
    inner_join(mejor_xgb, by = c("trees", "tree_depth", "learn_rate")) %>% mutate(modelo = "XGBoost"))
g <- por_pliegue %>% filter(.metric == "mae") %>%
  ggplot(aes(id, .estimate, colour = modelo, group = modelo)) + geom_line() + geom_point(size = 2) +
  labs(title = "MAE de cada pliegue (mejor configuración)", x = NULL, y = "MAE", colour = NULL) +
  tema_stanford
guardar_grafico(g, "10_4_mae_por_pliegue.png")


# =============================================================================
# DÍA 18
# =============================================================================
titulo("[RUBÉN] Día 18 · Tabla comparativa y selección del modelo POR ZONA")
grupos <- function(d) bind_rows(
  d %>% mutate(grupo = "Todas las parroquias"),
  d %>% filter(cod_parroquia == "060150") %>% mutate(grupo = "Urbana (Riobamba)"),
  d %>% filter(cod_parroquia != "060150") %>% mutate(grupo = "Rurales"),
  d %>% filter(cod_parroquia == "060153") %>% mutate(grupo = "Cubijíes"),
  d %>% filter(cod_parroquia == "060154") %>% mutate(grupo = "Flores"))
calcular_tablas <- function(pt) {
  tm <- pt %>% grupos() %>% group_by(grupo, modelo) %>% metricas() %>%
    mutate(across(c(MAE, RMSE), ~ round(.x, 2)))
  rm <- tm %>% select(grupo, modelo, MAE) %>%
    pivot_wider(names_from = grupo, values_from = MAE) %>% arrange(`Todas las parroquias`)
  list(tm = tm, rm = rm)
}
tt <- calcular_tablas(pred_test)

# La parroquia urbana (~800 casos/semana) domina el error general, por eso se
# elige un modelo para la ciudad y otro para las parroquias rurales.
# Combinaciones (promedio de modelos). En la revisión de modelos (carpeta
# revision/, 02-nov) fueron las mejores: en la ciudad RF + XGBoost + binomial
# negativa (MAE 32,1) y en las rurales Poisson + promedio de 12 semanas (2,04).
COMBINACIONES <- list(
  "Combinación urbana (RF + XGBoost + BinNeg)" = c("Random forest", "XGBoost", "Binomial negativa"),
  "Combinación rural (Poisson + promedio 12 sem.)" = c("Regresión Poisson", "Base: promedio 12 semanas"))
for (cn in names(COMBINACIONES)) {
  comp <- COMBINACIONES[[cn]]
  if (!all(comp %in% pred_test$modelo)) next
  pred_test <- bind_rows(pred_test, pred_test %>% filter(modelo %in% comp) %>%
    group_by(cod_parroquia, semana_inicio, real) %>%
    summarise(prediccion = mean(prediccion), .groups = "drop") %>% mutate(modelo = cn))
}
tt <- calcular_tablas(pred_test)
candidatos <- c("Base: promedio 4 semanas", "Base: promedio 12 semanas", "Regresión Poisson",
                "Binomial negativa", "Random forest", "XGBoost", "Random forest ajustado",
                "XGBoost ajustado", names(COMBINACIONES))
mejor_en <- function(g) tt$tm %>% filter(grupo == g, modelo %in% candidatos) %>%
  arrange(MAE) %>% slice(1) %>% pull(modelo)
elegido_urbana <- mejor_en("Urbana (Riobamba)")
elegido_rural  <- mejor_en("Rurales")
elegido <- "Elegido por zona"
pred_test <- bind_rows(pred_test, bind_rows(
  pred_test %>% filter(modelo == elegido_urbana, cod_parroquia == "060150"),
  pred_test %>% filter(modelo == elegido_rural,  cod_parroquia != "060150")) %>%
    mutate(modelo = elegido))
tt <- calcular_tablas(pred_test)
tabla_metricas <- tt$tm; resumen_metricas <- tt$rm
mejor_global <- resumen_metricas$modelo[1]
print(resumen_metricas, n = Inf, width = Inf)
message("\n>>> URBANA: ", elegido_urbana, "  ·  RURALES: ", elegido_rural)

# ¿Cuánto error es inevitable? Si los casos ocurren al azar (Poisson), incluso un
# modelo "perfecto" que conociera la media real de la semana tendría este MAE.
# Sirve para juzgar a los modelos con justicia.
piso_poisson <- function(l) { k <- 0:ceiling(l + 10 * sqrt(l) + 20); sum(abs(k - l) * dpois(k, l)) }
limite_azar <- test %>% group_by(cod_parroquia, parroquia_corta) %>%
  summarise(media_semanal = mean(incidentes), .groups = "drop") %>%
  mutate(MAE_modelo_perfecto = round(sapply(media_semanal, piso_poisson), 2)) %>%
  left_join(pred_test %>% filter(modelo == elegido) %>% group_by(cod_parroquia) %>%
              summarise(MAE_modelo = round(mean(abs(real - prediccion)), 2)), by = "cod_parroquia") %>%
  mutate(error_relativo_pct = round(100 * MAE_modelo / media_semanal))
print(limite_azar)

titulo("[NELCY] Día 18 · Reales vs predicción del modelo elegido")
comparacion <- pred_test %>% filter(modelo == elegido) %>%
  left_join(nombres_parroquia, by = "cod_parroquia") %>%
  group_by(parroquia_corta) %>%
  summarise(real_total = sum(real), predicho_total = round(sum(prediccion)),
            MAE = round(mean(abs(real - prediccion)), 2), .groups = "drop")
print(comparacion)

titulo("[SONIA] Día 18 · Gráficos de métricas y predicción vs real")
g <- tabla_metricas %>% filter(grupo %in% c("Urbana (Riobamba)", "Cubijíes", "Flores")) %>%
  ggplot(aes(reorder(modelo, -MAE), MAE, fill = modelo == elegido)) + geom_col() + coord_flip() +
  facet_wrap(~grupo, scales = "free_x") +
  scale_fill_manual(values = c(`TRUE` = "#d4593a", `FALSE` = "#9db7d1"), guide = "none") +
  labs(title = "MAE en el año de prueba (menor es mejor)",
       subtitle = paste0("Rojo: elegido por zona (urbana: ", elegido_urbana, " · rurales: ", elegido_rural, ")"),
       x = NULL, y = "MAE (incidentes por semana)") + tema_stanford
guardar_grafico(g, "10_5_metricas_modelos.png", ancho = 12, alto = 6)
g <- pred_test %>% filter(modelo == elegido) %>% left_join(nombres_parroquia, by = "cod_parroquia") %>%
  ggplot(aes(semana_inicio)) + geom_line(aes(y = real), colour = "grey60") +
  geom_line(aes(y = prediccion), colour = "#d4593a") +
  facet_wrap(~parroquia_corta, scales = "free_y") +
  labs(title = "Real (gris) vs predicción (rojo) · modelo elegido por zona", x = NULL,
       y = "Incidentes por semana") + tema_stanford
guardar_grafico(g, "10_6_real_vs_prediccion.png", ancho = 12, alto = 8)

titulo("[MELANIE] Día 18 · Variables de los modelos elegidos")
importancia_de <- function(nombre) tryCatch({
  if (nombre %in% names(COMBINACIONES)) {
    bind_rows(lapply(COMBINACIONES[[nombre]], function(x)
      importancia_de(x) %>% mutate(componente = x)))
  } else if (str_detect(nombre, "Random forest")) {
    eng <- extract_fit_engine(if (nombre == "Random forest") fit_rf else fit_rf_aj)
    tibble(variable = names(eng$variable.importance), importancia = eng$variable.importance)
  } else if (str_detect(nombre, "XGBoost")) {
    xgboost::xgb.importance(model = extract_fit_engine(
      if (nombre == "XGBoost") fit_xgb else fit_xgb_aj)) %>%
      as_tibble() %>% transmute(variable = Feature, importancia = Gain)
  } else if (nombre %in% c("Regresión Poisson", "Binomial negativa")) {
    m <- if (nombre == "Regresión Poisson") m_poisson else m_nb
    broom::tidy(m) %>% filter(term != "(Intercept)") %>%
      transmute(variable = term, importancia = abs(statistic))
  } else tibble(variable = if_else(str_detect(nombre, "12"), "ma12 (promedio de 12 semanas)",
                                   "ma4 (promedio de 4 semanas)"), importancia = 1)
}, error = function(e) tibble(variable = character(), importancia = numeric()))
importancia <- bind_rows(
  importancia_de(elegido_urbana) %>% mutate(zona = paste("Urbana ·", elegido_urbana)),
  importancia_de(elegido_rural) %>% mutate(zona = paste("Rurales ·", elegido_rural))) %>%
  mutate(componente = if ("componente" %in% names(.)) coalesce(componente, zona) else zona) %>%
  group_by(zona, componente) %>% arrange(desc(importancia), .by_group = TRUE) %>%
  mutate(importancia_rel = round(100 * importancia / max(importancia), 1)) %>% ungroup()
print(importancia %>% group_by(zona, componente) %>% slice_head(n = 6), n = 40)

# =============================================================================
# DÍA 19 · Pronóstico de las próximas 4 semanas (para el dashboard)
# =============================================================================
titulo("[RUBÉN] Día 19 · Pronóstico de las próximas 4 semanas")
# Cada modelo elegido se re-entrena con TODOS los datos y pronostica en forma
# recursiva (la predicción de la semana 1 se usa como rezago de la semana 2...).
todo <- fs
ajustar_final <- function(nombre) {
  if (nombre %in% names(COMBINACIONES))
    return(structure(lapply(COMBINACIONES[[nombre]], ajustar_final), class = "combinacion"))
  ajustar_uno(nombre)
}
ajustar_uno <- function(nombre) switch(nombre,
  "Base: promedio 4 semanas" = "ma4",
  "Base: promedio 12 semanas" = "ma12",
  "Regresión Poisson" = glm(formula_glm, family = poisson(), data = prep_glm(todo)),
  "Binomial negativa" = MASS::glm.nb(formula_glm, data = prep_glm(todo)),
  "Random forest" = fit(wf_rf, datos_ml(todo)),
  "XGBoost" = fit(wf_xgb, datos_ml(todo)),
  "Random forest ajustado" = finalize_workflow(wf_rf_tune, mejor_rf) %>% fit(datos_ml(todo)),
  "XGBoost ajustado" = finalize_workflow(wf_xgb_tune, mejor_xgb) %>% fit(datos_ml(todo)))
modelo_urbana <- ajustar_final(elegido_urbana)
modelo_rural  <- if (elegido_rural == elegido_urbana) modelo_urbana else ajustar_final(elegido_rural)
predecir <- function(m, d) {
  if (inherits(m, "combinacion")) rowMeans(sapply(unclass(m), predecir, d = d))
  else if (identical(m, "ma4")) d$ma4
  else if (identical(m, "ma12")) d$ma12
  else if (inherits(m, "workflow")) predict(m, datos_ml(d))$.pred
  else predict(m, newdata = prep_glm(d), type = "response")
}

historia <- readRDS(file.path(DIR_LIMPIOS, "conteo_parroquia_semana.rds")) %>%
  filter(!(semana_inicio == max(semana_inicio) & !semana_completa)) %>%
  select(cod_parroquia, parroquia_corta, zona_foco, semana_inicio, incidentes, robos, violencia)
extra <- fs %>% select(cod_parroquia, any_of(c("urbana", espaciales))) %>% distinct()
pronosticos <- list()
for (h in 1:4) {
  nueva <- max(historia$semana_inicio) + 7
  recientes <- historia %>% group_by(cod_parroquia) %>% slice_tail(n = 4) %>%
    summarise(robos = as.integer(round(mean(robos))),
              violencia = as.integer(round(mean(violencia))), .groups = "drop")
  fila <- historia %>% distinct(cod_parroquia, parroquia_corta, zona_foco) %>%
    mutate(semana_inicio = nueva, incidentes = NA_integer_) %>% left_join(recientes, by = "cod_parroquia")
  base <- bind_rows(historia, fila) %>% agregar_calendario() %>% agregar_rezagos() %>%
    filter(semana_inicio == nueva) %>% select(-any_of(c("urbana", espaciales))) %>%
    left_join(extra, by = "cod_parroquia") %>%
    mutate(parroquia = factor(cod_parroquia, levels = levels(fs$parroquia)),
           across(where(is.logical) & !any_of("zona_foco"), as.integer))
  p_urb <- predecir(modelo_urbana, base); p_rur <- predecir(modelo_rural, base)
  base$prediccion <- pmax(ifelse(base$cod_parroquia == "060150", p_urb, p_rur), 0)
  pronosticos[[h]] <- base %>% transmute(cod_parroquia, parroquia_corta, zona_foco,
                                         semana_inicio, horizonte = h, prediccion)
  historia <- historia %>% bind_rows(fila %>% mutate(
    incidentes = as.integer(round(base$prediccion[match(cod_parroquia, base$cod_parroquia)]))))
}

# Rango probable y alerta:
#  - Urbana: predicción ± 1,28 × RMSE del año de prueba (80 %).
#  - Rurales: rango Poisson del 80 % (con pocos casos el azar manda).
#  - Índice = pronóstico / promedio de las últimas 52 semanas (100 = normal).
#    Alerta alta si el índice >= 125; media si >= 110.
rmse_urb <- tabla_metricas %>% filter(grupo == "Urbana (Riobamba)", modelo == elegido) %>% pull(RMSE)
media52 <- semanal %>% group_by(cod_parroquia) %>% slice_tail(n = 52) %>%
  summarise(media_52_semanas = mean(incidentes), .groups = "drop")
pronosticos <- bind_rows(pronosticos) %>% left_join(media52, by = "cod_parroquia") %>%
  mutate(urbana = cod_parroquia == "060150",
         rango_bajo = if_else(urbana, pmax(prediccion - 1.2816 * rmse_urb, 0), qpois(0.10, prediccion)),
         rango_alto = if_else(urbana, prediccion + 1.2816 * rmse_urb, qpois(0.90, prediccion)),
         prob_al_menos_1 = round(100 * (1 - exp(-prediccion))),
         indice = round(100 * prediccion / pmax(media_52_semanas, 0.1)),
         alerta = case_when(indice >= 125 ~ "Alta", indice >= 110 ~ "Media", TRUE ~ "Normal"),
         modelo = if_else(urbana, elegido_urbana, elegido_rural),
         across(c(prediccion, rango_bajo, rango_alto, media_52_semanas), ~ round(.x, 1))) %>%
  select(-urbana)
print(pronosticos %>% select(parroquia_corta, semana_inicio, horizonte, prediccion,
                             rango_bajo, rango_alto, prob_al_menos_1, indice, alerta), n = 48)

# ---- Guardar -----------------------------------------------------------------
pred_test_out <- pred_test %>% left_join(nombres_parroquia, by = "cod_parroquia")
saveRDS(pred_test_out, file.path(DIR_MODELOS, "predicciones_prueba.rds"))
saveRDS(pronosticos, file.path(DIR_MODELOS, "pronosticos.rds"))
saveRDS(list(urbana = modelo_urbana, rural = modelo_rural), file.path(DIR_MODELOS, "modelo_final.rds"))
saveRDS(list(elegido = elegido, elegido_urbana = elegido_urbana, elegido_rural = elegido_rural,
             mejor_global = mejor_global, corte = CORTE, predictores = PREDICTORES),
        file.path(DIR_MODELOS, "info_modelo.rds"))
write_xlsx(list("Resumen MAE" = resumen_metricas, "Metricas" = tabla_metricas,
                "Limite del azar" = limite_azar,
                "Tuning" = tabla_tuning, "Por pliegue" = por_pliegue,
                "Reales vs prediccion" = comparacion, "Variables" = importancia,
                "Distribucion objetivo" = dist_obj, "Pronosticos" = pronosticos),
           file.path(DIR_MODELOS, "10_resultados_modelos.xlsx"))
message("\nListo. Siguiente: scripts/11_mapas_riesgo.R y scripts/12_tendencia_2029.R")
