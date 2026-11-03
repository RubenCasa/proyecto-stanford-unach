# =============================================================================
# PROYECTO STANFORD · 03_filtro_geografico.R
# DÍA 7 (Mar 27-oct) · Filtrado de Chimborazo, Riobamba, Flores y Cubijíes
#
#   [NELCY]   Aplica el filtro por provincia, cantón y parroquia.
#   [MELANIE] Correspondencia Cod_Parroquia <-> Parroquia en Riobamba.
#   [SONIA]   Tablas de frecuencia: el filtro conserva Flores y Cubijíes.
#   [RUBÉN]   Tabla de conteos de incidentes por parroquia.
#   [GABRIELA] Registra en el tablero el criterio y el número de registros.
#   (La unión con los límites del INEC la hace EDGAR en 08_mapas.R)
#
# Entrada: 02_datos_limpios/01_base_limpia_chimborazo.rds
# Salida:  02_datos_limpios/02_base_riobamba.rds
# =============================================================================
source("scripts/_comun.R")

nacional <- readRDS(file.path(DIR_LIMPIOS, "01_base_limpia_chimborazo.rds"))   # provincia completa

# -----------------------------------------------------------------------------
# [NELCY] Filtro geográfico
# -----------------------------------------------------------------------------
titulo("[NELCY] Día 7 · Filtro Chimborazo > Riobamba")
# (la provincia de Chimborazo ya se separó al importar, por memoria)
# Criterio: provincia CHIMBORAZO y cantón RIOBAMBA (código de cantón 0601).
# Se trabaja con TODAS las parroquias de Riobamba (para entrenar los modelos)
# y se marcan Flores y Cubijíes (beneficiarias directas) para reportarlas aparte.
riobamba <- nacional %>%
  filter(provincia == PROVINCIA, canton == CANTON) %>%
  mutate(zona_foco = cod_parroquia %in% names(PARROQUIAS_FOCO))

conteo_filtro <- tibble(
  nivel = c("Nacional (sin limpiar, 63 archivos)", "Provincia Chimborazo (limpia)", "Cantón Riobamba",
            "Riobamba · Seguridad Ciudadana",
            "Flores + Cubijíes (todos los servicios)",
            "Flores + Cubijíes · Seguridad Ciudadana"),
  registros = c(sum(readRDS(file.path(DIR_LIMPIOS, "00_resumen_nacional.rds"))$registros),
                sum(nacional$provincia == PROVINCIA),
                nrow(riobamba),
                sum(riobamba$servicio == SERVICIO_FOCO),
                sum(riobamba$zona_foco),
                sum(riobamba$zona_foco & riobamba$servicio == SERVICIO_FOCO))
)
print(conteo_filtro)

# Revisión: registros con código 0601xx pero cantón escrito distinto
fuera <- nacional %>% filter(str_detect(cod_parroquia, "^0601"), canton != CANTON)
message("Registros con código de Riobamba pero otro cantón: ", nrow(fuera))

# -----------------------------------------------------------------------------
# [MELANIE] Correspondencia código - nombre de parroquia
# -----------------------------------------------------------------------------
titulo("[MELANIE] Día 7 · Código vs nombre de parroquia (Riobamba)")
correspondencia <- riobamba %>%
  count(cod_parroquia, parroquia, name = "registros") %>%
  mutate(foco = cod_parroquia %in% names(PARROQUIAS_FOCO),
         nombre_corto = nombre_corto(parroquia))
print(correspondencia, n = Inf)
stopifnot("Flores no aparece"   = "060154" %in% correspondencia$cod_parroquia,
          "Cubijíes no aparece" = "060153" %in% correspondencia$cod_parroquia)

# -----------------------------------------------------------------------------
# [SONIA] Frecuencias: el filtro conserva Flores y Cubijíes
# -----------------------------------------------------------------------------
titulo("[SONIA] Día 7 · Comparación de conteos antes y después del filtro")
comparacion_foco <- nacional %>%
  filter(cod_parroquia %in% names(PARROQUIAS_FOCO)) %>%
  count(parroquia, name = "en_base_provincial") %>%
  left_join(riobamba %>% filter(zona_foco) %>%
              count(parroquia, name = "en_base_riobamba"), by = "parroquia") %>%
  mutate(se_conservan = en_base_provincial == en_base_riobamba)
print(comparacion_foco)

# -----------------------------------------------------------------------------
# [RUBÉN] Conteo de incidentes por parroquia
# -----------------------------------------------------------------------------
titulo("[RUBÉN] Día 7 · Conteo por parroquia")
conteo_parroquia <- riobamba %>%
  group_by(cod_parroquia, parroquia = nombre_corto(parroquia)) %>%
  summarise(total_incidentes = n(),
            seguridad_ciudadana = sum(servicio == SERVICIO_FOCO),
            .groups = "drop") %>%
  mutate(pct_seguridad = round(100 * seguridad_ciudadana / total_incidentes, 1)) %>%
  arrange(desc(total_incidentes))
print(conteo_parroquia, n = Inf)

# ---- Guardar -----------------------------------------------------------------
saveRDS(riobamba, file.path(DIR_LIMPIOS, "02_base_riobamba.rds"))
guardar_tabla(list("Conteo por nivel" = conteo_filtro,
                   "Codigo vs nombre" = correspondencia,
                   "Flores y Cubijies" = comparacion_foco,
                   "Conteo por parroquia" = conteo_parroquia),
              "03_filtro_geografico.xlsx")
message("\n>> Para el tablero (Gabriela): base de Riobamba = ", miles(nrow(riobamba)),
        " registros; Flores + Cubijíes = ", sum(riobamba$zona_foco))
message("Listo -> ahora ejecuta scripts/04_fechas_diccionario.R")
