# R3 · Random forest (ranger): todas juntas vs. separado urbana / rurales
source("revision/R0_base_revision.R")
sink("revision/salidas/R3.txt", split = TRUE)
VARS <- c(CONTEOS, CALENDARIO, "urbana", "parroquia")
rf <- function(datos, vars, mtry = NULL, min_n = 5)
  ranger::ranger(reformulate(vars, "incidentes"), data = datos, num.trees = 500,
                 mtry = mtry, min.node.size = min_n, seed = 2026, importance = "impurity")
titulo("R3a · RF todas juntas")
m <- rf(train, VARS); registrar("RF juntas", predict(m, test)$predictions)
print(head(sort(m$variable.importance, decreasing = TRUE), 8))
titulo("R3b · RF separado")
vu <- setdiff(VARS, c("urbana", "parroquia"))
mu <- rf(train %>% filter(cod_parroquia == URB), vu)
mr <- rf(train %>% filter(cod_parroquia != URB), setdiff(VARS, "urbana"))
p <- numeric(nrow(test))
p[test$cod_parroquia == URB] <- predict(mu, test %>% filter(cod_parroquia == URB))$predictions
p[test$cod_parroquia != URB] <- predict(mr, test %>% filter(cod_parroquia != URB))$predictions
registrar("RF separado", p)
titulo("R3c · RF rural con menos variables (evita ruido)")
mr2 <- rf(train %>% filter(cod_parroquia != URB), c("ma4", "ma8", "ma12", "lag52", "sin_semana", "cos_semana", "parroquia"), min_n = 20)
p2 <- p; p2[test$cod_parroquia != URB] <- predict(mr2, test %>% filter(cod_parroquia != URB))$predictions
registrar("RF juntas-urb + RF rural simple", {q <- predict(m, test)$predictions; q[test$cod_parroquia != URB] <- p2[test$cod_parroquia != URB]; q})
sink()
