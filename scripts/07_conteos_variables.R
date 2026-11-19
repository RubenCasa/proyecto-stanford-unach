# =============================================================================
# PROYECTO STANFORD · 07_conteos_variables.R
# RUBÉN DARÍO CASA CASA · Equipo 1 · Features y modelado
#
# DÍAS 1-3 · Definición (documentada aquí y en la matriz de requerimientos)
#   - Unidad de análisis: parroquia × semana (lunes a domingo).
#   - Variable a predecir: incidentes de Seguridad Ciudadana de la parroquia
#     en la semana (conteo).
#   - Predictores candidatos: calendario, historial de la parroquia (rezagos,
#     promedios móviles), composición (robos, violencia) y variables espaciales.
# DÍA 4 · Paquetes de modelado -> scripts/00_instalar_paquetes.R
# DÍAS 5-7 · Secciones [RUBÉN] de los scripts 01, 02 y 03
#
# ESTE SCRIPT:
# DÍA 8 (28-oct)  Conteos parroquia × fecha (con días en cero).
# DÍA 9 (29-oct)  Conteos parroquia × semana.
# DÍA 10 (30-oct) Variables de calendario (semana, mes, feriados).
#
# Salida: 02_datos_limpios/conteo_parroquia_fecha.rds
#         02_datos_limpios/conteo_parroquia_semana.rds
# =============================================================================
source("scripts/_comun.R")

rb <- readRDS(file.path(DIR_LIMPIOS, "riobamba_depurada.rds"))
sc <- rb %>% filter(servicio == SERVICIO_FOCO)

parroquias <- rb %>% distinct(cod_parroquia, parroquia_corta, zona_foco) %>%
  arrange(cod_parroquia)
stopifnot("Un código tiene dos nombres" = !any(duplicated(parroquias$cod_parroquia)))
message("Parroquias de Riobamba: ", nrow(parroquias))

# -----------------------------------------------------------------------------
# [RUBÉN] DÍA 8 · Conteos parroquia × fecha
# -----------------------------------------------------------------------------
titulo("[RUBÉN] Día 8 · Tabla parroquia × fecha")
fechas <- seq(min(rb$fecha), max(rb$fecha), by = "day")

conteo_fecha <- sc %>%
  group_by(cod_parroquia, fecha) %>%
  summarise(incidentes = n(),
            robos = sum(categoria == "Delitos contra la propiedad"),
            violencia = sum(categoria %in% c("Violencia intrafamiliar / de género",
                                             "Delitos contra las personas")),
            .groups = "drop") %>%
  right_join(expand_grid(cod_parroquia = parroquias$cod_parroquia, fecha = fechas),
             by = c("cod_parroquia", "fecha")) %>%
  mutate(across(c(incidentes, robos, violencia), ~ replace_na(.x, 0L))) %>%
  left_join(parroquias, by = "cod_parroquia") %>%
  arrange(cod_parroquia, fecha)

message("Filas: ", miles(nrow(conteo_fecha)), " (", nrow(parroquias), " parroquias × ",
        length(fechas), " días) · Incidentes: ", miles(sum(conteo_fecha$incidentes)))
stopifnot(sum(conteo_fecha$incidentes) == nrow(sc))   # no se pierde ningún incidente
print(conteo_fecha %>% group_by(parroquia_corta) %>%
        summarise(dias = n(), dias_con_casos = sum(incidentes > 0),
                  promedio_diario = round(mean(incidentes), 2), .groups = "drop"))

# -----------------------------------------------------------------------------
# [RUBÉN] DÍA 9 · Conteos parroquia × semana
# -----------------------------------------------------------------------------
titulo("[RUBÉN] Día 9 · Tabla parroquia × semana")
conteo_semana <- conteo_fecha %>%
  mutate(semana_inicio = floor_date(fecha, "week", week_start = 1)) %>%
  group_by(cod_parroquia, parroquia_corta, zona_foco, semana_inicio) %>%
  summarise(incidentes = sum(incidentes), robos = sum(robos),
            violencia = sum(violencia), dias_observados = n(), .groups = "drop") %>%
  mutate(semana_completa = dias_observados == 7)

message("Semanas completas: ",
        n_distinct(conteo_semana$semana_inicio[conteo_semana$semana_completa]),
        " · incompletas (inicio/fin de datos, no se usan en modelos): ",
        n_distinct(conteo_semana$semana_inicio[!conteo_semana$semana_completa]))

resumen_semanal <- conteo_semana %>% filter(semana_completa) %>%
  group_by(cod_parroquia, parroquia_corta, zona_foco) %>%
  summarise(semanas = n(), total = sum(incidentes),
            media_semanal = round(mean(incidentes), 2),
            varianza = round(var(incidentes), 2),
            pct_semanas_en_cero = round(100 * mean(incidentes == 0), 1),
            maximo = max(incidentes), .groups = "drop") %>%
  arrange(desc(total))
print(resumen_semanal, n = Inf)
message("Varianza > media en casi todas -> sobredispersión: probar binomial negativa.")

# -----------------------------------------------------------------------------
# [RUBÉN] DÍA 10 · Variables de calendario
# -----------------------------------------------------------------------------
titulo("[RUBÉN] Día 10 · Variables de calendario")
conteo_semana <- conteo_semana %>% agregar_calendario() %>%
  arrange(cod_parroquia, semana_inicio)
glimpse(conteo_semana)
print(conteo_semana %>% filter(semana_completa) %>% group_by(semana_feriado) %>%
        summarise(semanas = n_distinct(semana_inicio),
                  media_canton = round(sum(incidentes) / n_distinct(semana_inicio), 1)))

saveRDS(conteo_fecha,  file.path(DIR_LIMPIOS, "conteo_parroquia_fecha.rds"))
saveRDS(conteo_semana, file.path(DIR_LIMPIOS, "conteo_parroquia_semana.rds"))
guardar_tabla(list("Parroquia x semana" = conteo_semana,
                   "Resumen semanal" = resumen_semanal),
              "07_conteos_variables.xlsx")
message("Listo -> días 11-13: scripts/09_features.R")
