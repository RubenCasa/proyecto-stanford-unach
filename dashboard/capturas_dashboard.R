# =============================================================================
# PROYECTO STANFORD · dashboard/capturas_dashboard.R
# Toma capturas de cada pestaña del dashboard (para el manual de usuario).
# Abre la app en segundo plano y la recorre con un Chrome invisible.
# Uso:  source("dashboard/capturas_dashboard.R")
# Salida: 05_documentos/capturas/*.png
# =============================================================================
setwd("C:/Users/RubenC/Desktop/PROYECTO STANFORD")
for (p in c("chromote", "callr")) if (!requireNamespace(p, quietly = TRUE))
  install.packages(p, repos = "https://cloud.r-project.org")
dir.create("05_documentos/capturas", recursive = TRUE, showWarnings = FALSE)

puerto <- 8765
app <- callr::r_bg(function(dir, port) shiny::runApp(dir, port = port, launch.browser = FALSE),
                   args = list(dir = normalizePath("dashboard"), port = puerto),
                   wd = normalizePath("."), supervise = TRUE)
# Esperar hasta que la app responda (máx. 3 minutos)
listo <- FALSE
for (i in 1:90) {
  Sys.sleep(2)
  if (!app$is_alive()) stop("La app se cerró:\n", app$read_all_error())
  listo <- tryCatch({ con <- url(paste0("http://127.0.0.1:", puerto)); open(con); close(con); TRUE },
                    error = function(e) FALSE, warning = function(w) FALSE)
  if (listo) break
}
if (!listo) stop("La app no respondió a tiempo:\n", app$read_error())
message("App lista después de ", i * 2, " segundos")

b <- chromote::ChromoteSession$new(width = 1440, height = 900)
b$Emulation$setDeviceMetricsOverride(width = 1440, height = 1500, deviceScaleFactor = 1, mobile = FALSE)
b$Page$navigate(paste0("http://127.0.0.1:", puerto)); Sys.sleep(15)

clic <- function(texto) {
  b$Runtime$evaluate(sprintf(
    "Array.from(document.querySelectorAll('a.nav-link')).find(a => a.textContent.trim() === '%s').click()", texto))
  Sys.sleep(7)
}
captura <- function(nombre, alto = 1500) {
  b$Emulation$setDeviceMetricsOverride(width = 1440, height = alto, deviceScaleFactor = 1, mobile = FALSE)
  Sys.sleep(2)
  b$screenshot(file.path("05_documentos/capturas", nombre), selector = "body", show = FALSE)
  message("captura: ", nombre)
}
pestanas <- c("Proyecto" = "01_proyecto.png", "Resumen" = "02_resumen.png",
              "Pronóstico y alertas" = "03_pronostico_alertas.png",
              "Tendencia 2029" = "04_tendencia_2029.png", "Mapa" = "05_mapa.png",
              "Perfil de parroquia" = "06_perfil_parroquia.png", "Modelos" = "07_modelos.png",
              "Datos" = "08_datos.png")
for (t in names(pestanas)) { clic(t); captura(pestanas[[t]], alto = if (t %in% c("Resumen", "Perfil de parroquia")) 1900 else 1400) }
# Filtros con "Solo patrones delictivos" activado
b$Runtime$evaluate("document.getElementById('solo_delictivo').click()"); Sys.sleep(6)
clic("Resumen"); captura("09_resumen_patrones_delictivos.png", alto = 1900)
b$close(); app$kill()
message("LISTO CAPTURAS")
