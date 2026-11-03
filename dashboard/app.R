# =============================================================================
# PROYECTO STANFORD · dashboard/app.R  (versión 2)
# Dashboard predictivo de Seguridad Ciudadana · Riobamba (Flores y Cubijíes)
# Responsable: ANTHONY JOEL CATAGUA CHULCA (Equipo 2) · mapas: EDGAR CHAMBA
#
# Pestañas:
#   Resumen ............ tendencia semanal, categorías, patrón día × mes, subtipos
#   Pronóstico y alertas próximas 4 semanas, rango probable, índice y alerta
#   Tendencia 2029 ..... tendencia mensual hasta dic-2029 con bandas 80/95 %
#   Mapa ............... alerta, incidentes del periodo o cambio 2025-2029
#   Perfil de parroquia  ficha de una parroquia (años, categorías, subtipos)
#   Modelos ............ desempeño de los modelos y predicción vs real
#   Datos .............. tabla con buscador y descarga CSV
#
# Abrir (con el proyecto abierto):  shiny::runApp("dashboard")
# Requiere los resultados de scripts/04, 08, 10 y 12.
# =============================================================================
suppressPackageStartupMessages({
  library(shiny); library(bslib); library(dplyr); library(tidyr); library(ggplot2)
  library(lubridate); library(DT); library(plotly)
})

buscar <- function(ruta) {          # funciona desde el proyecto o desde dashboard/
  r <- c(file.path("..", ruta), ruta); r <- r[file.exists(r)]; if (length(r)) r[1] else NA
}
ico <- function(n) if (requireNamespace("bsicons", quietly = TRUE)) bsicons::bs_icon(n) else NULL
fmt <- function(x, d = 0) format(round(x, d), big.mark = ".", decimal.mark = ",", nsmall = d,
                                 scientific = FALSE, trim = TRUE)
AZUL <- "#1f5f99"; ROJO <- "#d4593a"; AMBAR <- "#e8a33d"; VERDE <- "#5a9e6f"
COLOR_ALERTA <- c(Normal = "#cfe3cf", Media = "#f2c46d", Alta = ROJO)
DIAS <- c("Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo")
MESES_C <- c("Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic")

# ---- Datos -------------------------------------------------------------------
ruta_datos <- buscar("02_datos_limpios/riobamba_depurada.rds")
if (is.na(ruta_datos)) stop("Falta 02_datos_limpios/riobamba_depurada.rds: ejecutar scripts 01 a 04.")
datos <- readRDS(ruta_datos) %>%
  mutate(dia_semana = factor(DIAS[wday(fecha, week_start = 1)], levels = DIAS),
         semana = floor_date(fecha, "week", week_start = 1),
         categoria = coalesce(categoria, "Otros servicios"))
FECHA_MIN <- min(datos$fecha); FECHA_MAX <- max(datos$fecha)

leer <- function(r) { p <- buscar(r); if (is.na(p)) NULL else readRDS(p) }
pron <- leer("03_resultados/modelos/pronosticos.rds")
pred <- leer("03_resultados/modelos/predicciones_prueba.rds")
tend <- leer("03_resultados/modelos/tendencia_2029.rds")
info <- leer("03_resultados/modelos/info_modelo.rds")
ruta_mapa <- buscar("04_mapas/parroquias_riobamba.gpkg")
capa <- if (!is.na(ruta_mapa)) sf::st_transform(sf::st_read(ruta_mapa, quiet = TRUE), 4326) else NULL

parroquias <- datos %>% count(parroquia_corta, sort = TRUE) %>% pull(parroquia_corta)
FOCO <- intersect(c("FLORES", "CUBIJIES"), parroquias)
categorias <- datos %>% filter(servicio == "Seguridad Ciudadana") %>%
  count(categoria, sort = TRUE) %>% pull(categoria)
PALETA_CAT <- setNames(c("#1f5f99", "#e8a33d", "#d4593a", "#8e5ea2", "#5a9e6f", "#7f8c8d",
                         "#c0392b", "#16a085", "#b0b7bf")[seq_along(union(categorias, "Otros servicios"))],
                       union(categorias, "Otros servicios"))

grafico <- function(g, alto = NULL, leyenda = TRUE) {
  # Se calcula con un tamaño fijo (evita el error "invalid width or height" en
  # Shiny) y luego se deja que el gráfico ocupe todo el espacio disponible.
  p <- ggplotly(g, tooltip = "text", width = 900, height = if (is.null(alto)) 340 else alto)
  p$x$layout$width <- NULL
  if (is.null(alto)) p$x$layout$height <- NULL
  p %>%
    config(displaylogo = FALSE, locale = "es",
           modeBarButtonsToRemove = c("lasso2d", "select2d", "autoScale2d")) %>%
    layout(showlegend = leyenda, legend = list(orientation = "h", y = -0.15))
}
TITULO_PROYECTO <- paste("Análisis predictivo de patrones delictivos mediante técnicas de Ciencia de",
                         "Datos e Inteligencia Artificial para el fortalecimiento de la seguridad ciudadana 2026–2029")
# Categorías consideradas "patrones delictivos" (sin pedidos de patrullaje ni otros servicios)
CAT_DELICTIVAS <- c("Delitos contra la propiedad", "Delitos contra las personas",
                    "Violencia intrafamiliar / de género", "Drogas", "Convivencia y orden público")
EQUIPO <- tibble::tribble(
  ~Equipo, ~Integrante, ~Rol,
  "Equipo 1", "Gabriela Katheryne Asitimbay Morocho", "Coordinación, actas e informe",
  "Equipo 1", "Nelcy Nathaly Ávila Morocho", "Limpieza de datos",
  "Equipo 1", "Melanie Sarahí Bolaños Espín", "Limpieza y diccionario de datos",
  "Equipo 1", "Sonia del Pilar Calle Arévalo", "Análisis exploratorio y gráficos",
  "Equipo 1", "Rubén Darío Casa Casa", "Variables y modelos predictivos",
  "Equipo 2", "Anthony Joel Catagua Chulca", "Dashboard",
  "Equipo 2", "Edgar Fabricio Chamba Rodríguez", "Mapas geoespaciales",
  "Equipo 2", "Emily Estefanía Damián Tufiño", "Manuales y capacitación",
  "Equipo 2", "Walter Eduardo García Benítez", "Informe y control de anexos")
tema <- theme_minimal(base_size = 12) + theme(panel.grid.minor = element_blank())
aviso <- function(txt) div(class = "p-4 text-muted", ico("info-circle"), " ", txt)

# ---- Interfaz ----------------------------------------------------------------
ui <- page_sidebar(
  title = div(class = "d-flex align-items-center gap-3",
              div(class = "fw-bold", "UNACH · CDIA"),
              div(div(class = "fw-semibold", "Proyecto STANFORD · Dashboard predictivo de seguridad ciudadana 2026–2029"),
                  div(class = "small opacity-75",
                      "Patrones delictivos · Riobamba, parroquias Flores y Cubijíes · Datos ECU 911"))),
  window_title = "Proyecto STANFORD · UNACH",
  theme = bs_theme(version = 5, primary = AZUL, secondary = "#5c6b7a", success = VERDE,
                   warning = AMBAR, danger = ROJO, "navbar-bg" = AZUL,
                   base_font = font_collection("Segoe UI", "Roboto", "Helvetica", "Arial", "sans-serif")),
  fillable = FALSE,
  sidebar = sidebar(
    width = 300, title = "Filtros",
    selectizeInput("parroquia", "Parroquias", choices = parroquias, selected = FOCO,
                   multiple = TRUE, options = list(plugins = list("remove_button"))),
    div(class = "small mb-2",
        actionLink("solo_foco", "Flores y Cubijíes"), " · ",
        actionLink("todas", "Todas"), " · ",
        actionLink("rurales", "Solo rurales")),
    selectInput("servicio", "Servicio", choices = sort(unique(datos$servicio)),
                selected = "Seguridad Ciudadana", multiple = TRUE),
    input_switch("solo_delictivo", "Solo patrones delictivos", value = FALSE),
    div(class = "small text-muted mb-2 mt-n2",
        "Excluye pedidos de patrullaje, personas desaparecidas y otros servicios."),
    selectizeInput("categoria", "Categoría (vacío = todas)", choices = categorias,
                   multiple = TRUE, options = list(placeholder = "Todas las categorías")),
    selectizeInput("subtipo", "Subtipo (vacío = todos)", choices = NULL, multiple = TRUE,
                   options = list(placeholder = "Todos los subtipos")),
    dateRangeInput("fechas", "Periodo", start = max(FECHA_MAX - 364, FECHA_MIN), end = FECHA_MAX,
                   min = FECHA_MIN, max = FECHA_MAX, language = "es", separator = "a",
                   format = "dd/mm/yyyy"),
    div(class = "small mb-3",
        actionLink("p_anio", "Último año"), " · ", actionLink("p_3", "3 años"), " · ",
        actionLink("p_todo", "Todo")),
    downloadButton("descargar", "Descargar datos (CSV)", class = "btn-outline-primary btn-sm w-100"),
    hr(),
    div(class = "small text-muted",
        "Fuente: ECU 911 (datos abiertos, CC BY 4.0) · ",
        format(FECHA_MIN, "%m/%Y"), " a ", format(FECHA_MAX, "%m/%Y"),
        br(), "Datos anonimizados y agregados por parroquia.", br(), br(),
        "UNACH · Carrera de Ciencia de Datos e Inteligencia Artificial · ",
        "Prácticas de Servicio Comunitario 2026-2S")
  ),

  layout_column_wrap(
    width = 1/4, fill = FALSE,
    value_box("Incidentes en el periodo", textOutput("k_total"), textOutput("k_var"),
              showcase = ico("clipboard-data"), theme = "primary"),
    value_box("Promedio semanal", textOutput("k_semana"), textOutput("k_semana_det"),
              showcase = ico("calendar-week"), theme = "light"),
    value_box("Categoría principal", div(class = "fs-5", textOutput("k_cat")), textOutput("k_cat_pct"),
              showcase = ico("tags"), theme = "light"),
    uiOutput("vb_pron")
  ),

  navset_card_underline(
    id = "pestanas", selected = "Resumen",
    nav_panel("Proyecto", icon = ico("house"),
      layout_columns(col_widths = c(8, 4),
        card(card_header(class = "bg-primary text-white", "Proyecto STANFORD"),
             h5(TITULO_PROYECTO),
             p(class = "text-muted", "Universidad Nacional de Chimborazo · Carrera de Ciencia de Datos e ",
               "Inteligencia Artificial, en articulación con la carrera de Criminalística · ",
               "Componente C1: análisis predictivo de patrones delictivos para el fortalecimiento de la ",
               "seguridad ciudadana."),
             h6("Objetivo"),
             p("Procesar registros históricos de incidentes, identificar patrones espaciotemporales y ",
               "generar modelos predictivos de comportamiento delictivo, presentados en tableros y mapas ",
               "de calor como insumo para la toma de decisiones de las autoridades."),
             h6("Beneficiarios directos"),
             p("Parroquias ", strong("Flores"), " y ", strong("Cubijíes"), " del cantón Riobamba, provincia ",
               "de Chimborazo. Los modelos se entrenan con las 12 parroquias del cantón y se reportan aparte."),
             h6("Alcance"),
             p(class = "small", "Solución piloto escalable para demostrar el valor de la Inteligencia ",
               "Artificial en la prevención situacional del delito, con una arquitectura documentada y ",
               "replicable por las instituciones de seguridad ciudadana.")),
        card(card_header("Datos y periodo"),
             p(ico("database"), " Base de emergencias ECU 911 (datos abiertos, CC BY 4.0)"),
             p(ico("calendar3"), " ", format(FECHA_MIN, "%m/%Y"), " a ", format(FECHA_MAX, "%m/%Y"),
               " · ", fmt(nrow(datos)), " incidentes en Riobamba"),
             p(ico("graph-up-arrow"), " Pronóstico semanal (4 semanas) y tendencia mensual hasta diciembre 2029"),
             p(ico("shield-lock"), " Datos anonimizados, publicados solo de forma agregada"),
             hr(),
             p(strong("Director del proyecto: "), "Ing. Ronny Pomboza, Mgs."),
             p(strong("Docentes tutores: "), "Ing. Ronny Pomboza (Equipo 1) · Ing. Johanna Moyano Arias (Equipo 2)"),
             p(class = "small text-muted", "Fecha de la intervención: 19-10-2026 a 20-11-2026"))),
      layout_columns(col_widths = c(6, 6),
        card(card_header("Productos del proyecto en este dashboard"),
             tags$table(class = "table table-sm small mb-0",
               tags$tbody(
                 tags$tr(tags$td("Análisis exploratorio y patrones espaciotemporales"), tags$td("Resumen · Perfil de parroquia")),
                 tags$tr(tags$td("Modelos predictivos evaluados"), tags$td("Modelos")),
                 tags$tr(tags$td("Alertas predictivas para operadores"), tags$td("Pronóstico y alertas")),
                 tags$tr(tags$td("Tendencias 2026–2029"), tags$td("Tendencia 2029")),
                 tags$tr(tags$td("Mapas de calor geoespaciales"), tags$td("Mapa · Resumen")),
                 tags$tr(tags$td("Repositorio depurado"), tags$td("Datos (descarga CSV)"))))),
        card(card_header("Equipo de estudiantes"),
             DTOutput("t_equipo")))),
    nav_panel("Resumen", icon = ico("speedometer2"),
      layout_columns(col_widths = c(8, 4),
        card(card_header("Incidentes por semana"), plotlyOutput("g_semana", height = 330)),
        card(card_header("Por categoría"), plotlyOutput("g_cat", height = 330))),
      layout_columns(col_widths = c(6, 6),
        card(card_header("¿Cuándo ocurren? Promedio diario por día y mes"),
             plotlyOutput("g_calor", height = 320)),
        card(card_header("Subtipos más frecuentes"), plotlyOutput("g_subtipo", height = 320))),
      card(card_header("Mapa de calor: patrones delictivos por parroquia y año (incidentes por cada 100 del total de la parroquia)"),
           plotlyOutput("g_calor_parroquia", height = 380),
           card_footer(class = "small text-muted",
                       "Usa todas las parroquias y años, con el servicio elegido. ",
                       "Permite ver qué tipo de delito pesa más en cada parroquia y cómo cambia en el tiempo."))),

    nav_panel("Pronóstico y alertas", icon = ico("bell"),
      if (is.null(pron)) aviso("Ejecutar scripts/10_modelos.R para ver los pronósticos.") else tagList(
        layout_columns(col_widths = c(8, 4),
          card(card_header("Incidentes esperados en las próximas 4 semanas"),
               plotlyOutput("g_pron", height = 340)),
          card(card_header("¿Cómo leer la alerta?"),
               p(span(class = "badge", style = paste0("background:", COLOR_ALERTA["Alta"]), "Alta"),
                 " el pronóstico supera en 25 % o más el promedio de las últimas 52 semanas."),
               p(span(class = "badge text-dark", style = paste0("background:", COLOR_ALERTA["Media"]), "Media"),
                 " lo supera entre 10 % y 25 %."),
               p(span(class = "badge text-dark", style = paste0("background:", COLOR_ALERTA["Normal"]), "Normal"),
                 " dentro de lo habitual."),
               p(class = "small text-muted", "La barra negra es el rango probable (80 %). ",
                 "En parroquias con pocos casos, como Flores, un solo incidente cambia mucho: ",
                 "la alerta es una señal para planificar, no una certeza."))),
        card(card_header("Alertas para operadores · próxima semana (todas las parroquias, ordenadas por prioridad)"),
             DTOutput("t_alertas")),
        card(card_header("Detalle por parroquia y semana"), DTOutput("t_pron")))),

    nav_panel("Tendencia 2029", icon = ico("graph-down"),
      if (is.null(tend)) aviso("Ejecutar scripts/12_tendencia_2029.R para ver la tendencia.") else tagList(
        card(card_header("Incidentes por mes: real y tendencia esperada hasta diciembre 2029"),
             full_screen = TRUE, uiOutput("tend_ui"),
             card_footer(class = "small text-muted",
                         "Línea roja: tendencia esperada · bandas: rango probable 80 % y 95 %. ",
                         "Supone que se mantienen las condiciones actuales; se actualiza cada mes.")),
        card(card_header("Totales por año"), DTOutput("t_tend")))),

    nav_panel("Mapa", icon = ico("geo-alt"),
      if (is.null(capa)) aviso("Ejecutar scripts/08_mapas.R para ver el mapa.") else
        layout_columns(col_widths = c(9, 3),
          card(full_screen = TRUE, leaflet::leafletOutput("mapa", height = 540)),
          card(card_header("Capa"),
               radioButtons("capa_mapa", NULL,
                            choices = c("Alerta próxima semana", "Incidentes del periodo",
                                        "Incidentes por km²", "Cambio esperado 2025-2029")),
               p(class = "small text-muted",
                 "Las parroquias elegidas en el filtro aparecen con borde azul. ",
                 "Pase el mouse sobre una parroquia para ver el detalle.")))),

    nav_panel("Perfil de parroquia", icon = ico("person-vcard"),
      selectInput("perfil", "Parroquia", choices = parroquias,
                  selected = if (length(FOCO)) FOCO[1] else parroquias[1]),
      layout_column_wrap(width = 1/4, fill = FALSE,
        value_box("Incidentes registrados", textOutput("p_total"), textOutput("p_periodo"), theme = "light"),
        value_box("Promedio mensual", textOutput("p_mes"), "último año completo", theme = "light"),
        value_box("Participación en el cantón", textOutput("p_pct"), "del total de Riobamba", theme = "light"),
        value_box("Tendencia a 2029", textOutput("p_2029"), "cambio esperado vs. 2025", theme = "light")),
      layout_columns(col_widths = c(6, 6),
        card(card_header("Incidentes por año y categoría"), plotlyOutput("g_p_anio", height = 320)),
        card(card_header("Por día de la semana"), plotlyOutput("g_p_dia", height = 320))),
      card(card_header("Subtipos más frecuentes (todo el periodo)"), DTOutput("t_p_sub"))),

    nav_panel("Modelos", icon = ico("cpu"),
      if (is.null(pred)) aviso("Ejecutar scripts/10_modelos.R.") else tagList(
        layout_columns(col_widths = c(7, 5),
          card(card_header("Error de cada modelo en el año de prueba (MAE, incidentes por semana)"),
               DTOutput("t_modelos")),
          card(card_header("Lectura"),
               p("Se elige un modelo para la ciudad y otro para las parroquias rurales, porque la ",
                 "ciudad (unos 770 casos por semana) domina el error general."),
               p(strong("Urbana: "), textOutput("m_urb", inline = TRUE)),
               p(strong("Rurales: "), textOutput("m_rur", inline = TRUE)),
               p(class = "small text-muted",
                 "En Flores y Cubijíes los casos semanales son tan pocos que ni un modelo perfecto ",
                 "podría acertar el número exacto: el error ya está cerca del límite del azar. ",
                 "Por eso se usan rangos, probabilidades y la tendencia mensual."))),
        card(card_header("Predicción vs. real en el año de prueba"),
             selectInput("modelo", NULL, choices = sort(unique(pred$modelo)),
                         selected = "Elegido por zona", width = "420px"),
             uiOutput("pred_ui")))),

    nav_panel("Datos", icon = ico("table"), DTOutput("tabla"))
  )
)

# ---- Servidor ----------------------------------------------------------------
server <- function(input, output, session) {
  observeEvent(input$todas, updateSelectizeInput(session, "parroquia", selected = parroquias))
  observeEvent(input$solo_foco, updateSelectizeInput(session, "parroquia", selected = FOCO))
  observeEvent(input$rurales, updateSelectizeInput(session, "parroquia",
                                                   selected = setdiff(parroquias, "RIOBAMBA")))
  observeEvent(input$p_anio, updateDateRangeInput(session, "fechas", start = FECHA_MAX - 364, end = FECHA_MAX))
  observeEvent(input$p_3, updateDateRangeInput(session, "fechas", start = FECHA_MAX - 3 * 365, end = FECHA_MAX))
  observeEvent(input$p_todo, updateDateRangeInput(session, "fechas", start = FECHA_MIN, end = FECHA_MAX))
  observe({
    st <- datos %>% filter(servicio %in% input$servicio,
                           if (length(input$categoria)) categoria %in% input$categoria else TRUE) %>%
      count(subtipo, sort = TRUE)
    updateSelectizeInput(session, "subtipo", choices = st$subtipo, server = TRUE)
  })

  # Filtro común (sin fechas) para reutilizar en el año anterior y en el mapa
  base_filtro <- reactive({
    d <- datos %>% filter(servicio %in% input$servicio)
    if (isTRUE(input$solo_delictivo)) d <- d %>% filter(categoria %in% CAT_DELICTIVAS)
    if (length(input$categoria)) d <- d %>% filter(categoria %in% input$categoria)
    if (length(input$subtipo)) d <- d %>% filter(subtipo %in% input$subtipo)
    d
  })
  filtrados <- reactive({
    req(input$fechas)
    base_filtro() %>% filter(parroquia_corta %in% input$parroquia,
                             fecha >= input$fechas[1], fecha <= input$fechas[2])
  })
  anterior <- reactive({
    base_filtro() %>% filter(parroquia_corta %in% input$parroquia,
                             fecha >= input$fechas[1] - 365, fecha <= input$fechas[2] - 365)
  })
  semanas <- reactive(max(1, as.numeric(input$fechas[2] - input$fechas[1] + 1) / 7))

  # ---- Indicadores ----
  output$k_total <- renderText(fmt(nrow(filtrados())))
  output$k_var <- renderText({
    a <- nrow(anterior())
    if (input$fechas[1] - 365 < FECHA_MIN || a == 0) return("sin año anterior para comparar")
    v <- 100 * (nrow(filtrados()) / a - 1)
    paste0(if (v >= 0) "▲ +" else "▼ ", fmt(v, 1), " % vs. mismo periodo del año anterior")
  })
  output$k_semana <- renderText(fmt(nrow(filtrados()) / semanas(), 1))
  output$k_semana_det <- renderText(paste(fmt(semanas()), "semanas analizadas"))
  output$k_cat <- renderText({
    c <- filtrados() %>% count(categoria, sort = TRUE)
    if (nrow(c)) c$categoria[1] else "-"
  })
  output$k_cat_pct <- renderText({
    c <- filtrados() %>% count(categoria, sort = TRUE)
    if (nrow(c)) paste0(fmt(100 * c$n[1] / sum(c$n), 1), " % de los incidentes") else ""
  })
  output$vb_pron <- renderUI({
    if (is.null(pron)) return(value_box("Próxima semana", "-", "sin pronóstico", theme = "light"))
    p <- pron %>% filter(horizonte == 1, parroquia_corta %in% input$parroquia)
    if (!nrow(p)) return(value_box("Próxima semana", "-", "elija parroquias", theme = "light"))
    alertas <- p %>% filter(alerta != "Normal")
    tema_vb <- if (any(p$alerta == "Alta")) "danger" else if (nrow(alertas)) "warning" else "success"
    value_box(paste("Pronóstico semana del", format(min(p$semana_inicio), "%d/%m")),
              paste(fmt(sum(p$prediccion), 1), "incidentes"),
              if (nrow(alertas)) paste("Alerta:", paste(alertas$parroquia_corta, collapse = ", "))
              else "Sin alertas en las parroquias elegidas",
              showcase = ico("bell"), theme = tema_vb)
  })

  # ---- Resumen ----
  output$g_semana <- renderPlotly({
    validate(need(length(input$parroquia) > 0, "Elija al menos una parroquia"))
    semanas_rango <- seq(floor_date(input$fechas[1], "week", week_start = 1),
                         floor_date(input$fechas[2], "week", week_start = 1), by = "week")
    d <- filtrados() %>% count(semana, parroquia_corta) %>%
      complete(semana = semanas_rango, parroquia_corta = input$parroquia, fill = list(n = 0L))
    g <- ggplot(d, aes(semana, n, colour = parroquia_corta, group = parroquia_corta,
                       text = paste0(parroquia_corta, "<br>Semana del ", format(semana, "%d/%m/%Y"),
                                     "<br>", n, " incidentes"))) +
      geom_line(linewidth = 0.6) + labs(x = NULL, y = "Incidentes", colour = NULL) + tema
    grafico(g)
  })
  output$g_cat <- renderPlotly({
    d <- filtrados() %>% count(categoria) %>% mutate(pct = 100 * n / sum(n))
    validate(need(nrow(d) > 0, "Sin datos"))
    g <- ggplot(d, aes(reorder(categoria, n), n, fill = categoria,
                       text = paste0(categoria, "<br>", fmt(n), " (", fmt(pct, 1), " %)"))) +
      geom_col(show.legend = FALSE) + coord_flip() + scale_fill_manual(values = PALETA_CAT) +
      labs(x = NULL, y = "Incidentes") + tema
    grafico(g, leyenda = FALSE)
  })
  output$g_calor <- renderPlotly({
    d <- filtrados()
    validate(need(nrow(d) > 0, "Sin datos"))
    dias <- tibble(fecha = seq(input$fechas[1], input$fechas[2], by = "day")) %>%
      mutate(dia_semana = factor(DIAS[wday(fecha, week_start = 1)], levels = DIAS),
             mes = factor(MESES_C[month(fecha)], levels = MESES_C)) %>% count(dia_semana, mes, name = "dias")
    m <- d %>% mutate(mes = factor(MESES_C[month(fecha)], levels = MESES_C)) %>%
      count(dia_semana, mes) %>% right_join(dias, by = c("dia_semana", "mes")) %>%
      mutate(n = coalesce(n, 0L), promedio = n / dias)
    g <- ggplot(m, aes(mes, dia_semana, fill = promedio,
                       text = paste0(dia_semana, " · ", mes, "<br>", fmt(promedio, 2), " por día"))) +
      geom_tile(colour = "white") + scale_y_discrete(limits = rev(DIAS)) +
      scale_fill_gradient(low = "#eef3f8", high = ROJO, name = "Por día") +
      labs(x = NULL, y = NULL) + tema
    grafico(g)
  })
  output$g_subtipo <- renderPlotly({
    d <- filtrados() %>% count(subtipo, sort = TRUE) %>% slice_head(n = 10)
    validate(need(nrow(d) > 0, "Sin datos"))
    g <- ggplot(d, aes(reorder(substr(subtipo, 1, 45), n), n, text = paste0(subtipo, "<br>", fmt(n)))) +
      geom_col(fill = "#6f8fb0") + coord_flip() + labs(x = NULL, y = "Incidentes") + tema
    grafico(g)
  })

  # ---- Proyecto ----
  output$t_equipo <- renderDT(datatable(EQUIPO, rownames = FALSE,
                                        options = list(dom = "t", pageLength = 9, ordering = FALSE)))

  # ---- Mapa de calor parroquia × año (categorías delictivas) ----
  output$g_calor_parroquia <- renderPlotly({
    d <- datos %>% filter(servicio %in% input$servicio, categoria %in% CAT_DELICTIVAS) %>%
      count(parroquia_corta, anio, categoria) %>%
      group_by(parroquia_corta, anio) %>% mutate(pct = 100 * n / sum(n)) %>% ungroup() %>%
      group_by(parroquia_corta, categoria) %>% summarise(n = sum(n), pct = mean(pct), .groups = "drop")
    validate(need(nrow(d) > 0, "Sin datos de patrones delictivos para el servicio elegido"))
    d <- d %>% mutate(foco = parroquia_corta %in% FOCO,
                      etiqueta = if_else(foco, paste0("<b>", parroquia_corta, "</b>"), parroquia_corta))
    g <- ggplot(d, aes(categoria, reorder(parroquia_corta, foco), fill = pct,
                       text = paste0(parroquia_corta, " · ", categoria, "<br>", fmt(n), " incidentes",
                                     "<br>", fmt(pct, 1), " % de los patrones delictivos de la parroquia"))) +
      geom_tile(colour = "white") +
      scale_fill_gradient(low = "#eef3f8", high = ROJO, name = "%") +
      labs(x = NULL, y = NULL) + tema + theme(axis.text.x = element_text(angle = 20, hjust = 1))
    grafico(g)
  })

  # ---- Alertas para operadores ----
  output$t_alertas <- renderDT({
    a <- pron %>% filter(horizonte == 1) %>%
      mutate(prioridad = factor(alerta, levels = c("Alta", "Media", "Normal"))) %>%
      arrange(prioridad, desc(indice)) %>%
      transmute(Prioridad = alerta, Parroquia = parroquia_corta,
                `Esperados` = prediccion, `Rango probable` = paste(rango_bajo, "a", rango_alto),
                `Índice (100 = normal)` = indice, `Prob. ≥ 1 (%)` = prob_al_menos_1,
                `Beneficiaria` = if_else(parroquia_corta %in% FOCO, "Sí", ""))
    datatable(a, rownames = FALSE, options = list(dom = "t", pageLength = 12)) %>%
      formatStyle("Prioridad", backgroundColor = styleEqual(names(COLOR_ALERTA), unname(COLOR_ALERTA)),
                  fontWeight = "bold")
  })

  # ---- Pronóstico ----
  output$g_pron <- renderPlotly({
    d <- pron %>% filter(parroquia_corta %in% input$parroquia)
    validate(need(nrow(d) > 0, "Elija parroquias"))
    g <- ggplot(d, aes(semana_inicio, prediccion, fill = alerta,
                       text = paste0(parroquia_corta, " · semana del ", format(semana_inicio, "%d/%m"),
                                     "<br>Esperados: ", fmt(prediccion, 1),
                                     " (", fmt(rango_bajo), " a ", fmt(rango_alto), ")",
                                     "<br>Prob. de al menos 1: ", prob_al_menos_1, " %",
                                     "<br>Índice: ", indice, " · Alerta ", alerta))) +
      geom_col(width = 5) +
      geom_errorbar(aes(ymin = rango_bajo, ymax = rango_alto), width = 2, colour = "grey25") +
      facet_wrap(~parroquia_corta, scales = "free_y") +
      scale_fill_manual(values = COLOR_ALERTA, drop = FALSE) +
      labs(x = NULL, y = "Incidentes esperados", fill = "Alerta") + tema
    grafico(g)
  })
  output$t_pron <- renderDT(datatable(
    pron %>% filter(parroquia_corta %in% input$parroquia) %>%
      transmute(Parroquia = parroquia_corta, Semana = format(semana_inicio, "%d/%m/%Y"),
                `Esperados` = prediccion, `Rango probable` = paste(rango_bajo, "a", rango_alto),
                `Prob. ≥ 1 (%)` = prob_al_menos_1, `Índice` = indice, Alerta = alerta, Modelo = modelo),
    rownames = FALSE, options = list(pageLength = 8, dom = "tp")) %>%
      formatStyle("Alerta", backgroundColor = styleEqual(names(COLOR_ALERTA), unname(COLOR_ALERTA))))

  # ---- Tendencia 2029 ----
  alto_facetas <- function(base, por) reactive(base + por * max(1, length(input$parroquia)))
  alto_tend <- alto_facetas(120, 250); alto_pred <- alto_facetas(100, 210)
  output$tend_ui <- renderUI(plotlyOutput("g_tend", height = paste0(alto_tend(), "px")))
  output$pred_ui <- renderUI(plotlyOutput("g_pred", height = paste0(alto_pred(), "px")))
  output$g_tend <- renderPlotly({
    d <- tend %>% filter(parroquia_corta %in% input$parroquia)
    validate(need(nrow(d) > 0, "Elija parroquias"))
    pr <- d %>% filter(tipo == "Pronóstico")
    g <- ggplot(d, aes(mes)) +
      geom_ribbon(data = pr, aes(ymin = bajo95, ymax = alto95), fill = ROJO, alpha = 0.12) +
      geom_ribbon(data = pr, aes(ymin = bajo80, ymax = alto80), fill = ROJO, alpha = 0.25) +
      geom_line(data = filter(d, tipo == "Real"), aes(y = incidentes, group = 1,
                text = paste0(format(mes, "%m/%Y"), "<br>Real: ", fmt(incidentes))), colour = "grey35") +
      geom_line(data = pr, aes(y = incidentes, group = 1,
                text = paste0(format(mes, "%m/%Y"), "<br>Esperado: ", fmt(incidentes, 1),
                              "<br>Rango 80 %: ", fmt(bajo80), " a ", fmt(alto80))),
                colour = ROJO, linewidth = 0.9) +
      facet_wrap(~parroquia_corta, ncol = 1, scales = "free_y") +
      labs(x = NULL, y = "Incidentes por mes") + tema
    grafico(g, alto = alto_tend())
  })
  output$t_tend <- renderDT({
    t <- tend %>% filter(parroquia_corta %in% input$parroquia) %>%
      mutate(anio = year(mes)) %>% group_by(parroquia_corta, anio) %>%
      summarise(total = sum(incidentes), meses = n(), pron = sum(tipo == "Pronóstico"), .groups = "drop") %>%
      filter(meses == 12) %>% group_by(parroquia_corta) %>%
      mutate(cambio = 100 * (total / lag(total) - 1)) %>% ungroup() %>%
      transmute(Parroquia = parroquia_corta, Año = anio, Incidentes = round(total),
                `Cambio vs año anterior (%)` = round(cambio, 1),
                Tipo = case_when(pron == 0 ~ "Real", pron == 12 ~ "Pronóstico", TRUE ~ "Real + pronóstico"))
    datatable(t, rownames = FALSE, options = list(pageLength = 16, dom = "tp")) %>%
      formatStyle("Tipo", color = styleEqual(c("Pronóstico", "Real + pronóstico"), c(ROJO, AMBAR)))
  })

  # ---- Mapa ----
  if (!is.null(capa)) output$mapa <- leaflet::renderLeaflet({
    tipo <- input$capa_mapa
    m <- capa
    if (tipo == "Alerta próxima semana" && !is.null(pron)) {
      m <- m %>% left_join(pron %>% filter(horizonte == 1) %>%
                             select(cod_parroquia, valor = prediccion, rango_bajo, rango_alto, alerta),
                           by = "cod_parroquia")
      pal <- leaflet::colorFactor(unname(COLOR_ALERTA), levels = names(COLOR_ALERTA))
      relleno <- ~pal(alerta)
      etiqueta <- ~paste0("<b>", parroquia_corta, "</b><br>Esperados próxima semana: ", fmt(valor, 1),
                          " (", rango_bajo, "-", rango_alto, ")<br>Alerta: ", alerta)
      leyenda <- list(pal = pal, values = ~alerta, title = "Alerta")
    } else if (tipo == "Cambio esperado 2025-2029" && !is.null(tend)) {
      cambio <- tend %>% mutate(anio = year(mes)) %>% filter(anio %in% c(2025, 2029)) %>%
        group_by(cod_parroquia, anio) %>% summarise(t = sum(incidentes), .groups = "drop") %>%
        pivot_wider(names_from = anio, values_from = t, names_prefix = "a") %>%
        mutate(valor = round(100 * (a2029 / a2025 - 1), 1))
      m <- m %>% left_join(cambio, by = "cod_parroquia")
      lim <- max(abs(m$valor), na.rm = TRUE)
      pal <- leaflet::colorNumeric(c("#2b7bba", "white", ROJO), domain = c(-lim, lim))
      relleno <- ~pal(valor)
      etiqueta <- ~paste0("<b>", parroquia_corta, "</b><br>2025: ", fmt(a2025), " · 2029: ", fmt(a2029),
                          "<br>Cambio: ", valor, " %")
      leyenda <- list(pal = pal, values = ~valor, title = "Cambio %")
    } else {
      conteo <- base_filtro() %>% filter(fecha >= input$fechas[1], fecha <= input$fechas[2]) %>%
        count(cod_parroquia, name = "n")
      m <- m %>% left_join(conteo, by = "cod_parroquia") %>%
        mutate(n = coalesce(n, 0L), valor = if (tipo == "Incidentes por km²") round(n / area_km2, 2) else n)
      pal <- leaflet::colorNumeric("Blues", log10(m$valor + 1))
      relleno <- ~pal(log10(valor + 1))
      etiqueta <- ~paste0("<b>", parroquia_corta, "</b><br>", fmt(n), " incidentes en el periodo",
                          "<br>", fmt(n / area_km2, 2), " por km²")
      leyenda <- NULL
    }
    sel <- m$parroquia_corta %in% input$parroquia
    mapa <- leaflet::leaflet(m) %>% leaflet::addTiles() %>%
      leaflet::addPolygons(fillColor = relleno, fillOpacity = 0.75,
                           color = ifelse(sel, AZUL, "white"), weight = ifelse(sel, 3, 1),
                           label = lapply(eval(etiqueta[[2]], sf::st_drop_geometry(m)), htmltools::HTML),
                           highlightOptions = leaflet::highlightOptions(weight = 4, color = "#333")) %>%
      leaflet::addLabelOnlyMarkers(data = suppressWarnings(sf::st_point_on_surface(m)),
                                   label = ~parroquia_corta,
                                   labelOptions = leaflet::labelOptions(noHide = TRUE, textOnly = TRUE,
                                                                        style = list("font-size" = "10px", "font-weight" = "bold")))
    if (!is.null(leyenda)) mapa <- do.call(leaflet::addLegend, c(list(map = mapa, position = "bottomright"), leyenda))
    mapa
  })

  # ---- Perfil de parroquia ----
  perfil <- reactive(datos %>% filter(parroquia_corta == input$perfil, servicio %in% input$servicio))
  output$p_total <- renderText(fmt(nrow(perfil())))
  output$p_periodo <- renderText(paste(format(FECHA_MIN, "%m/%Y"), "a", format(FECHA_MAX, "%m/%Y")))
  output$p_mes <- renderText({
    d <- perfil() %>% filter(fecha > FECHA_MAX - 365)
    fmt(nrow(d) / 12, 1)
  })
  output$p_pct <- renderText({
    tot <- datos %>% filter(servicio %in% input$servicio) %>% nrow()
    paste0(fmt(100 * nrow(perfil()) / tot, 2), " %")
  })
  output$p_2029 <- renderText({
    if (is.null(tend)) return("-")
    t <- tend %>% filter(parroquia_corta == input$perfil) %>% mutate(a = year(mes)) %>%
      group_by(a) %>% summarise(t = sum(incidentes))
    v <- 100 * (t$t[t$a == 2029] / t$t[t$a == 2025] - 1)
    if (length(v)) paste0(if (v >= 0) "+" else "", fmt(v, 1), " %") else "-"
  })
  output$g_p_anio <- renderPlotly({
    d <- perfil() %>% count(anio, categoria)
    validate(need(nrow(d) > 0, "Sin datos"))
    g <- ggplot(d, aes(factor(anio), n, fill = categoria,
                       text = paste0(anio, " · ", categoria, "<br>", n, " incidentes"))) +
      geom_col() + scale_fill_manual(values = PALETA_CAT) +
      labs(x = NULL, y = "Incidentes (2021: jul-dic · 2026: ene-sep)", fill = NULL) + tema
    grafico(g)
  })
  output$g_p_dia <- renderPlotly({
    d <- perfil() %>% count(dia_semana) %>% mutate(pct = 100 * n / sum(n))
    g <- ggplot(d, aes(dia_semana, n, text = paste0(dia_semana, "<br>", n, " (", fmt(pct, 1), " %)"))) +
      geom_col(fill = AZUL) + labs(x = NULL, y = "Incidentes") + tema
    grafico(g)
  })
  output$t_p_sub <- renderDT(datatable(
    perfil() %>% count(Categoría = categoria, Subtipo = subtipo, sort = TRUE, name = "Incidentes") %>%
      mutate(`%` = round(100 * Incidentes / sum(Incidentes), 1)),
    rownames = FALSE, options = list(pageLength = 10, dom = "ftp", language = list(search = "Buscar:"))))

  # ---- Modelos ----
  if (!is.null(pred)) {
    output$m_urb <- renderText(if (!is.null(info$elegido_urbana)) info$elegido_urbana else "-")
    output$m_rur <- renderText(if (!is.null(info$elegido_rural)) info$elegido_rural else "-")
    output$t_modelos <- renderDT({
      t <- bind_rows(
        pred %>% filter(cod_parroquia == "060150") %>% mutate(g = "Urbana"),
        pred %>% filter(cod_parroquia != "060150") %>% mutate(g = "Rurales"),
        pred %>% filter(cod_parroquia == "060153") %>% mutate(g = "Cubijíes"),
        pred %>% filter(cod_parroquia == "060154") %>% mutate(g = "Flores")) %>%
        group_by(Modelo = modelo, g) %>% summarise(MAE = round(mean(abs(real - prediccion)), 2), .groups = "drop") %>%
        pivot_wider(names_from = g, values_from = MAE) %>% arrange(Urbana)
      datatable(t, rownames = FALSE, options = list(pageLength = 20, dom = "t")) %>%
        formatStyle("Modelo", target = "row",
                    fontWeight = styleEqual("Elegido por zona", "bold"),
                    backgroundColor = styleEqual("Elegido por zona", "#fdeee9"))
    })
    output$g_pred <- renderPlotly({
      d <- pred %>% filter(modelo == input$modelo, parroquia_corta %in% input$parroquia)
      validate(need(nrow(d) > 0, "Elija parroquias"))
      g <- ggplot(d, aes(semana_inicio)) +
        geom_col(aes(y = real, text = paste0(format(semana_inicio, "%d/%m/%Y"), "<br>Real: ", real)),
                 fill = "grey80") +
        geom_line(aes(y = prediccion, group = 1,
                      text = paste0("Predicción: ", fmt(prediccion, 1))), colour = ROJO, linewidth = 0.8) +
        facet_wrap(~parroquia_corta, ncol = 1, scales = "free_y") +
        labs(x = NULL, y = "Incidentes por semana") + tema
      grafico(g, alto = alto_pred())
    })
  }

  # ---- Datos ----
  output$tabla <- renderDT(datatable(
    filtrados() %>% transmute(Fecha = fecha, Parroquia = parroquia_corta, Servicio = servicio,
                              Categoría = categoria, Subtipo = subtipo) %>% arrange(desc(Fecha)),
    rownames = FALSE, filter = "top",
    options = list(pageLength = 15, language = list(search = "Buscar:"))))
  output$descargar <- downloadHandler(
    filename = function() paste0("incidentes_filtrados_", format(Sys.Date(), "%Y%m%d"), ".csv"),
    content = function(f) readr::write_excel_csv(
      filtrados() %>% select(fecha, parroquia_corta, cod_parroquia, servicio, categoria, subtipo), f))
}

shinyApp(ui, server)
