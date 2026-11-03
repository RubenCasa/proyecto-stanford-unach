# =============================================================================
# PROYECTO STANFORD · 02_limpieza.R
# DÍA 6 (Lun 26-oct) · Valores perdidos, duplicados y estandarización
#
#   [NELCY]   Limpieza de valores perdidos y duplicados con naniar y janitor
#             (conteo antes y después).
#   [MELANIE] Valores no válidos en Cod_Parroquia y Parroquia.
#   [SONIA]   Compara conteos antes/después: no se pierden registros válidos.
#   [RUBÉN]   Verifica que la limpieza conserve los campos para las variables.
#
# Entrada: 02_datos_limpios/00_base_unificada_chimborazo.rds
# Salida:  02_datos_limpios/01_base_limpia_chimborazo.rds
# =============================================================================
source("scripts/_comun.R")
library(janitor); library(naniar)

base <- readRDS(file.path(DIR_LIMPIOS, "00_base_unificada_chimborazo.rds"))
resumen_nacional <- readRDS(file.path(DIR_LIMPIOS, "00_resumen_nacional.rds"))
n_inicial <- nrow(base)
message("A nivel nacional: ", miles(sum(resumen_nacional$sin_servicio)), " registros sin servicio y ",
        miles(sum(resumen_nacional$sin_provincia)), " sin provincia (de ",
        miles(sum(resumen_nacional$registros)), ").")

# -----------------------------------------------------------------------------
# [NELCY] Nombres de columnas estandarizados y valores perdidos
# -----------------------------------------------------------------------------
titulo("[NELCY] Día 6 · Valores perdidos")
base <- base %>% clean_names()     # fecha, provincia, canton, cod_parroquia, ...
print(names(base))

perdidos_antes <- miss_var_summary(base)
print(perdidos_antes)

# Regla acordada:
#  - Sin servicio o sin subtipo -> se elimina (no se puede clasificar).
#  - Sin cantón/parroquia -> se elimina (no se puede ubicar).
sin_servicio  <- sum(is.na(base$servicio) | is.na(base$subtipo))
sin_ubicacion <- sum(is.na(base$provincia) | is.na(base$canton) | is.na(base$cod_parroquia))
base <- base %>%
  filter(!is.na(servicio), !is.na(subtipo),
         !is.na(provincia), !is.na(canton), !is.na(cod_parroquia))

# -----------------------------------------------------------------------------
# [NELCY] Duplicados
# -----------------------------------------------------------------------------
titulo("[NELCY] Día 6 · Duplicados")
# La base NO trae identificador ni hora. Dos filas iguales (misma fecha,
# parroquia y subtipo) suelen ser dos incidentes distintos del mismo día.
# Decisión: se CUENTAN pero NO se eliminan. Solo se eliminan filas idénticas
# también en el archivo de origen si un mismo archivo se cargó dos veces.
filas_repetidas <- base %>%
  select(-archivo_origen) %>% duplicated() %>% sum()
message("Filas con contenido repetido: ", miles(filas_repetidas),
        " (se conservan: no hay ID para saber si son el mismo incidente)")
ejemplo_dupes <- base %>% filter(canton == CANTON) %>%
  get_dupes(fecha, cod_parroquia, servicio, subtipo) %>% head(10)
print(ejemplo_dupes)

# -----------------------------------------------------------------------------
# Estandarización de texto en Servicio y Subtipo
# -----------------------------------------------------------------------------
titulo("[NELCY] Día 6 · Estandarización de Servicio y Subtipo")
base <- base %>%
  mutate(across(c(provincia, canton, parroquia, servicio, subtipo), str_squish),
         provincia = str_to_upper(provincia),
         canton    = str_to_upper(canton))

# Subtipos que solo se diferencian por mayúsculas/espacios
variantes <- base %>% distinct(subtipo) %>%
  mutate(clave = str_to_lower(str_remove_all(subtipo, "\\s"))) %>%
  group_by(clave) %>% filter(n() > 1) %>% arrange(clave)
message("Subtipos con variantes de escritura: ", nrow(variantes))
if (nrow(variantes) > 0) print(variantes)
# Inconsistencia de la fuente: en 2023 hay registros cuyo subtipo es el mismo
# nombre del servicio (ej. subtipo "Seguridad Ciudadana"). Se conservan y se marcan.
subtipo_generico <- base %>% filter(subtipo == servicio) %>%
  count(anio = str_extract(fecha, "\\d{4}$"), servicio, name = "registros")
message("Registros con subtipo genérico (= nombre del servicio):"); print(subtipo_generico)
message("Servicios distintos: ", n_distinct(base$servicio),
        " · Subtipos distintos: ", n_distinct(base$subtipo))

# -----------------------------------------------------------------------------
# [MELANIE] Valores no válidos en Cod_Parroquia y Parroquia
# -----------------------------------------------------------------------------
titulo("[MELANIE] Día 6 · Códigos y nombres de parroquia")
base <- base %>%
  mutate(cod_parroquia = str_pad(str_trim(cod_parroquia), 6, "left", "0"))

cod_invalidos <- base %>%
  filter(!str_detect(cod_parroquia, "^\\d{6}$")) %>% count(cod_parroquia, parroquia)
message("Códigos que no tienen 6 dígitos: ", nrow(cod_invalidos))

# Un código debería tener un solo nombre de parroquia
codigo_con_varios_nombres <- base %>% distinct(cod_parroquia, parroquia) %>%
  group_by(cod_parroquia) %>% filter(n() > 1) %>% arrange(cod_parroquia)
message("Códigos con más de un nombre: ", n_distinct(codigo_con_varios_nombres$cod_parroquia))
print(head(codigo_con_varios_nombres, 20))

# Código de provincia (2 primeros dígitos) coherente con la provincia
prov_inconsistente <- base %>% mutate(cod_prov = substr(cod_parroquia, 1, 2)) %>%
  distinct(provincia, cod_prov) %>% group_by(provincia) %>% filter(n() > 1)
message("Provincias con más de un código provincial: ", n_distinct(prov_inconsistente$provincia))

# -----------------------------------------------------------------------------
# [SONIA] Conteo antes y después
# -----------------------------------------------------------------------------
titulo("[SONIA] Día 6 · Antes vs después de la limpieza")
antes_despues <- tibble(
  paso = c("Registros iniciales (Chimborazo)", "Sin servicio o subtipo (eliminados)",
           "Sin ubicación (eliminados)", "Registros finales"),
  registros = c(n_inicial, sin_servicio, sin_ubicacion, nrow(base))
)
print(antes_despues)
message("Se conserva el ", round(100 * nrow(base) / n_inicial, 3), " % de los registros.")
por_archivo <- base %>% count(archivo_origen, name = "despues")
print(por_archivo)

# -----------------------------------------------------------------------------
# [RUBÉN] ¿Se conservan los campos para generar variables?
# -----------------------------------------------------------------------------
titulo("[RUBÉN] Día 6 · Campos conservados")
print(sapply(base[c("fecha", "cod_parroquia", "servicio", "subtipo")],
             function(v) sum(is.na(v))))

# ---- Guardar -----------------------------------------------------------------
saveRDS(base, file.path(DIR_LIMPIOS, "01_base_limpia_chimborazo.rds"))
guardar_tabla(list("Perdidos antes" = perdidos_antes,
                   "Antes vs despues" = antes_despues,
                   "Codigos varios nombres" = codigo_con_varios_nombres,
                   "Variantes subtipo" = variantes,
                   "Subtipo generico" = subtipo_generico),
              "02_control_limpieza.xlsx")
message("\nListo -> ahora ejecuta scripts/03_filtro_geografico.R")
