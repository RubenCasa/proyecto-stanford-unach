# R2 · Modelos lineales generalizados (Poisson y binomial negativa)
#      Se prueban: (a) todas las parroquias juntas, (b) separado urbana / rurales
source("revision/R0_base_revision.R")
sink("revision/salidas/R2.txt", split = TRUE)
prep <- function(d) d %>% mutate(across(all_of(CONTEOS), log1p))
f_full <- reformulate(c(CONTEOS, "sin_semana", "cos_semana", "n_feriados", "semana_pago",
                        "fin_de_mes", "tendencia", "parroquia"), "incidentes")
f_simple <- reformulate(c("ma4", "ma12", "lag52", "sin_semana", "cos_semana", "n_feriados",
                          "tendencia", "parroquia"), "incidentes")
ajusta <- function(form, fam, datos) {
  if (fam == "poisson") glm(form, family = poisson(), data = prep(datos))
  else MASS::glm.nb(form, data = prep(datos))
}
f_urb_full <- update(f_full, . ~ . - parroquia); f_urb_simple <- update(f_simple, . ~ . - parroquia)
titulo("R2a · Poisson, todas juntas")
registrar("Poisson juntas", predict(ajusta(f_full, "poisson", train), prep(test), type = "response"))
titulo("R2b · Binomial negativa, todas juntas")
registrar("BinNeg juntas", tryCatch(predict(ajusta(f_full, "nb", train), prep(test), type = "response"),
                                    error = function(e) rep(NA, nrow(test))))
titulo("R2c · Poisson separado (urbana sin variable parroquia)")
pu <- predict(ajusta(f_urb_full, "poisson", train %>% filter(cod_parroquia == URB)),
              prep(test %>% filter(cod_parroquia == URB)), type = "response")
mr <- ajusta(f_full, "poisson", train %>% filter(cod_parroquia != URB) %>% mutate(parroquia = droplevels(parroquia)))
pr <- predict(mr, prep(test %>% filter(cod_parroquia != URB) %>%
                         mutate(parroquia = factor(as.character(parroquia), levels = levels(droplevels(train$parroquia[train$cod_parroquia != URB]))))),
              type = "response")
p <- numeric(nrow(test)); p[test$cod_parroquia == URB] <- pu; p[test$cod_parroquia != URB] <- pr
registrar("Poisson separado", p)
titulo("R2d · Binomial negativa separada, fórmula simple (menos variables)")
pu <- predict(ajusta(f_urb_simple, "nb", train %>% filter(cod_parroquia == URB)),
              prep(test %>% filter(cod_parroquia == URB)), type = "response")
mr <- ajusta(f_simple, "poisson", train %>% filter(cod_parroquia != URB) %>% mutate(parroquia = droplevels(parroquia)))
pr <- predict(mr, prep(test %>% filter(cod_parroquia != URB) %>%
                         mutate(parroquia = factor(as.character(parroquia), levels = levels(droplevels(train$parroquia[train$cod_parroquia != URB]))))),
              type = "response")
p[test$cod_parroquia == URB] <- pu; p[test$cod_parroquia != URB] <- pr
registrar("BinNeg urb + Poisson rural simple", p)
sink()
