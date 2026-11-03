# =============================================================================
# PROYECTO STANFORD · 05_eda_frecuencias.R
# DÍA 9 (Jue 29-oct) · Frecuencias por servicio y subtipo
#
#   [NELCY] Tablas de frecuencias por servicio y subtipo.
#   [SONIA] Gráficos de frecuencia con ggplot2.
#   (Gabriela, Walter y Emily usan estas tablas/gráficos para el informe y manual)
#
# Entrada: 02_datos_limpios/riobamba_depurada.rds
# Salida:  03_resultados/tablas/05_frecuencias.xlsx y gráficos 05_*.png
# =============================================================================
source("scripts/_comun.R")

rb <- readRDS(file.path(DIR_LIMPIOS, "riobamba_depurada.rds"))
sc <- rb %>% filter(servicio == SERVICIO_FOCO)
foco <- sc %>% filter(zona_foco)

# -----------------------------------------------------------------------------
# [NELCY] Tablas de frecuencias
# -----------------------------------------------------------------------------
titulo("[NELCY] Día 9 · Tablas de frecuencias")

f_servicio <- rb %>% count(servicio, name = "incidentes", sort = TRUE) %>%
  mutate(porcentaje = round(100 * incidentes / sum(incidentes), 2))
print(f_servicio)

f_subtipo_sc <- sc %>% count(subtipo, name = "incidentes", sort = TRUE) %>%
  mutate(porcentaje = round(100 * incidentes / sum(incidentes), 2),
         acumulado = cumsum(porcentaje))
print(head(f_subtipo_sc, 20))

f_parroquia_sc <- sc %>% count(cod_parroquia, parroquia_corta, name = "incidentes",
                               sort = TRUE) %>%
  mutate(porcentaje = round(100 * incidentes / sum(incidentes), 2))
print(f_parroquia_sc)

f_foco_servicio <- rb %>% filter(zona_foco) %>%
  count(parroquia_corta, servicio) %>%
  pivot_wider(names_from = parroquia_corta, values_from = n, values_fill = 0)
print(f_foco_servicio)

f_foco_subtipo <- foco %>% count(parroquia_corta, subtipo, name = "incidentes") %>%
  arrange(parroquia_corta, desc(incidentes))
print(f_foco_subtipo, n = 40)

guardar_tabla(list("Servicio Riobamba" = f_servicio,
                   "Subtipos Seg Ciudadana" = f_subtipo_sc,
                   "Parroquias Seg Ciudadana" = f_parroquia_sc,
                   "Flores-Cubijies servicio" = f_foco_servicio,
                   "Flores-Cubijies subtipo" = f_foco_subtipo),
              "05_frecuencias.xlsx")

# -----------------------------------------------------------------------------
# [SONIA] Gráficos de frecuencia
# -----------------------------------------------------------------------------
titulo("[SONIA] Día 9 · Gráficos de frecuencia")

g1 <- ggplot(f_servicio, aes(reorder(servicio, incidentes), incidentes)) +
  geom_col(fill = "#1f5f99") + coord_flip() +
  geom_text(aes(label = paste0(round(porcentaje, 1), " %")), hjust = -0.1, size = 3.5) +
  scale_y_continuous(labels = miles, expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Incidentes por servicio · Cantón Riobamba",
       subtitle = "Julio 2021 a septiembre 2026 · ECU 911", x = NULL, y = "Incidentes") +
  tema_stanford
guardar_grafico(g1, "05_1_servicios_riobamba.png")

g2 <- f_subtipo_sc %>% slice_head(n = 15) %>%
  mutate(subtipo = str_trunc(subtipo, 55)) %>%
  ggplot(aes(reorder(subtipo, incidentes), incidentes)) +
  geom_col(fill = "#1f5f99") + coord_flip() +
  scale_y_continuous(labels = miles) +
  labs(title = "15 subtipos más frecuentes de Seguridad Ciudadana",
       subtitle = "Cantón Riobamba, jul-2021 a sep-2026", x = NULL, y = "Incidentes") +
  tema_stanford
guardar_grafico(g2, "05_2_subtipos_seguridad.png", ancho = 10, alto = 6)

g3 <- f_parroquia_sc %>%
  mutate(foco = cod_parroquia %in% names(PARROQUIAS_FOCO)) %>%
  ggplot(aes(reorder(parroquia_corta, incidentes), incidentes, fill = foco)) +
  geom_col() + coord_flip() +
  scale_y_log10(labels = miles) +
  scale_fill_manual(values = c(`TRUE` = "#d4593a", `FALSE` = "#9db7d1"),
                    labels = c(`TRUE` = "Flores / Cubijíes", `FALSE` = "Otras parroquias")) +
  labs(title = "Seguridad Ciudadana por parroquia de Riobamba",
       subtitle = "Escala logarítmica: la cabecera cantonal concentra casi todo",
       x = NULL, y = "Incidentes (escala log)", fill = NULL) +
  tema_stanford
guardar_grafico(g3, "05_3_parroquias_seguridad.png")

g4 <- ggplot(f_foco_subtipo, aes(reorder(str_trunc(subtipo, 50), incidentes), incidentes)) +
  geom_col(fill = "#d4593a") + coord_flip() +
  facet_wrap(~parroquia_corta, scales = "free") +
  labs(title = "Seguridad Ciudadana en Flores y Cubijíes por subtipo",
       subtitle = "Julio 2021 a septiembre 2026", x = NULL, y = "Incidentes") +
  tema_stanford
guardar_grafico(g4, "05_4_flores_cubijies_subtipos.png", ancho = 12, alto = 6)

message("Listo -> ahora ejecuta scripts/06_eda_temporal.R")
