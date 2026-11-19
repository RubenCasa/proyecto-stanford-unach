# =============================================================================
# PROYECTO STANFORD · 08_mapas.R
# EDGAR FABRICIO CHAMBA RODRÍGUEZ · Equipo 2 · Mapas
#
# DÍAS 1-3: fuentes cartográficas (límites parroquiales INEC/CONALI o GADM)
#           y nivel geográfico de la base (parroquia; no hay coordenadas).
# DÍA 4  Cargar límites en R con sf y revisar códigos de Riobamba.
# DÍA 5  ¿Coinciden los códigos de la base con los del mapa?
# DÍA 6  Registros con código o nombre inconsistente.
# DÍA 7  Unir datos + límites; comprobar Flores y Cubijíes.
# DÍA 8  Capa base de parroquias de Riobamba.
# DÍA 9  Tabla de incidentes por parroquia para el primer mapa.
# DÍA 10 Mapas por parroquia y por año (y por mes).
#
# FUENTE DEL MAPA (en este orden):
#  1) Si guardas el shapefile/gpkg de límites parroquiales del INEC/CONALI en
#     la carpeta 04_mapas/, se usa ese y se une por código (DPA).
#  2) Si no hay archivo, se descarga GADM nivel 3 (parroquias) con geodata
#     (necesita internet) y se une por nombre normalizado.
#
# Entrada: 02_datos_limpios/riobamba_depurada.rds
# Salida:  04_mapas/parroquias_riobamba.gpkg, mapas PNG y mapa HTML
# =============================================================================
source("scripts/_comun.R")
library(sf)

rb <- readRDS(file.path(DIR_LIMPIOS, "riobamba_depurada.rds"))
sc <- rb %>% filter(servicio == SERVICIO_FOCO)

# -----------------------------------------------------------------------------
# [EDGAR] DÍA 4 · Cargar límites parroquiales
# -----------------------------------------------------------------------------
titulo("[EDGAR] Día 4 · Límites parroquiales")
archivo_inec <- list.files(DIR_MAPAS, pattern = "\\.(shp|gpkg)$", full.names = TRUE,
                           recursive = TRUE)
archivo_inec <- archivo_inec[!str_detect(basename(archivo_inec), "^parroquias_riobamba")]

if (length(archivo_inec) > 0) {
  message("Usando límites del INEC/CONALI: ", archivo_inec[1])
  limites <- st_read(archivo_inec[1], quiet = TRUE)
  # Buscar la columna que contiene códigos DPA de parroquia (ej. 060154)
  col_cod <- names(limites)[sapply(names(limites), function(cn) {
    v <- as.character(limites[[cn]])
    any(str_detect(str_pad(v, 6, "left", "0"), "^0601\\d{2}$"), na.rm = TRUE)
  })][1]
  if (is.na(col_cod)) stop("No encuentro la columna de código de parroquia en el shapefile")
  message("Columna de código: ", col_cod)
  limites <- limites %>%
    mutate(cod_parroquia = str_pad(as.character(.data[[col_cod]]), 6, "left", "0")) %>%
    filter(str_detect(cod_parroquia, "^0601")) %>%
    st_make_valid()
  fuente_mapa <- "INEC/CONALI"
} else {
  message("No hay shapefile del INEC en 04_mapas/. Descargando GADM (nivel parroquia)...")
  gadm <- geodata::gadm(country = "ECU", level = 3, path = DIR_MAPAS)
  limites <- st_as_sf(gadm) %>%
    filter(nombre_corto(NAME_1) == PROVINCIA, nombre_corto(NAME_2) == CANTON) %>%
    mutate(parroquia_corta = nombre_corto(NAME_3)) %>%
    st_make_valid()
  fuente_mapa <- "GADM 4.1"
}
limites <- st_transform(limites, 4326)
message("Polígonos de Riobamba cargados: ", nrow(limites), " (fuente: ", fuente_mapa, ")")

# -----------------------------------------------------------------------------
# [EDGAR] DÍA 5 y 6 · Coincidencia de códigos / nombres e inconsistencias
# -----------------------------------------------------------------------------
titulo("[EDGAR] Días 5-6 · Coincidencia base vs mapa")
catalogo_base <- rb %>% count(cod_parroquia, parroquia, parroquia_corta, name = "registros")

if (fuente_mapa == "INEC/CONALI") {
  catalogo_base$en_mapa <- catalogo_base$cod_parroquia %in% limites$cod_parroquia
  llave <- "cod_parroquia"
} else {
  # GADM no tiene códigos INEC: se une por nombre normalizado
  limites <- limites %>%
    left_join(catalogo_base %>% distinct(cod_parroquia, parroquia_corta),
              by = "parroquia_corta")
  catalogo_base$en_mapa <- catalogo_base$parroquia_corta %in% limites$parroquia_corta
  llave <- "cod_parroquia"
}
print(catalogo_base, n = Inf)
inconsistentes <- catalogo_base %>% filter(!en_mapa)
message("Parroquias de la base que NO están en el mapa: ", nrow(inconsistentes))
if (nrow(inconsistentes) > 0) print(inconsistentes)
sin_datos <- limites %>% st_drop_geometry() %>%
  filter(is.na(cod_parroquia) | !cod_parroquia %in% catalogo_base$cod_parroquia)
message("Polígonos del mapa sin datos en la base: ", nrow(sin_datos))

# -----------------------------------------------------------------------------
# [EDGAR] DÍA 7 · Unir datos con límites; comprobar Flores y Cubijíes
# -----------------------------------------------------------------------------
titulo("[EDGAR] Día 7 · Unión datos + límites")
foco_en_mapa <- names(PARROQUIAS_FOCO) %in% limites$cod_parroquia
print(tibble(parroquia = PARROQUIAS_FOCO, codigo = names(PARROQUIAS_FOCO),
             aparece_en_mapa = foco_en_mapa))
if (!all(foco_en_mapa)) warning("Flores o Cubijíes no se unieron: revisar nombres/códigos")

# -----------------------------------------------------------------------------
# [EDGAR] DÍA 8 · Capa base de parroquias de Riobamba
# -----------------------------------------------------------------------------
titulo("[EDGAR] Día 8 · Capa base")
capa <- limites %>%
  filter(!is.na(cod_parroquia)) %>%
  group_by(cod_parroquia) %>% summarise(.groups = "drop") %>%   # 1 polígono por parroquia
  left_join(catalogo_base %>% distinct(cod_parroquia, parroquia_corta), by = "cod_parroquia") %>%
  mutate(zona_foco = cod_parroquia %in% names(PARROQUIAS_FOCO))
capa$area_km2 <- round(as.numeric(st_area(capa)) / 1e6, 2)
st_write(capa, file.path(DIR_MAPAS, "parroquias_riobamba.gpkg"), delete_dsn = TRUE, quiet = TRUE)

g_base <- ggplot(capa) +
  geom_sf(aes(fill = zona_foco), colour = "white") +
  geom_sf_text(aes(label = parroquia_corta), size = 2.6) +
  scale_fill_manual(values = c(`TRUE` = "#d4593a", `FALSE` = "#cfdeec"),
                    labels = c(`TRUE` = "Flores / Cubijíes", `FALSE` = "Otras")) +
  labs(title = "Parroquias del cantón Riobamba", fill = NULL,
       caption = paste("Fuente de límites:", fuente_mapa)) +
  theme_void()
guardar_grafico(g_base, "08_1_capa_base_parroquias.png", ancho = 8, alto = 8)

# -----------------------------------------------------------------------------
# [EDGAR] DÍA 9 · Tabla de incidentes por parroquia (primer mapa)
# -----------------------------------------------------------------------------
titulo("[EDGAR] Día 9 · Incidentes por parroquia")
tabla_mapa <- sc %>% count(cod_parroquia, name = "seguridad_ciudadana") %>%
  right_join(capa %>% st_drop_geometry(), by = "cod_parroquia") %>%
  mutate(seguridad_ciudadana = replace_na(seguridad_ciudadana, 0L),
         por_km2 = round(seguridad_ciudadana / area_km2, 2)) %>%
  arrange(desc(seguridad_ciudadana))
print(tabla_mapa)
guardar_tabla(list("Incidentes por parroquia" = tabla_mapa), "08_tabla_mapa.xlsx")

mapa1 <- capa %>% left_join(tabla_mapa %>% select(cod_parroquia, seguridad_ciudadana),
                            by = "cod_parroquia")
g1 <- ggplot(mapa1) +
  geom_sf(aes(fill = seguridad_ciudadana), colour = "white") +
  geom_sf(data = filter(mapa1, zona_foco), fill = NA, colour = "#d4593a", linewidth = 1) +
  geom_sf_text(aes(label = parroquia_corta), size = 2.6) +
  scale_fill_gradient(low = "#e8f0f8", high = "#1f5f99", trans = "log10",
                      labels = miles, name = "Incidentes\n(escala log)") +
  labs(title = "Seguridad Ciudadana por parroquia · Riobamba",
       subtitle = "Jul-2021 a sep-2026 · Borde rojo: Flores y Cubijíes") +
  theme_void()
guardar_grafico(g1, "08_2_mapa_incidentes_parroquia.png", ancho = 8, alto = 8)

# -----------------------------------------------------------------------------
# [EDGAR] DÍA 10 · Mapas por año y por mes
# -----------------------------------------------------------------------------
titulo("[EDGAR] Día 10 · Mapas por año y por mes")
por_periodo <- function(var) {
  sc %>% count(cod_parroquia, periodo = .data[[var]], name = "incidentes") %>%
    tidyr::complete(cod_parroquia = capa$cod_parroquia, periodo,
                    fill = list(incidentes = 0L)) %>%
    left_join(capa, by = "cod_parroquia") %>% st_as_sf()
}
g2 <- ggplot(por_periodo("anio")) +
  geom_sf(aes(fill = incidentes + 1), colour = "white") +
  facet_wrap(~periodo) +
  scale_fill_gradient(low = "#e8f0f8", high = "#1f5f99", trans = "log10",
                      labels = function(x) miles(x - 1), name = "Incidentes") +
  labs(title = "Seguridad Ciudadana por parroquia y año") + theme_void()
guardar_grafico(g2, "08_3_mapa_por_anio.png", ancho = 9, alto = 7)

g3 <- ggplot(por_periodo("mes") %>% filter(periodo %in% unique(sc$mes))) +
  geom_sf(aes(fill = incidentes + 1), colour = "white", linewidth = 0.2) +
  facet_wrap(~periodo, ncol = 4) +
  scale_fill_gradient(low = "#e8f0f8", high = "#1f5f99", trans = "log10",
                      labels = function(x) miles(x - 1), name = "Incidentes") +
  labs(title = "Seguridad Ciudadana por parroquia y mes (todos los años)") + theme_void()
guardar_grafico(g3, "08_4_mapa_por_mes.png", ancho = 12, alto = 7)

# Mapa interactivo (vista previa para el dashboard)
if (requireNamespace("leaflet", quietly = TRUE)) {
  library(leaflet)
  pal <- colorNumeric("Blues", log10(mapa1$seguridad_ciudadana + 1))
  m <- leaflet(mapa1) %>% addProviderTiles("CartoDB.Positron") %>%
    addPolygons(fillColor = ~pal(log10(seguridad_ciudadana + 1)), fillOpacity = 0.8,
                color = ~ifelse(zona_foco, "#d4593a", "white"), weight = 2,
                label = ~paste0(parroquia_corta, ": ", seguridad_ciudadana, " incidentes"))
  htmlwidgets::saveWidget(m, normalizePath(file.path(DIR_MAPAS, "mapa_interactivo.html"),
                                           mustWork = FALSE), selfcontained = TRUE)
  message("Mapa interactivo: 04_mapas/mapa_interactivo.html")
}
message("Listo.")
