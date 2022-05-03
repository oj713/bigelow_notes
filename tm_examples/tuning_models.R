# Tuning models and the dangers of overfitting

library(tidymodels)
data(cells) 

cells <- cells |> select(-case)

set.seed(41)
cell_folds <- vfold_cv(cells)

mlp_rec <- 
  recipe(class ~ ., data = cells) |>
  step_YeoJohnson(all_numeric_predictors()) |>
  step_normalize(all_numeric_predictors()) |>
  step_pca(all_numeric_predictors(), num_comp = tune()) |>
  step_normalize(all_numeric_predictors())

mlp_spec <- 
  mlp(hidden_units = tune(), penalty = tune(), epochs = tune()) |>
  set_engine("nnet", trace = 0) |>
  set_mode("classification")

mlp_workflow <- 
  workflow() |>
  add_model(mlp_spec) |>
  add_recipe(mlp_rec)

mlp_param <- mlp_workflow |>
  hardhat::extract_parameter_set_dials() |>
  update(
    epochs = epochs(c(50, 200)), 
    num_comp = num_comp(c(0, 40))
  )

roc_results <- metric_set(roc_auc)

mlp_reg_rune <- 
  mlp_workflow |>
  tune_grid(
    cell_folds, 
    grid = mlp_param |> grid_regular(levels = 3), 
    metrics = roc_res
  )



