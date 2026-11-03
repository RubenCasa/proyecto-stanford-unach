# =============================================================================
# PROYECTO STANFORD · 00_instalar_paquetes.R
# DÍA 4 (Jue 22-oct) · Configuración del entorno de trabajo en R
# TODOS lo ejecutan UNA VEZ en su computador.
#   - Rubén: paquetes de modelado (tidymodels)
#   - Sonia: paquetes de EDA (ggplot2, skimr)
#   - Anthony: paquetes del dashboard (shiny)
#   - Edgar: paquetes de mapas (sf, geodata, leaflet)
#   - Nelcy y Melanie: paquetes de limpieza (janitor, naniar, lubridate)
# Evidencia día 4: captura de RStudio con el proyecto abierto y este script
# terminado sin errores.
# =============================================================================

paquetes <- list(
  "Importación y limpieza (Nelcy, Melanie)" =
    c("readr", "readxl", "dplyr", "tidyr", "stringr", "stringi", "lubridate",
      "janitor", "naniar", "writexl"),
  "Análisis exploratorio (Sonia)" =
    c("ggplot2", "scales", "skimr"),
  "Variables y modelos (Rubén)" =
    c("tidymodels", "ranger", "xgboost", "MASS", "tsibble", "fable", "fabletools", "feasts"),
  "Mapas (Edgar)" =
    c("sf", "geodata", "terra", "leaflet", "htmlwidgets"),
  "Dashboard (Anthony)" =
    c("shiny", "bslib", "DT", "plotly", "bsicons"),
  "Informes (Walter, Gabriela, Emily)" =
    c("rmarkdown", "knitr", "quarto")
)

todos  <- unique(unlist(paquetes))
faltan <- todos[!todos %in% rownames(installed.packages())]

if (length(faltan) > 0) {
  message("Instalando ", length(faltan), " paquetes: ", paste(faltan, collapse = ", "))
  install.packages(faltan, repos = "https://cloud.r-project.org")
}

# Verificación por grupo
for (g in names(paquetes)) {
  ok <- paquetes[[g]] %in% rownames(installed.packages())
  message(sprintf("%-45s %s", g, if (all(ok)) "OK" else
    paste("FALTA:", paste(paquetes[[g]][!ok], collapse = ", "))))
}
message("\nR ", R.version$major, ".", R.version$minor,
        " · Proyecto en: ", getwd())
