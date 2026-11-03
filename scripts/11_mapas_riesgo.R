# =============================================================================
# PROYECTO STANFORD · 11_mapas_riesgo.R
# EDGAR FABRICIO CHAMBA RODRÍGUEZ · Días 14 a 18 (9 al 13-nov)
#
# DÍA 14 Capa de parroquias lista para mostrar resultados del modelo.
# DÍA 15 Mapa preliminar del riesgo predicho por parroquia.
# DÍA 16 Comparación en mapas de las predicciones de distintos modelos.
# DÍA 17 Simbología y rangos de los mapas de riesgo (niveles de alerta).
# DÍA 18 Mapas para la presentación de avances.
#
# Requiere: 08_mapas.R (capa) y 10_modelos.R (predicciones)
# =============================================================================
source("scripts/_comun.R")
library(sf)

capa <- st_read(file.path(DIR_MAPAS, "parroquias_riobamba.gpkg"), quiet = TRUE)
pron <- readRDS(file.path(DIR_MODELOS, "pronosticos.rds"))
pred <- readRDS(file.path(DIR_MODELOS, "predicciones_prueba.rds"))
info <- readRDS(file.path(DIR_MODELOS, "info_modelo.rds"))

# DÍA 14 · capa con resultados
titulo("[EDGAR] Día 14 · Capa para resultados")
capa_res <- capa %>% left_join(pron %>% filter(horizonte == 1) %>%
                                 select(cod_parroquia, prediccion, rango_bajo, rango_alto,
                                        prob_al_menos_1, indice, alerta),
                               by = "cod_parroquia")
print(st_drop_geometry(capa_res))

# DÍA 15 y 17 · riesgo predicho con niveles de alerta
titulo("[EDGAR] Días 15 y 17 · Mapa de riesgo predicho")
semana_txt <- format(min(pron$semana_inicio), "%d/%m/%Y")
g1 <- ggplot(capa_res) +
  geom_sf(aes(fill = factor(alerta, levels = c("Normal", "Media", "Alta"))), colour = "white") +
  geom_sf_text(aes(label = paste0(parroquia_corta, "\n", prediccion, " (", rango_bajo, "-", rango_alto, ")")),
               size = 2.3) +
  scale_fill_manual(values = c(Normal = "#cfe3cf", Media = "#f2c46d", Alta = "#d4593a"),
                    drop = FALSE, name = "Alerta") +
  labs(title = paste("Pronóstico semana del", semana_txt),
       subtitle = paste0("Incidentes esperados (rango 80 %) · urbana: ", info$elegido_urbana,
                         " · rurales: ", info$elegido_rural,
                         "\nAlerta según índice vs. últimas 52 semanas: alta ≥ 125, media ≥ 110")) +
  theme_void()
guardar_grafico(g1, "11_1_mapa_riesgo_pronostico.png", ancho = 8, alto = 8)

# Índice: pronóstico / promedio de las últimas 52 semanas (100 = normal)
g2 <- ggplot(capa_res) +
  geom_sf(aes(fill = indice), colour = "white") +
  geom_sf_text(aes(label = indice), size = 2.6) +
  scale_fill_gradient2(low = "#2b7bba", mid = "white", high = "#d4593a", midpoint = 100,
                       name = "Índice\n(100 = normal)") +
  labs(title = "Índice de riesgo: pronóstico vs. promedio histórico",
       subtitle = paste("Semana del", semana_txt)) + theme_void()
guardar_grafico(g2, "11_2_indice_riesgo.png", ancho = 8, alto = 8)

# DÍA 16 · comparación de modelos (error por parroquia)
titulo("[EDGAR] Día 16 · Comparación de modelos en mapas")
modelos_cmp <- intersect(c("Base: promedio 4 semanas", "Regresión Poisson",
                           "Random forest", "XGBoost ajustado", info$elegido),
                         unique(pred$modelo))
error_parroquia <- pred %>% filter(modelo %in% modelos_cmp) %>%
  group_by(modelo, cod_parroquia) %>%
  summarise(MAE_relativo = mean(abs(real - prediccion)) / max(mean(real), 0.1), .groups = "drop")
g3 <- capa %>% inner_join(error_parroquia, by = "cod_parroquia") %>%
  ggplot() + geom_sf(aes(fill = MAE_relativo), colour = "white", linewidth = 0.2) +
  facet_wrap(~modelo) +
  scale_fill_gradient(low = "#e8f0f8", high = "#d4593a", labels = label_percent(),
                      name = "Error relativo\n(MAE / media)") +
  labs(title = "¿Dónde se equivoca más cada modelo? (año de prueba)") + theme_void()
guardar_grafico(g3, "11_3_error_modelos_mapa.png", ancho = 11, alto = 8)

# DÍA 18 · mapa interactivo para la presentación y el dashboard
titulo("[EDGAR] Día 18 · Mapa interactivo de riesgo")
if (requireNamespace("leaflet", quietly = TRUE)) {
  library(leaflet)
  pal <- colorFactor(c("#cfe3cf", "#f2c46d", "#d4593a"), levels = c("Normal", "Media", "Alta"))
  m <- leaflet(st_transform(capa_res, 4326)) %>% addProviderTiles("CartoDB.Positron") %>%
    addPolygons(fillColor = ~pal(alerta), fillOpacity = 0.8, color = "white", weight = 2,
                label = ~paste0(parroquia_corta, ": ", prediccion, " esperados (", rango_bajo, "-",
                                rango_alto, ") · alerta ", alerta)) %>%
    addLegend(pal = pal, values = ~alerta, title = paste("Alerta · semana", semana_txt))
  htmlwidgets::saveWidget(m, normalizePath(file.path(DIR_MAPAS, "mapa_riesgo.html"),
                                           mustWork = FALSE), selfcontained = TRUE)
}
st_write(capa_res, file.path(DIR_MAPAS, "riesgo_parroquias.gpkg"), delete_dsn = TRUE, quiet = TRUE)
message("Listo.")
