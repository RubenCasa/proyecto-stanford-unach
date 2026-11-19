# =============================================================================
# PROYECTO STANFORD · 01_importar_unir.R
# DÍAS 4 y 5 (22 y 23-oct) · Importación y unificación de las bases (5 años)
#
#   [NELCY]   Día 4: importa los 63 archivos (jul-2021 a sep-2026) y revisa
#             la codificación.  Día 5: une los archivos y revisa con glimpse().
#   [MELANIE] Día 5: compara nombres y tipos de columnas entre archivos.
#   [SONIA]   Día 5: revisa estructura y completitud con skim().
#   [RUBÉN]   Día 5: verifica que existan los campos para generar variables.
#
# MEMORIA: la base nacional tiene unos 18 millones de filas. Para que funcione
# en cualquier computador, de cada archivo se guarda el RESUMEN nacional
# (registros, vacíos, formato) y se conservan completos solo los registros de
# la provincia de Chimborazo.
#
# Salida: 02_datos_limpios/00_base_unificada_chimborazo.rds
#         03_resultados/tablas/01_resumen_importacion.xlsx
# =============================================================================
source("scripts/_comun.R")

COLUMNAS <- c("Fecha", "provincia", "Canton", "Cod_Parroquia",
              "Parroquia", "Servicio", "Subtipo")

archivos <- unlist(lapply(CARPETAS_CRUDOS, function(c)
  list.files(c, pattern = PATRON_BASES, full.names = TRUE)))
archivos <- archivos[!duplicated(basename(archivos))]
if (length(archivos) == 0) stop("No se encontraron archivos emergencias_* / incidentes_*")
message("Archivos encontrados: ", length(archivos))

# -----------------------------------------------------------------------------
# [NELCY] DÍA 4 · Importar cada archivo y revisar la codificación
# -----------------------------------------------------------------------------
titulo("[NELCY] Día 4 · Importación de archivos")

leer_archivo <- function(ruta) {
  if (str_detect(ruta, "\\.xlsx$")) {
    df <- read_excel(ruta, col_types = "text")
    # En Excel la fecha llega como número de serie (ej. 46113) -> día/mes/año
    num <- suppressWarnings(as.numeric(df[[1]]))
    df[[1]] <- ifelse(!is.na(num), format(as.Date(num, origin = "1899-12-30"), "%d/%m/%Y"), df[[1]])
  } else {
    df <- suppressMessages(suppressWarnings(read_delim(
      ruta, delim = ";", col_types = cols(.default = col_character()),
      locale = locale(encoding = "UTF-8"), trim_ws = TRUE)))
  }
  df
}

resumen <- list(); partes <- list()
for (i in seq_along(archivos)) {
  a <- archivos[i]
  df <- leer_archivo(a)
  nombres <- names(df)
  df <- df[, COLUMNAS]
  resumen[[i]] <- tibble(
    archivo       = basename(a),
    formato       = toupper(tools::file_ext(a)),
    registros     = nrow(df),
    columnas      = length(nombres),
    columnas_ok   = all(COLUMNAS %in% nombres),
    columnas_extra = paste(setdiff(nombres, COLUMNAS), collapse = ", "),
    tildes_mal    = sum(str_detect(df$Subtipo, "Ã|Â"), na.rm = TRUE),
    sin_servicio  = sum(is.na(df$Servicio)),
    sin_provincia = sum(is.na(df$provincia)),
    cod_5_digitos = sum(nchar(df$Cod_Parroquia) == 5, na.rm = TRUE),
    fecha_ejemplo = df$Fecha[1]
  )
  partes[[i]] <- df %>% filter(str_squish(provincia) == PROVINCIA) %>%
    mutate(archivo_origen = basename(a))
  message(sprintf("  %2d/%d %-35s %9s registros", i, length(archivos), basename(a),
                  miles(nrow(df))))
  rm(df); invisible(gc())
}
resumen_archivos <- bind_rows(resumen) %>%
  mutate(anio = as.integer(str_extract(archivo, "20\\d\\d"))) %>% arrange(anio, archivo)
print(resumen_archivos %>% select(archivo, registros, columnas, tildes_mal), n = Inf)
message("TOTAL NACIONAL: ", miles(sum(resumen_archivos$registros)), " registros en ",
        nrow(resumen_archivos), " archivos")

# -----------------------------------------------------------------------------
# [MELANIE] DÍA 5 · ¿Coinciden nombres y tipos de columnas entre archivos?
# -----------------------------------------------------------------------------
titulo("[MELANIE] Día 5 · Comparación de columnas entre archivos")
print(resumen_archivos %>% count(columnas_ok, columnas, columnas_extra, name = "archivos"))
message("Diferencias de formato encontradas:\n",
        " - Nombres: 2021-2023 se llaman 'emergencias_', 2024-2026 'incidentes_'.\n",
        " - Fecha: texto día/mes/año en CSV; fecha nativa en los Excel de 2026.\n",
        " - Cod_Parroquia: en ", sum(resumen_archivos$cod_5_digitos > 0),
        " archivos perdió el 0 inicial (5 dígitos).\n",
        " - Columnas vacías extra en: ",
        paste(resumen_archivos$archivo[resumen_archivos$columnas > 7], collapse = ", "))

# -----------------------------------------------------------------------------
# [NELCY] DÍA 5 · Unificación y glimpse()
# -----------------------------------------------------------------------------
titulo("[NELCY] Día 5 · Unificación")
base_unificada <- bind_rows(partes); rm(partes)
message("Base unificada de Chimborazo: ", miles(nrow(base_unificada)), " registros · ",
        ncol(base_unificada), " columnas")
glimpse(base_unificada)

# -----------------------------------------------------------------------------
# [SONIA] DÍA 5 · skim()
# -----------------------------------------------------------------------------
titulo("[SONIA] Día 5 · skim() de la base unificada")
print(skimr::skim(base_unificada))

# -----------------------------------------------------------------------------
# [RUBÉN] DÍA 5 · Campos para construir variables
# -----------------------------------------------------------------------------
titulo("[RUBÉN] Día 5 · Campos necesarios para generar variables")
necesarios <- c(Fecha = "calendario (semana, mes, feriados)",
                Cod_Parroquia = "unidad espacial (parroquia)",
                Servicio = "filtro de Seguridad Ciudadana",
                Subtipo = "tipo de incidente / categorías")
print(tibble(campo = names(necesarios), uso = necesarios,
             presente = names(necesarios) %in% names(base_unificada),
             pct_completo = round(100 * sapply(names(necesarios), function(c)
               mean(!is.na(base_unificada[[c]]))), 2)))

# ---- Guardar -----------------------------------------------------------------
saveRDS(base_unificada, file.path(DIR_LIMPIOS, "00_base_unificada_chimborazo.rds"))
saveRDS(resumen_archivos, file.path(DIR_LIMPIOS, "00_resumen_nacional.rds"))
guardar_tabla(list("Archivos" = resumen_archivos,
                   "Archivos por anio" = resumen_archivos %>% group_by(anio) %>%
                     summarise(archivos = n(), registros = sum(registros))),
              "01_resumen_importacion.xlsx")
message("\nListo -> ahora ejecuta scripts/02_limpieza.R")
