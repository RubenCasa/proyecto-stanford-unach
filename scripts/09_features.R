# =============================================================================
# PROYECTO STANFORD · 09_features.R
# DÍAS 11-13 (4 al 6-nov) · EDA espacial e ingeniería de características
#
# DÍA 11 [RUBÉN]   Conteos por parroquia y semana para la capa espacial.
#        [NELCY]   Tablas de conteo por parroquia para los mapas.
#        [MELANIE] Verifica nombres y códigos de parroquia usados en los mapas.
#        (Edgar: mapas en 08_mapas.R · Sonia: reporte_EDA.qmd)
# DÍA 12 [RUBÉN]   Rezagos y promedios móviles por parroquia.
#        [EDGAR]   Variables espaciales (área, urbana, vecinos).
#        [SONIA]   Gráficos del comportamiento de las variables nuevas.
#        [MELANIE] Diccionario de las variables nuevas.
# DÍA 13 [RUBÉN]   Matriz de características (Feature Store) consolidada.
#        [NELCY]   Verifica que no haya perdidos ni duplicados.
#        [MELANIE] Consistencia matriz vs diccionario.
#
# Entrada: 02_datos_limpios/conteo_parroquia_semana.rds
# Salida:  02_datos_limpios/feature_store.rds (+ .csv)
# =============================================================================
source("scripts/_comun.R")

semanal <- readRDS(file.path(DIR_LIMPIOS, "conteo_parroquia_semana.rds"))
ruta_capa <- file.path(DIR_MAPAS, "parroquias_riobamba.gpkg")

# =============================================================================
# DÍA 11
# =============================================================================
titulo("[RUBÉN] Día 11 · Conteos por parroquia y semana para la capa espacial")
capa_espacial <- semanal %>% filter(semana_completa) %>%
  group_by(cod_parroquia, parroquia_corta, anio) %>%
  summarise(semanas = n(), total = sum(incidentes),
            media_semanal = round(mean(incidentes), 2), .groups = "drop")
ultimas_12 <- semanal %>% filter(semana_completa) %>%
  filter(semana_inicio > max(semana_inicio) - weeks(12)) %>%
  group_by(cod_parroquia, parroquia_corta) %>%
  summarise(media_ultimas_12_semanas = round(mean(incidentes), 2), .groups = "drop")
print(ultimas_12)

titulo("[NELCY] Día 11 · Tablas de conteo por parroquia para los mapas")
tabla_mapas <- capa_espacial %>%
  select(cod_parroquia, parroquia_corta, anio, total) %>%
  pivot_wider(names_from = anio, values_from = total, values_fill = 0) %>%
  left_join(ultimas_12, by = c("cod_parroquia", "parroquia_corta"))
print(tabla_mapas)

titulo("[MELANIE] Día 11 · Nombres y códigos usados en los mapas")
if (file.exists(ruta_capa)) {
  capa_nombres <- sf::st_drop_geometry(sf::st_read(ruta_capa, quiet = TRUE))
  revision_mapa <- full_join(
    tabla_mapas %>% select(cod_parroquia, nombre_base = parroquia_corta),
    capa_nombres %>% select(cod_parroquia, nombre_mapa = parroquia_corta),
    by = "cod_parroquia") %>%
    mutate(coincide = nombre_base == nombre_mapa)
  print(revision_mapa)
} else {
  message("Aún no existe la capa del mapa (ejecutar 08_mapas.R).")
  revision_mapa <- tibble()
}

# =============================================================================
# DÍA 12
# =============================================================================
titulo("[RUBÉN] Día 12 · Rezagos y promedios móviles por parroquia")
# Importante: cada variable usa SOLO semanas anteriores (sin fuga de información)
fs <- semanal %>% agregar_rezagos()
print(fs %>% filter(cod_parroquia == "060153") %>%
        select(semana_inicio, incidentes, lag1, lag2, ma4, ma8) %>% tail(8))

titulo("[EDGAR] Día 12 · Variables espaciales")
if (file.exists(ruta_capa)) {
  capa <- sf::st_read(ruta_capa, quiet = TRUE)
  vecinos <- sf::st_touches(capa)
  espacial <- sf::st_drop_geometry(capa) %>%
    transmute(cod_parroquia, area_km2, n_vecinos = lengths(vecinos))
} else {
  message("Sin capa de mapa: se usan solo variables espaciales básicas.")
  espacial <- tibble(cod_parroquia = unique(fs$cod_parroquia), area_km2 = NA_real_,
                     n_vecinos = NA_integer_)
}
fs <- fs %>% left_join(espacial, by = "cod_parroquia") %>%
  mutate(urbana = cod_parroquia == "060150")
print(espacial)

titulo("[SONIA] Día 12 · Comportamiento de las variables nuevas")
g1 <- fs %>% filter(semana_completa, !is.na(lag1)) %>%
  ggplot(aes(lag1 + 1, incidentes + 1)) +
  geom_point(alpha = 0.3, colour = "#1f5f99") +
  scale_x_log10() + scale_y_log10() + facet_wrap(~parroquia_corta, scales = "free") +
  labs(title = "Incidentes de la semana vs. semana anterior (lag1)",
       subtitle = "Escala log(x+1) · cada panel es una parroquia",
       x = "Semana anterior + 1", y = "Semana actual + 1") + tema_stanford
guardar_grafico(g1, "09_1_lag1_vs_actual.png", ancho = 12, alto = 8)

g2 <- fs %>% filter(semana_completa, zona_foco) %>%
  select(semana_inicio, parroquia_corta, incidentes, ma4, ma12) %>%
  pivot_longer(c(incidentes, ma4, ma12), names_to = "serie") %>%
  ggplot(aes(semana_inicio, value, colour = serie)) + geom_line() +
  facet_wrap(~parroquia_corta, ncol = 1, scales = "free_y") +
  scale_colour_manual(values = c(incidentes = "grey70", ma4 = "#1f5f99", ma12 = "#d4593a")) +
  labs(title = "Flores y Cubijíes: semanal vs. promedios móviles",
       x = NULL, y = "Incidentes", colour = NULL) + tema_stanford
guardar_grafico(g2, "09_2_promedios_moviles_foco.png", alto = 7)

correlaciones <- fs %>% filter(semana_completa) %>%
  select(incidentes, lag1, lag2, lag4, lag52, ma4, ma8, ma12, robos_lag1, violencia_lag1) %>%
  cor(use = "pairwise.complete.obs") %>% round(2)
print(correlaciones[, "incidentes"])

# =============================================================================
# DÍA 13
# =============================================================================
titulo("[RUBÉN] Día 13 · Matriz de características (Feature Store)")
VARIABLES_MODELO <- c("lag1", "lag2", "lag3", "lag4", "lag52", "ma4", "ma8", "ma12",
                      "robos_lag1", "violencia_lag1", "semana_iso", "mes_num", "trimestre",
                      "sin_semana", "cos_semana", "n_feriados", "semana_pago",
                      "fin_de_mes", "tendencia", "urbana")
feature_store <- fs %>%
  filter(semana_completa) %>%
  filter(if_all(all_of(VARIABLES_MODELO), ~ !is.na(.x))) %>%   # el primer año pierde lag52
  select(cod_parroquia, parroquia_corta, zona_foco, semana_inicio, anio,
         incidentes, all_of(VARIABLES_MODELO), any_of(c("area_km2", "n_vecinos")))
message("Feature Store: ", miles(nrow(feature_store)), " filas × ", ncol(feature_store),
        " columnas · desde ", min(feature_store$semana_inicio), " hasta ",
        max(feature_store$semana_inicio))

titulo("[NELCY] Día 13 · Perdidos y duplicados en la matriz")
perdidos <- colSums(is.na(feature_store))
print(perdidos[perdidos > 0])
dups <- sum(duplicated(feature_store[c("cod_parroquia", "semana_inicio")]))
message("Duplicados parroquia-semana: ", dups)
stopifnot(dups == 0)

titulo("[MELANIE] Días 12-13 · Diccionario de variables nuevas")
dicc_features <- tribble(
  ~variable, ~descripcion,
  "incidentes", "OBJETIVO: incidentes delictivos (delitos + convivencia) en la parroquia y semana; ver 07b",
  "lag1, lag2, lag3, lag4", "Incidentes de 1, 2, 3 y 4 semanas antes",
  "lag52", "Incidentes de la misma semana del año anterior",
  "ma4, ma8, ma12", "Promedio de las 4, 8 y 12 semanas anteriores (sin incluir la actual)",
  "robos_lag1", "Delitos contra la propiedad de la semana anterior",
  "violencia_lag1", "Violencia intrafamiliar y delitos contra las personas de la semana anterior",
  "semana_iso, mes_num, trimestre", "Calendario de la semana (ISO)",
  "sin_semana, cos_semana", "Estacionalidad anual (forma circular de la semana del año)",
  "n_feriados", "Número de feriados nacionales o locales en la semana",
  "semana_pago", "TRUE si la semana incluye el día 15 o fin de mes",
  "fin_de_mes", "TRUE si la semana cruza el cambio de mes",
  "tendencia", "Semanas transcurridas desde el inicio de los datos",
  "urbana", "TRUE para la parroquia urbana de Riobamba (060150)",
  "area_km2", "Área de la parroquia (de la capa de mapas)",
  "n_vecinos", "Número de parroquias vecinas (de la capa de mapas)"
)
en_matriz <- names(feature_store)
consistencia <- tibble(variable = en_matriz,
                       documentada = sapply(en_matriz, function(v)
                         any(str_detect(dicc_features$variable, fixed(v))) ||
                           v %in% c("cod_parroquia", "parroquia_corta", "zona_foco",
                                    "semana_inicio", "anio")))
print(consistencia %>% filter(!documentada))

saveRDS(feature_store, file.path(DIR_LIMPIOS, "feature_store.rds"))
write_csv(feature_store, file.path(DIR_LIMPIOS, "feature_store.csv"))
saveRDS(fs, file.path(DIR_LIMPIOS, "features_completas.rds"))   # incluye semanas recientes
write_xlsx(list("Variables nuevas" = dicc_features, "Consistencia" = consistencia),
           file.path(DIR_DOCS, "Diccionario_variables_modelo.xlsx"))
guardar_tabla(list("Capa espacial" = capa_espacial, "Tabla mapas" = tabla_mapas,
                   "Revision mapa" = revision_mapa,
                   "Correlaciones" = as.data.frame(correlaciones) %>%
                     tibble::rownames_to_column("variable")),
              "09_features.xlsx")
message("Listo -> días 14-18: scripts/10_modelos.R")
