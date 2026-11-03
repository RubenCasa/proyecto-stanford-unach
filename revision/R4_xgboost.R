# R4 · XGBoost (objetivo Poisson): todas juntas vs. separado
source("revision/R0_base_revision.R")
sink("revision/salidas/R4.txt", split = TRUE)
VARS <- c(CONTEOS, CALENDARIO, "urbana")
mat <- function(d) cbind(as.matrix(d[VARS]), model.matrix(~ parroquia - 1, d))
xgb <- function(d, rounds = 400, depth = 4, eta = 0.05) {
  set.seed(2026)
  xgboost::xgb.train(params = list(objective = "count:poisson", max_depth = depth, eta = eta,
                                   subsample = 0.8, colsample_bytree = 0.8),
                     data = xgboost::xgb.DMatrix(mat(d), label = d$incidentes),
                     nrounds = rounds, verbose = 0)
}
titulo("R4a · XGBoost juntas")
m <- xgb(train); registrar("XGB juntas", predict(m, xgboost::xgb.DMatrix(mat(test))))
titulo("R4b · XGBoost rural aparte (urbana con XGB juntas)")
tr_r <- train %>% filter(cod_parroquia != URB); te_r <- test %>% filter(cod_parroquia != URB)
mr <- xgb(tr_r, rounds = 300, depth = 3, eta = 0.03)
p <- predict(m, xgboost::xgb.DMatrix(mat(test)))
p[test$cod_parroquia != URB] <- predict(mr, xgboost::xgb.DMatrix(mat(te_r)))
registrar("XGB rural aparte", p)
sink()
