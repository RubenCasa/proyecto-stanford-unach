# =============================================================================
# PROYECTO STANFORD · UNACH · Vinculación con la sociedad
# "Análisis predictivo de patrones delictivos ... Parroquias Flores y Cubijíes"
#
# _comun.R  ->  configuración que usan TODOS los scripts (no se ejecuta solo).
# Cada script lo carga con: source("scripts/_comun.R")
# =============================================================================

suppressPackageStartupMessages({
  library(readr); library(readxl); library(dplyr); library(tidyr)
  library(stringr); library(lubridate); library(ggplot2); library(scales)
  library(writexl)
})

# ---- Carpetas del proyecto ---------------------------------------------------
# Las bases originales (emergencias_*.csv 2021-2023, incidentes_*.csv/xlsx
# 2024-2026) pueden estar en la carpeta principal o en 01_datos_crudos/
CARPETAS_CRUDOS <- c(".", "01_datos_crudos")
PATRON_BASES    <- "^(incidentes|emergencias)_.*\\.(csv|xlsx)$"
DIR_LIMPIOS     <- "02_datos_limpios"
DIR_TABLAS      <- "03_resultados/tablas"
DIR_GRAFICOS    <- "03_resultados/graficos"
DIR_MODELOS     <- "03_resultados/modelos"
DIR_MAPAS       <- "04_mapas"
DIR_DOCS        <- "05_documentos"
for (d in c(DIR_LIMPIOS, DIR_TABLAS, DIR_GRAFICOS, DIR_MODELOS, DIR_MAPAS, DIR_DOCS)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

if (!file.exists("proyecto_stanford.Rproj")) {
  warning("No estás en la carpeta del proyecto. Abre proyecto_stanford.Rproj ",
          "o usa setwd('C:/Users/RubenC/Desktop/PROYECTO STANFORD')")
}

# ---- Zona de estudio ---------------------------------------------------------
PROVINCIA <- "CHIMBORAZO"
CANTON    <- "RIOBAMBA"
PARROQUIAS_FOCO <- c("060153" = "CUBIJÍES", "060154" = "FLORES")   # códigos DPA INEC
SERVICIO_FOCO   <- "Seguridad Ciudadana"

# ---- Etiquetas en español ----------------------------------------------------
MESES <- c("Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio",
           "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre")
DIAS  <- c("Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo")

# ---- Feriados 2021-2027 ------------------------------------------------------
# Se usan las fechas oficiales de cada feriado (nacionales + locales de
# Riobamba). Carnaval y Viernes Santo se calculan desde la fecha de Pascua.
# Los "traslados" de descanso casi siempre caen en la misma semana, por eso
# no cambian el análisis semanal. Los traslados conocidos se agregan abajo.
pascua <- function(y) {
  a <- y %% 19; b <- y %/% 100; c <- y %% 100; d <- b %/% 4; e <- b %% 4
  f <- (b + 8) %/% 25; g <- (b - f + 1) %/% 3; h <- (19 * a + b - d - g + 15) %% 30
  i <- c %/% 4; k <- c %% 4; l <- (32 + 2 * e + 2 * i - h - k) %% 7
  m <- (a + 11 * h + 22 * l) %/% 451
  mes <- (h + l - 7 * m + 114) %/% 31; dia <- ((h + l - 7 * m + 114) %% 31) + 1
  as.Date(sprintf("%d-%02d-%02d", y, mes, dia))
}
anios <- 2021:2027
FERIADOS <- bind_rows(
  tibble(fecha = as.Date(paste0(anios, "-01-01")), feriado = "Año Nuevo"),
  tibble(fecha = pascua(anios) - 48, feriado = "Carnaval (lunes)"),
  tibble(fecha = pascua(anios) - 47, feriado = "Carnaval (martes)"),
  tibble(fecha = pascua(anios) - 2,  feriado = "Viernes Santo"),
  tibble(fecha = as.Date(paste0(anios, "-04-21")), feriado = "Independencia de Riobamba (local)"),
  tibble(fecha = as.Date(paste0(anios, "-05-01")), feriado = "Día del Trabajo"),
  tibble(fecha = as.Date(paste0(anios, "-05-24")), feriado = "Batalla de Pichincha"),
  tibble(fecha = as.Date(paste0(anios, "-08-10")), feriado = "Primer Grito de Independencia"),
  tibble(fecha = as.Date(paste0(anios, "-10-09")), feriado = "Independencia de Guayaquil"),
  tibble(fecha = as.Date(paste0(anios, "-11-02")), feriado = "Día de Difuntos"),
  tibble(fecha = as.Date(paste0(anios, "-11-03")), feriado = "Independencia de Cuenca"),
  tibble(fecha = as.Date(paste0(anios, "-11-11")), feriado = "Fundación de Riobamba (local)"),
  tibble(fecha = as.Date(paste0(anios, "-12-25")), feriado = "Navidad"),
  # Traslados / días adicionales conocidos (agregar los de otros años si se requiere)
  tibble(fecha = as.Date(c("2026-01-02", "2026-04-30", "2026-05-25")),
         feriado = c("Año Nuevo (descanso adicional)", "Día del Trabajo (descanso adicional)",
                     "Batalla de Pichincha (trasladado)"))
) %>% arrange(fecha)

# ---- Categorías de Seguridad Ciudadana ---------------------------------------
# (gana la primera regla que coincide)
# Corrección del 9-nov (día 14): "\\barma" evita que "Sonidos de alarma" caiga en
# delitos contra las personas; se agregan subtipos delictivos que antes quedaban
# en "otros" (delitos sexuales, estupro, sicariato, trata, receptación, etc.).
categorizar <- function(subtipo) {
  case_when(
    str_detect(subtipo, regex("sustancias sujetas|droga|microtr", TRUE)) ~ "Drogas",
    str_detect(subtipo, regex("robo|hurto|abigeato|asalto|estafa|abuso de confianza|daño a propiedad|fraude|falsificaci|receptaci|cachiner|usura|suplantaci|moneda falsa|tráfico de moneda|contrabando|sustracci|usurpaci|aprovechamiento il", TRUE)) ~ "Delitos contra la propiedad",
    str_detect(subtipo, regex("asesinato|homicidio|sicariato|\\barmas?\\b|armada|disparos|explosivos|agresi|violaci[oó]n|abuso sexual|delitos sexuales|estupro|acoso|secuestro|trata de personas|desaparici[oó]n forzada|extorsi|amenaza|intimidaci|abandono de niños|persona herida", TRUE)) ~ "Delitos contra las personas",
    str_detect(subtipo, regex("violencia", TRUE)) ~ "Violencia intrafamiliar / de género",
    str_detect(subtipo, regex("libadores|escándalo|fiestas|riña|ruido|inquilinato|actos inmorales|exhibicionista|bebidas alcohólicas|eventos clandestinos|eventos ilegales", TRUE)) ~ "Convivencia y orden público",
    str_detect(subtipo, regex("desaparec|desaparici[oó]n de persona|extraviado|suicidio|persona sin vida|constatar|muerte|abandono de (persona|adultos)", TRUE)) ~ "Personas desaparecidas / muertes",
    TRUE ~ "Servicio policial preventivo y otros"
  )
}

# ---- Tipo de registro (día 14 · definición del problema predictivo) ----------
# Seguridad Ciudadana mezcla hechos (delitos, convivencia) con pedidos de
# servicio (patrullaje) y trámites (fichas de datos, boletas, resguardo de
# valores). Solo los hechos son "patrones delictivos".
CAT_DELITO <- c("Delitos contra la propiedad", "Delitos contra las personas",
                "Violencia intrafamiliar / de género", "Drogas")
CAT_DELICTIVAS <- c(CAT_DELITO, "Convivencia y orden público")
tipo_registro <- function(categoria, subtipo) {
  case_when(
    is.na(categoria) ~ NA_character_,
    categoria %in% CAT_DELITO ~ "Delito",
    categoria == "Convivencia y orden público" ~ "Convivencia y orden público",
    categoria == "Personas desaparecidas / muertes" ~ "Personas desaparecidas / muertes",
    str_detect(subtipo, regex("patrullaje|sospechosa|alarma|botón|presencia policial|encargos domiciliarios|custodia policial en lugares", TRUE)) ~ "Servicio policial solicitado",
    TRUE ~ "Trámite u operativo"
  )
}

# ---- Funciones de apoyo ------------------------------------------------------
miles <- label_number(big.mark = ".", decimal.mark = ",")

tema_stanford <- theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"),
        panel.grid.minor = element_blank())

guardar_grafico <- function(g, nombre, ancho = 9, alto = 5.5) {
  ruta <- file.path(DIR_GRAFICOS, nombre)
  ggsave(ruta, g, width = ancho, height = alto, dpi = 150, bg = "white")
  message("  gráfico guardado: ", ruta)
  invisible(ruta)
}

guardar_tabla <- function(lista_tablas, nombre) {
  ruta <- file.path(DIR_TABLAS, nombre)
  write_xlsx(lapply(lista_tablas, as.data.frame), ruta)
  message("  tabla guardada: ", ruta)
  invisible(ruta)
}

# "RIOBAMBA, CABECERA CANTONAL ..." -> "RIOBAMBA"; "CACHA (CAB. EN ...)" -> "CACHA"
nombre_corto <- function(x) {
  x %>% str_remove(",.*$") %>% str_remove("\\(.*\\)") %>%
    stringi::stri_trans_general("Latin-ASCII") %>% str_to_upper() %>% str_squish()
}

titulo <- function(texto) {
  message("\n", strrep("=", 70), "\n", texto, "\n", strrep("=", 70))
}

# ---- Variables de calendario por semana (lunes a domingo) --------------------
agregar_calendario <- function(df) {
  fer <- FERIADOS %>% mutate(semana_inicio = floor_date(fecha, "week", week_start = 1)) %>%
    count(semana_inicio, name = "n_feriados")
  df %>%
    mutate(jueves = semana_inicio + 3,                 # el jueves define año/mes ISO
           anio = isoyear(jueves), semana_iso = isoweek(jueves),
           mes_num = month(jueves), trimestre = quarter(jueves),
           sin_semana = sin(2 * pi * semana_iso / 52.18),
           cos_semana = cos(2 * pi * semana_iso / 52.18),
           fin_de_mes = month(semana_inicio) != month(semana_inicio + 6),
           semana_pago = fin_de_mes | (day(semana_inicio) <= 15 & day(semana_inicio + 6) >= 15)) %>%
    select(-jueves) %>%
    left_join(fer, by = "semana_inicio") %>%
    mutate(n_feriados = replace_na(n_feriados, 0L), semana_feriado = n_feriados > 0)
}

# ---- Rezagos y promedios móviles por parroquia (solo usan el PASADO) ----------
agregar_rezagos <- function(df) {
  ma_previa <- function(x, k) dplyr::lag(as.numeric(stats::filter(x, rep(1 / k, k), sides = 1)))
  df %>% arrange(cod_parroquia, semana_inicio) %>% group_by(cod_parroquia) %>%
    mutate(lag1 = dplyr::lag(incidentes, 1), lag2 = dplyr::lag(incidentes, 2),
           lag3 = dplyr::lag(incidentes, 3), lag4 = dplyr::lag(incidentes, 4),
           lag52 = dplyr::lag(incidentes, 52),
           ma4 = ma_previa(incidentes, 4), ma8 = ma_previa(incidentes, 8),
           ma12 = ma_previa(incidentes, 12),
           robos_lag1 = dplyr::lag(robos, 1), violencia_lag1 = dplyr::lag(violencia, 1),
           tendencia = as.numeric(semana_inicio - min(semana_inicio)) / 7) %>%
    ungroup()
}
