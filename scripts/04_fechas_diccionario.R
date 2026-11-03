# =============================================================================
# PROYECTO STANFORD · 04_fechas_diccionario.R
# DÍA 8 (Mié 28-oct) · Corrección de fechas, base depurada y diccionario
#   (también contiene lo que Melanie agrega al diccionario en los días 9 y 10)
#
#   [MELANIE] Día 8: convierte Fecha con lubridate y redacta el diccionario.
#             Día 9: agrega las categorías de Servicio y Subtipo.
#             Día 10: agrega las variables derivadas de la fecha.
#   [SONIA]   Día 8: revisa el rango de fechas por año.
#   [NELCY]   Día 8: guarda la base depurada y el registro de cambios.
#
# Entrada: 02_datos_limpios/02_base_riobamba.rds
# Salida:  02_datos_limpios/riobamba_depurada.rds y .csv
#          05_documentos/Diccionario_de_datos.xlsx
# =============================================================================
source("scripts/_comun.R")

riobamba <- readRDS(file.path(DIR_LIMPIOS, "02_base_riobamba.rds"))

# -----------------------------------------------------------------------------
# [MELANIE] DÍA 8 · Conversión de la fecha con lubridate
# -----------------------------------------------------------------------------
titulo("[MELANIE] Día 8 · Conversión de fechas")
riobamba <- riobamba %>%
  mutate(fecha_texto = fecha,
         fecha = as.Date(parse_date_time(fecha, orders = c("dmy", "ymd"), quiet = TRUE)))
fechas_fallidas <- sum(is.na(riobamba$fecha))
message("Fechas que no se pudieron convertir: ", fechas_fallidas)
if (fechas_fallidas > 0) print(head(riobamba %>% filter(is.na(fecha)) %>% select(fecha_texto)))
riobamba <- riobamba %>% filter(!is.na(fecha)) %>% select(-fecha_texto)

# Coherencia: la fecha debe caer en el mes y año del archivo de origen
meses_archivo <- tolower(MESES)
mes_de_archivo <- sapply(unique(riobamba$archivo_origen), function(a)
  which(sapply(meses_archivo, function(m) str_detect(a, m)))[1])
riobamba <- riobamba %>%
  mutate(mes_archivo = mes_de_archivo[archivo_origen],
         anio_archivo = as.integer(str_extract(archivo_origen, "20\\d\\d")))
incoherentes <- sum(month(riobamba$fecha) != riobamba$mes_archivo |
                      year(riobamba$fecha) != riobamba$anio_archivo, na.rm = TRUE)
message("Fechas fuera del mes/año de su archivo: ", incoherentes)

# -----------------------------------------------------------------------------
# [MELANIE] DÍA 10 · Variables derivadas de la fecha
# -----------------------------------------------------------------------------
riobamba <- riobamba %>%
  mutate(
    anio        = year(fecha),
    mes_num     = month(fecha),
    mes         = factor(MESES[mes_num], levels = MESES),
    semana_inicio = floor_date(fecha, "week", week_start = 1),  # lunes de esa semana
    semana_iso  = isoweek(fecha),
    dia_semana  = factor(DIAS[wday(fecha, week_start = 1)], levels = DIAS),
    fin_semana  = dia_semana %in% c("Sábado", "Domingo"),
    feriado     = fecha %in% FERIADOS$fecha,
    parroquia_corta = nombre_corto(parroquia),
    categoria   = if_else(servicio == SERVICIO_FOCO, categorizar(subtipo), NA_character_)
  ) %>%
  select(-mes_archivo, -anio_archivo)

# -----------------------------------------------------------------------------
# [SONIA] DÍA 8 · Rango de fechas por año
# -----------------------------------------------------------------------------
titulo("[SONIA] Día 8 · Rango de fechas por año")
rango_fechas <- riobamba %>% group_by(anio) %>%
  summarise(desde = min(fecha), hasta = max(fecha),
            dias_con_datos = n_distinct(fecha), registros = n(), .groups = "drop")
print(rango_fechas)

# -----------------------------------------------------------------------------
# [NELCY] DÍA 8 · Guardar base depurada y registro de cambios
# -----------------------------------------------------------------------------
titulo("[NELCY] Día 8 · Base depurada")
riobamba <- riobamba %>%
  select(fecha, anio, mes_num, mes, semana_inicio, semana_iso, dia_semana,
         fin_semana, feriado, provincia, canton, cod_parroquia, parroquia,
         parroquia_corta, zona_foco, servicio, subtipo, categoria, archivo_origen)

saveRDS(riobamba, file.path(DIR_LIMPIOS, "riobamba_depurada.rds"))
write_csv(riobamba, file.path(DIR_LIMPIOS, "riobamba_depurada.csv"))
glimpse(riobamba)

registro_cambios <- tibble(
  paso = 1:8,
  cambio = c("Unión de los archivos mensuales en una sola base",
             "Nombres de columnas estandarizados (janitor::clean_names)",
             "Eliminados registros sin servicio/subtipo o sin ubicación",
             "Cod_Parroquia completado a 6 dígitos (0 inicial)",
             "Espacios sobrantes eliminados en textos (str_squish)",
             "Filtro: Chimborazo > Riobamba; marca de Flores y Cubijíes",
             "Fecha convertida a tipo fecha y variables de calendario",
             "Subtipos de Seguridad Ciudadana agrupados en categorías"),
  script = c("01", "02", "02", "02", "02", "03", "04", "04")
)
print(registro_cambios)

# -----------------------------------------------------------------------------
# [MELANIE] DÍAS 8, 9 y 10 · Diccionario de datos
# -----------------------------------------------------------------------------
titulo("[MELANIE] Diccionario de datos")
descripciones <- c(
  fecha = "Fecha del incidente (AAAA-MM-DD)",
  anio = "Año del incidente (derivada de fecha)",
  mes_num = "Mes en número 1-12 (derivada)",
  mes = "Nombre del mes (derivada)",
  semana_inicio = "Lunes de la semana del incidente; unidad temporal del modelo (derivada)",
  semana_iso = "Número de semana ISO 1-53 (derivada)",
  dia_semana = "Día de la semana, lunes a domingo (derivada)",
  fin_semana = "TRUE si es sábado o domingo (derivada)",
  feriado = "TRUE si la fecha es feriado nacional o local de Riobamba (derivada)",
  provincia = "Provincia donde ocurrió el incidente",
  canton = "Cantón donde ocurrió el incidente",
  cod_parroquia = "Código DPA del INEC de la parroquia (6 dígitos: 2 provincia, 2 cantón, 2 parroquia)",
  parroquia = "Nombre de la parroquia según ECU 911",
  parroquia_corta = "Nombre corto normalizado (sin tildes) para unir con mapas (derivada)",
  zona_foco = "TRUE si es Flores (060154) o Cubijíes (060153), beneficiarias directas",
  servicio = "Servicio del ECU 911 que atendió el incidente",
  categoria = "Agrupación propuesta de los subtipos de Seguridad Ciudadana (derivada)",
  subtipo = "Tipo específico de incidente",
  archivo_origen = "Archivo mensual del que proviene el registro (trazabilidad)"
)
diccionario <- tibble(
  variable = names(riobamba),
  tipo = sapply(riobamba, function(v) class(v)[1]),
  descripcion = descripciones[names(riobamba)],
  origen = ifelse(names(riobamba) %in% c("provincia", "canton", "cod_parroquia",
                                         "parroquia", "servicio", "subtipo", "fecha"),
                  "Original ECU 911", "Derivada"),
  valores_distintos = sapply(riobamba, n_distinct),
  perdidos = sapply(riobamba, function(v) sum(is.na(v))),
  ejemplo = sapply(riobamba, function(v) as.character(v[1]))
)
print(diccionario, n = Inf)

# Día 9: categorías de Servicio y Subtipo
categorias_servicio <- riobamba %>% count(servicio, name = "registros", sort = TRUE)
categorias_subtipo  <- riobamba %>% count(servicio, subtipo, name = "registros") %>%
  arrange(servicio, desc(registros))

# Anonimización: la base no contiene nombres, cédulas, teléfonos, direcciones
# exactas ni hora; el nivel más fino es la parroquia y el día.
# Formato institucional (mismo esquema que formato-diccionario-de-datos_v2.xlsx)
formato_institucional <- bind_rows(
  tibble(campo = c("Institución", "Identificador", "Documento Referencia", "Nombre", "Descripción"),
         descripcion = c("UNACH · Proyecto Stanford (fuente: Servicio Integrado de Seguridad ECU 911)",
                         "DA-ECU-001 (derivado: Riobamba depurada)", "Base de emergencias",
                         "Base depurada de incidentes · cantón Riobamba",
                         "Incidentes coordinados por el ECU 911 en el cantón Riobamba, jul-2021 a sep-2026, depurados para el proyecto")),
  tibble(campo = "Nombre del campo", descripcion = "Descripción del campo"),
  tibble(campo = diccionario$variable, descripcion = diccionario$descripcion)
)
write_xlsx(list("Formato institucional" = formato_institucional,
                "Diccionario" = diccionario,
                "Categorias Servicio" = categorias_servicio,
                "Categorias Subtipo" = categorias_subtipo,
                "Feriados" = FERIADOS,
                "Registro de cambios" = registro_cambios,
                "Rango de fechas" = rango_fechas),
           file.path(DIR_DOCS, "Diccionario_de_datos.xlsx"))
message("Diccionario guardado en ", DIR_DOCS, "/Diccionario_de_datos.xlsx")
message("Listo -> ahora ejecuta scripts/05_eda_frecuencias.R")
