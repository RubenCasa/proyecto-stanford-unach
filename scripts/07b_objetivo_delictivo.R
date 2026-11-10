# =============================================================================
# PROYECTO STANFORD · 07b_objetivo_delictivo.R
# DÍAS 14-15 (9 y 10-nov) · Definición del problema predictivo
#
# Por qué existe este script: en el EDA (días 9-13) se vio que "Seguridad
# Ciudadana" mezcla HECHOS (delitos, convivencia) con PEDIDOS DE SERVICIO
# (patrullaje solicitado, alarmas) y TRÁMITES (fichas de datos, boletas,
# resguardo de valores). Solo los hechos son "patrones delictivos". Aquí se
# clasifica cada registro y se redefine la variable a predecir.
#
# DÍA 14 [SONIA]   Subtipos relevantes: tipo de registro de cada subtipo.
#        [MELANIE] Diccionario: definición de tipo_registro y de la nueva
#                  variable objetivo.
#        [RUBÉN]   Nueva variable objetivo: incidentes delictivos
#                  (delitos + convivencia) por parroquia y semana.
#        [NELCY]   Verifica que no se pierda ningún registro al reclasificar.
# DÍA 15 [SONIA]   Tendencia por tipo de registro (lo que realmente bajó).
#
# Entrada: 02_datos_limpios/riobamba_depurada.rds, conteo_parroquia_semana.rds
# Salida:  riobamba_depurada.rds (+ tipo_registro), conteo_parroquia_fecha.rds y
#          conteo_parroquia_semana.rds con el objetivo nuevo,
#          03_resultados/tablas/07b_objetivo_delictivo.xlsx
# =============================================================================
source("scripts/_comun.R")

rb <- readRDS(file.path(DIR_LIMPIOS, "riobamba_depurada.rds"))
n_registros <- nrow(rb)

# -----------------------------------------------------------------------------
# [SONIA] DÍA 14 · Subtipos relevantes: tipo de registro
# -----------------------------------------------------------------------------
titulo("[SONIA] Día 14 · Tipo de registro de cada subtipo")
rb <- rb %>%
  mutate(categoria = if_else(servicio == SERVICIO_FOCO, categorizar(subtipo), NA_character_),
         tipo_registro = tipo_registro(categoria, subtipo),
         delictivo = tipo_registro %in% c("Delito", "Convivencia y orden público"))
resumen_tipo <- rb %>% filter(servicio == SERVICIO_FOCO) %>%
  count(tipo_registro, name = "registros", sort = TRUE) %>%
  mutate(pct = round(100 * registros / sum(registros), 1))
print(resumen_tipo)
subtipos_tipo <- rb %>% filter(servicio == SERVICIO_FOCO) %>%
  count(tipo_registro, categoria, subtipo, name = "registros") %>%
  arrange(tipo_registro, desc(registros))
message("Solo el ", resumen_tipo$pct[resumen_tipo$tipo_registro == "Delito"],
        " % de Seguridad Ciudadana son delitos; los pedidos de patrullaje y los trámites ",
        "no son hechos delictivos y salen de la variable objetivo.")

# -----------------------------------------------------------------------------
# [NELCY] DÍA 14 · Ningún registro se pierde al reclasificar
# -----------------------------------------------------------------------------
titulo("[NELCY] Día 14 · Verificación de totales")
stopifnot(nrow(rb) == n_registros,
          all(!is.na(rb$tipo_registro[rb$servicio == SERVICIO_FOCO])))
print(rb %>% filter(servicio == SERVICIO_FOCO) %>%
        summarise(seguridad_ciudadana = n(), delictivos = sum(delictivo),
                  no_delictivos = sum(!delictivo)))

# -----------------------------------------------------------------------------
# [RUBÉN] DÍA 14 · Nueva variable objetivo por parroquia y fecha/semana
# -----------------------------------------------------------------------------
titulo("[RUBÉN] Día 14 · Variable objetivo: incidentes delictivos")
sc <- rb %>% filter(servicio == SERVICIO_FOCO)
parroquias <- rb %>% distinct(cod_parroquia, parroquia_corta, zona_foco) %>% arrange(cod_parroquia)
fechas <- seq(min(rb$fecha), max(rb$fecha), by = "day")

conteo_fecha <- sc %>%
  group_by(cod_parroquia, fecha) %>%
  summarise(incidentes  = sum(delictivo),                       # OBJETIVO
            delitos     = sum(tipo_registro == "Delito"),
            convivencia = sum(tipo_registro == "Convivencia y orden público"),
            robos       = sum(categoria == "Delitos contra la propiedad"),
            violencia   = sum(categoria %in% c("Violencia intrafamiliar / de género",
                                               "Delitos contra las personas")),
            seguridad_ciudadana = n(),                          # objetivo anterior
            .groups = "drop") %>%
  right_join(expand_grid(cod_parroquia = parroquias$cod_parroquia, fecha = fechas),
             by = c("cod_parroquia", "fecha")) %>%
  mutate(across(c(incidentes, delitos, convivencia, robos, violencia, seguridad_ciudadana),
                ~ replace_na(.x, 0L))) %>%
  left_join(parroquias, by = "cod_parroquia") %>%
  arrange(cod_parroquia, fecha)
stopifnot(sum(conteo_fecha$incidentes) == sum(sc$delictivo),
          sum(conteo_fecha$seguridad_ciudadana) == nrow(sc))

conteo_semana <- conteo_fecha %>%
  mutate(semana_inicio = floor_date(fecha, "week", week_start = 1)) %>%
  group_by(cod_parroquia, parroquia_corta, zona_foco, semana_inicio) %>%
  summarise(across(c(incidentes, delitos, convivencia, robos, violencia, seguridad_ciudadana), sum),
            dias_observados = n(), .groups = "drop") %>%
  mutate(semana_completa = dias_observados == 7) %>%
  agregar_calendario() %>%
  arrange(cod_parroquia, semana_inicio)

comparacion <- conteo_semana %>% filter(semana_completa) %>%
  group_by(parroquia_corta) %>%
  summarise(media_semanal_antes = round(mean(seguridad_ciudadana), 2),
            media_semanal_ahora = round(mean(incidentes), 2),
            media_semanal_delitos = round(mean(delitos), 2),
            pct_semanas_cero_ahora = round(100 * mean(incidentes == 0), 1),
            .groups = "drop") %>%
  arrange(desc(media_semanal_ahora))
print(comparacion, n = Inf)

# -----------------------------------------------------------------------------
# [MELANIE] DÍA 14 · Diccionario de la nueva variable objetivo
# -----------------------------------------------------------------------------
titulo("[MELANIE] Día 14 · Definiciones")
definiciones <- tibble::tribble(
  ~variable, ~definicion,
  "tipo_registro", "Delito / Convivencia y orden público / Servicio policial solicitado / Trámite u operativo / Personas desaparecidas o muertes (solo Seguridad Ciudadana)",
  "delictivo", "TRUE si tipo_registro es Delito o Convivencia y orden público",
  "incidentes", "OBJETIVO: incidentes delictivos (delitos + convivencia) de la parroquia en el día o la semana",
  "delitos", "Solo delitos (propiedad, personas, violencia intrafamiliar, drogas)",
  "convivencia", "Libadores, escándalos, fiestas, riñas, ruido",
  "seguridad_ciudadana", "Todos los registros de Seguridad Ciudadana (objetivo usado hasta el día 13, se guarda para comparar)"
)
print(definiciones)

# -----------------------------------------------------------------------------
# [SONIA] DÍA 15 · Tendencia por tipo de registro
# -----------------------------------------------------------------------------
titulo("[SONIA] Día 15 · ¿Qué bajó realmente?")
por_anio <- sc %>% count(anio, tipo_registro) %>%
  left_join(rb %>% group_by(anio) %>% summarise(dias = n_distinct(fecha)), by = "anio") %>%
  mutate(promedio_diario = round(n / dias, 1))
print(por_anio %>% select(anio, tipo_registro, promedio_diario) %>%
        pivot_wider(names_from = anio, values_from = promedio_diario))
g <- ggplot(por_anio, aes(anio, promedio_diario, colour = tipo_registro)) +
  geom_line(linewidth = 1) + geom_point() +
  labs(title = "Seguridad Ciudadana por tipo de registro · Riobamba",
       subtitle = "Bajan los pedidos de patrullaje y, hasta 2023, la convivencia; los delitos se mantienen estables",
       x = NULL, y = "Promedio diario", colour = NULL) +
  tema_stanford + theme(legend.position = "bottom") +
  guides(colour = guide_legend(nrow = 2))
guardar_grafico(g, "07b_1_tipo_registro_anual.png")

delitos_subtipo <- sc %>% filter(tipo_registro == "Delito") %>%
  count(anio, subtipo) %>% group_by(subtipo) %>% filter(sum(n) >= 500) %>% ungroup() %>%
  left_join(rb %>% group_by(anio) %>% summarise(dias = n_distinct(fecha)), by = "anio") %>%
  mutate(por_100_dias = round(100 * n / dias, 1))
g2 <- ggplot(delitos_subtipo, aes(anio, por_100_dias, colour = subtipo)) +
  geom_line(linewidth = 1) + geom_point() +
  labs(title = "Delitos más frecuentes por año · Riobamba",
       x = NULL, y = "Casos por cada 100 días", colour = NULL) +
  tema_stanford + theme(legend.position = "bottom") +
  guides(colour = guide_legend(ncol = 2))
guardar_grafico(g2, "07b_2_delitos_por_anio.png", alto = 6.5)

# ---- Guardar ------------------------------------------------------------------
saveRDS(rb, file.path(DIR_LIMPIOS, "riobamba_depurada.rds"))
write_csv(rb, file.path(DIR_LIMPIOS, "riobamba_depurada.csv"))
saveRDS(conteo_fecha,  file.path(DIR_LIMPIOS, "conteo_parroquia_fecha.rds"))
saveRDS(conteo_semana, file.path(DIR_LIMPIOS, "conteo_parroquia_semana.rds"))
guardar_tabla(list("Tipo de registro" = resumen_tipo,
                   "Subtipos por tipo" = subtipos_tipo,
                   "Antes vs ahora" = comparacion,
                   "Definiciones" = definiciones,
                   "Por año" = por_anio),
              "07b_objetivo_delictivo.xlsx")
message("Listo -> el objetivo de los modelos ahora es 'incidentes delictivos'. Sigue 08 y 09.")
