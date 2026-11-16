# =============================================================================
# PROYECTO STANFORD · 13_abigeato.R
# 16-nov · Análisis descriptivo del abigeato (robo de ganado) en Riobamba
#
# Pedido de SONIA: ¿en qué meses y en qué parroquias hay más abigeato?
# Es un delito explícito del COIP (código 1) y sobre todo rural.
# OJO: son pocos casos (unos 3 por mes): sirve para describir, no para un
# modelo predictivo propio. Febrero de 2023 no tiene subtipo en la fuente.
#
# Entrada: 02_datos_limpios/riobamba_depurada.rds
# Salida:  03_resultados/tablas/13_abigeato.xlsx y gráficos 13_*.png
# =============================================================================
source("scripts/_comun.R")

rb <- readRDS(file.path(DIR_LIMPIOS, "riobamba_depurada.rds"))
ab <- rb %>% filter(str_detect(subtipo, regex("abigeato", TRUE)))

titulo("[SONIA] 16-nov · Abigeato por año")
por_anio <- ab %>% count(anio, name = "casos")
print(por_anio)

titulo("[SONIA] 16-nov · Abigeato por mes del año (promedio)")
# promedio por mes = casos / número de años en que ese mes tiene datos con subtipo
meses_con_dato <- rb %>% filter(servicio == SERVICIO_FOCO) %>%
  group_by(anio, mes_num) %>%
  summarise(con_subtipo = n_distinct(subtipo) > 1, .groups = "drop") %>%
  filter(con_subtipo) %>% count(mes_num, name = "anios_con_dato")
por_mes <- ab %>% count(mes_num, name = "casos") %>%
  right_join(meses_con_dato, by = "mes_num") %>%
  mutate(casos = coalesce(casos, 0L),
         promedio = round(casos / anios_con_dato, 1),
         mes = factor(MESES[mes_num], levels = MESES)) %>%
  arrange(mes_num)
print(por_mes)

titulo("[SONIA] 16-nov · Abigeato por parroquia")
por_parroquia <- ab %>% count(parroquia_corta, name = "casos", sort = TRUE) %>%
  mutate(pct = round(100 * casos / sum(casos), 1))
print(por_parroquia)
cat("Casos en parroquias rurales:",
    round(100 * mean(ab$parroquia_corta != "RIOBAMBA"), 1), "%\n")

por_dia <- ab %>% count(dia_semana, name = "casos")
anio_parroquia <- ab %>% count(parroquia_corta, anio) %>%
  pivot_wider(names_from = anio, values_from = n, values_fill = 0)

g1 <- ggplot(por_mes, aes(mes, promedio)) +
  geom_col(fill = "#1f5f99") +
  geom_text(aes(label = format(promedio, decimal.mark = ",")), vjust = -0.4, size = 3.5) +
  labs(title = "Abigeato en el cantón Riobamba: promedio de casos por mes del año",
       subtitle = paste0("ECU 911, jul-2021 a sep-2026 · ", nrow(ab),
                         " casos en total (pocos casos: es una señal, no una prueba)"),
       x = NULL, y = "Casos por mes (promedio)") +
  tema_stanford + theme(axis.text.x = element_text(angle = 45, hjust = 1))
guardar_grafico(g1, "13_1_abigeato_por_mes.png")

g2 <- ggplot(por_parroquia, aes(reorder(parroquia_corta, casos), casos,
                                fill = parroquia_corta %in% c("FLORES", "CUBIJIES"))) +
  geom_col(show.legend = FALSE) + coord_flip() +
  geom_text(aes(label = casos), hjust = -0.2, size = 3.5) +
  scale_fill_manual(values = c(`FALSE` = "#5c6b7a", `TRUE` = "#d4593a")) +
  labs(title = "Abigeato por parroquia (en rojo: Flores y Cubijíes)",
       subtitle = "ECU 911, jul-2021 a sep-2026", x = NULL, y = "Casos") +
  tema_stanford
guardar_grafico(g2, "13_2_abigeato_por_parroquia.png")

g3 <- ggplot(por_anio, aes(factor(anio), casos)) +
  geom_col(fill = "#e8a33d") + geom_text(aes(label = casos), vjust = -0.4) +
  labs(title = "Abigeato por año en el cantón Riobamba",
       subtitle = "2021 desde julio y 2026 hasta septiembre (años incompletos)",
       x = NULL, y = "Casos") + tema_stanford
guardar_grafico(g3, "13_3_abigeato_por_anio.png")

guardar_tabla(list("Por anio" = por_anio, "Por mes" = por_mes %>% select(-mes_num),
                   "Por parroquia" = por_parroquia, "Por dia" = por_dia,
                   "Parroquia x anio" = anio_parroquia), "13_abigeato.xlsx")
message("Listo -> análisis descriptivo del abigeato (pedido de Sonia).")
