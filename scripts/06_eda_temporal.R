# =============================================================================
# PROYECTO STANFORD · 06_eda_temporal.R
# DÍA 10 (Vie 30-oct) · Tendencias y estacionalidad (año, mes, día de semana)
#
#   [NELCY] Tablas de conteo por año, mes y día de la semana.
#   [SONIA] Gráficos de tendencia y estacionalidad.
#
# Entrada: 02_datos_limpios/riobamba_depurada.rds
# Salida:  03_resultados/tablas/06_temporal.xlsx y gráficos 06_*.png
# =============================================================================
source("scripts/_comun.R")

rb <- readRDS(file.path(DIR_LIMPIOS, "riobamba_depurada.rds"))
sc <- rb %>% filter(servicio == SERVICIO_FOCO)

# Serie diaria completa (los días sin incidentes cuentan como 0)
todos_dias <- tibble(fecha = seq(min(rb$fecha), max(rb$fecha), by = "day"))
diario <- todos_dias %>%
  left_join(sc %>% count(fecha, name = "incidentes"), by = "fecha") %>%
  mutate(incidentes = replace_na(incidentes, 0L),
         dia_semana = factor(DIAS[wday(fecha, week_start = 1)], levels = DIAS),
         mes = factor(MESES[month(fecha)], levels = MESES),
         anio = year(fecha),
         feriado = fecha %in% FERIADOS$fecha)

# -----------------------------------------------------------------------------
# [NELCY] Tablas de conteo
# -----------------------------------------------------------------------------
titulo("[NELCY] Día 10 · Conteos por año, mes y día de la semana")

t_anio <- diario %>% group_by(anio) %>%
  summarise(promedio_diario = round(mean(incidentes), 1),
            incidentes = sum(incidentes), dias = n(), .groups = "drop")
print(t_anio)

t_mes <- diario %>% group_by(anio, mes) %>%
  summarise(incidentes = sum(incidentes), dias = n(),
            promedio_diario = round(incidentes / dias, 1), .groups = "drop") %>%
  mutate(variacion_pct = round(100 * (incidentes / lag(incidentes) - 1), 1))
print(t_mes)

t_dia <- diario %>% group_by(dia_semana) %>%
  summarise(promedio_por_dia = round(mean(incidentes), 1),
            incidentes = sum(incidentes), n_dias = n(), .groups = "drop") %>%
  mutate(indice = round(100 * promedio_por_dia / mean(diario$incidentes)))  # 100 = promedio
print(t_dia)

t_feriado <- diario %>% group_by(feriado) %>%
  summarise(dias = n(), promedio_por_dia = round(mean(incidentes), 1), .groups = "drop")
print(t_feriado)

# Flores y Cubijíes por año
t_foco_mes <- sc %>% filter(zona_foco) %>%
  count(parroquia_corta, anio) %>%
  pivot_wider(names_from = anio, values_from = n, values_fill = 0)
print(t_foco_mes)

guardar_tabla(list("Por anio" = t_anio, "Por mes" = t_mes,
                   "Por dia de semana" = t_dia, "Feriados" = t_feriado,
                   "Flores-Cubijies por anio" = t_foco_mes,
                   "Serie diaria" = diario),
              "06_temporal.xlsx")

# -----------------------------------------------------------------------------
# [SONIA] Gráficos de tendencia y estacionalidad
# -----------------------------------------------------------------------------
titulo("[SONIA] Día 10 · Gráficos de tendencia")

diario <- diario %>%
  mutate(media_7d = as.numeric(stats::filter(incidentes, rep(1 / 7, 7), sides = 2)))

g1 <- ggplot(diario, aes(fecha)) +
  geom_line(aes(y = incidentes), colour = "grey70", linewidth = 0.4) +
  geom_line(aes(y = media_7d), colour = "#1f5f99", linewidth = 1) +
  geom_point(data = filter(diario, feriado), aes(y = incidentes),
             colour = "#d4593a", size = 2) +
  scale_x_date(date_breaks = "6 months", date_labels = "%m/%Y") +
  labs(title = "Seguridad Ciudadana diaria · Cantón Riobamba",
       subtitle = "Gris: diario · Azul: media móvil 7 días · Rojo: feriados",
       x = NULL, y = "Incidentes por día") + tema_stanford
guardar_grafico(g1, "06_1_tendencia_diaria.png")

g0 <- ggplot(t_anio, aes(factor(anio), promedio_diario)) +
  geom_col(fill = "#1f5f99") +
  geom_text(aes(label = promedio_diario), vjust = -0.4, size = 3.5) +
  labs(title = "Promedio diario por año · Seguridad Ciudadana, Riobamba",
       subtitle = "2021: solo jul-dic · 2026: solo ene-sep", x = NULL, y = "Incidentes por día") +
  tema_stanford
guardar_grafico(g0, "06_0_por_anio.png")

g2 <- ggplot(t_mes, aes(mes, promedio_diario, group = anio, colour = factor(anio))) +
  geom_line(linewidth = 1) + geom_point(size = 2) +
  labs(title = "Promedio diario por mes · Seguridad Ciudadana, Riobamba",
       x = NULL, y = "Incidentes por día", colour = "Año") + tema_stanford
guardar_grafico(g2, "06_2_mensual.png")

g3 <- ggplot(t_dia, aes(dia_semana, promedio_por_dia)) +
  geom_col(fill = "#1f5f99") +
  geom_text(aes(label = promedio_por_dia), vjust = -0.4, size = 3.5) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.08))) +
  labs(title = "Promedio por día de la semana · Seguridad Ciudadana, Riobamba",
       x = NULL, y = "Incidentes por día") + tema_stanford
guardar_grafico(g3, "06_3_dia_semana.png")

g4 <- diario %>%
  ggplot(aes(dia_semana, incidentes)) +
  geom_boxplot(fill = "#cfdeec", outlier.colour = "#d4593a") +
  labs(title = "Distribución diaria por día de la semana",
       x = NULL, y = "Incidentes por día") + tema_stanford
guardar_grafico(g4, "06_4_boxplot_dia_semana.png")

g5 <- sc %>% filter(zona_foco) %>% count(parroquia_corta, anio) %>%
  ggplot(aes(factor(anio), n, fill = parroquia_corta)) +
  geom_col(position = "dodge") +
  scale_fill_manual(values = c("#d4593a", "#1f5f99")) +
  labs(title = "Seguridad Ciudadana por año en Flores y Cubijíes",
       x = NULL, y = "Incidentes", fill = NULL) + tema_stanford
guardar_grafico(g5, "06_5_flores_cubijies_anio.png")

message("Listo -> Rubén: scripts/07_conteos_variables.R · Edgar: scripts/08_mapas.R")
