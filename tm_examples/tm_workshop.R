library(tidymodels)
setwd("~/projects/bigelow/tm_examples")
library(randomForest)

plot_help <- function(results) {
  ggplot(mapping = aes(x = Year)) + 
    geom_point(data = dataset, 
               aes(y = Pounds), 
               col = "grey") +
    geom_line(data = dataset, 
               aes(y = Pounds), 
               col = "grey") +
    geom_line(data = results, 
              aes(y = .pred), 
              col = "orange") + 
    geom_point(data = results,
               aes(y = .pred), 
               col = "black")
}

# reading in the data 
dataset <- c("amo.csv", "gsi.csv", "nao.csv", "herring.csv") |>
  lapply(function(x) readr::read_csv(file.path("data", x))) |>
  purrr::reduce(function(x, y) merge(x, y, by = "Year")) |>
  select(Year, Pounds, starts_with("mean"))

# plotting the data 
ggplot(dataset, mapping = aes(x = Year, y = Pounds)) + geom_point()

set.seed(234)

# RSample 
data_split <- initial_split(dataset, prop = 3/4)

testing <- testing(data_split)
training <- training(data_split)

# Recipes
recipe <- recipe(Pounds ~ ., data = training) |>
  step_corr(all_numeric_predictors()) |>
  step_naomit(all_predictors()) |>
  step_ns(all_numeric_predictors, deg_free = 7) |>
  prep() 

formula <- formula(recipe)

model <- linear_reg(mode = "regression", 
                    engine = "lm", 
                    penalty = NULL)

workflow <- workflow() |>
  add_recipe(recipe) |>
  add_model(model)

fit <- last_fit(workflow, data_split)

fit |>
  augment() |>
  plot_help()

# Workflow
if (FALSE) {

workflow_temp <- workflow(preprocessor = recipe) 

wkf_help <- function(model) {
  workflow_temp |>
    add_model(model) |>
    fit(training) |>
    augment(testing)
}

# GAM
gam <- workflow_temp |>
  add_model(gen_additive_mod(mode = "regression"), 
            formula = Pounds ~ s(mean_amo) + s(mean_gsi) + s(mean_nao)) |>
  fit(training) |>
  augment(testing)

# random forest
ranger <- rand_forest(mode = "regression", 
                      engine = "ranger", 
                      trees = 500) |>
  wkf_help()

randomForest <- rand_forest(mode = "regression", 
                            engine = "randomForest", 
                            trees = 500) |>
  wkf_help()

yardstick::metrics(gam, Pounds, .pred)

plot_help(ranger, "RF Ranger")
plot_help(randomForest, "RF randomForest")
plot_help(gam, "GAM")

}


