library(tidymodels)
library(modeldata)

data(ames)

### Index ###
#' 14: Exploratory Data Analysis
#' 47: Spending Data
#' 80: Building a Model
#' 124: Workflows
#' 176: Recipes
#' 257: Yardstick

###### EXPLORATORY DATA ANALYSIS #########

glimpse(ames)

#outcome - sale price
ggplot(ames, aes(x = Sale_Price)) +
  theme_bw() +
  geom_histogram(bins = 50, fill="darkolivegreen", col = "white")

#' because this data is right skewed, we could log-scale the data
#' advantages: 
#' - no houses would be predicted with negative prices
#' - errors in predicting expensive houses wouldn't have high effect
#' - may stabilize variance to make inference > legitimate
#' 
#' disadvantages: 
#' - performance metrics will also be in log scale and require > processing

ggplot(ames, aes(x = Sale_Price)) +
  theme_bw() +
  geom_histogram(bins = 50, col = "white", fill = "darkolivegreen") +
  scale_x_log10()

ames <- ames |>
  mutate(Sale_Price = log10(Sale_Price))

#' Exploratory Data Analysis Questions
#' 
#' - are there oddities about the distributions of predictors? any skew?
#' - are there highly correlated predictors?
#' - are there associations btwn predictors & outcomes?


############### SPENDING DATA ###################

#' Spending data = splitting data 

set.seed(137)

#' Stratified Sampling
#' 
#' If the data has skew, we would want to consider stratified sampling.
#' Without stratification, random sampling might over-sample one group,
#'   meaning that that group will be overly predicted later on. 
#'  
#' Generally, it's best practice to use stratified sampling, 
#'   exempting time series data

ames_split <- initial_split(ames, prop = 3/4, strata = Sale_Price)

training <- training(ames_split)
testing <- testing(ames_split)

set.seed(NULL)


#' Additional Sampling Considerations
#' 
#' Inclusion of a Validation Set, or third small split of data to use
#'   for model tuning prior to the test set. Covered later. 
#'   
#' Multi-Level Data -- data points may not be fully independent, eg. if 
#'   multiple data points are from the same independent experimental unit. 
#'   Data splitting in these cases should occur at the ieu level of data. 


######## BUILDING A MODEL ##############

# use translate() to recieve information on how parsnip hands info to engines
model <- linear_reg() |> 
  set_engine("lm") 

model |> translate()

# regularized linear regression adds a penalty to least squares method 
# encourages simplicity by removing predictors & shrinking coefficients
linear_reg(penalty = 1) |> 
  set_engine("glmnet") |> translate()


# Example 1: predicting price from longitude and latitude

# by formula
lm_form_fit <- model |>
  fit(Sale_Price ~ Longitude + Latitude, data = training)

# by xy
lm_xy_fit <- model |>
  fit_xy(
    x = training |> select(Longitude, Latitude),
    y = training |> pull(Sale_Price)
  )

# to extract and examine the model output
lm_form_fit |> extract_fit_engine()

broom::tidy(lm_form_fit)


#' Notes on predict
#' 
#' - results are a tibble, with predictable names
#' - there are as many rows in tibble as in input data set

head(testing) |>
  select(Sale_Price) |>
  bind_cols(predict(lm_form_fit, head(testing))) |>
  bind_cols(predict(lm_form_fit, head(testing), type = "pred_int"))


############ WORKFLOWS ##############

lm_wkf <- workflow() |>
  add_model(model) |>
  add_formula(Sale_Price ~ Longitude + Latitude) |>
  fit(training) 

predict(lm_wkf, head(testing))

#' Workflow Sets 
#' 
#' When need multiple attempts to find appropriate model
#' workflowset package creates combinations of workflow components 
#' lists of preprocessors can be combined with list of model specifications

library(workflowsets)

preprocess_options <- list(
  longitude = Sale_Price ~ Longitude, 
  latitude = Sale_Price ~ Latitude,
  coords = Sale_Price ~ Latitude + Longitude,
  neighborhood = Sale_Price ~ Neighborhood
)

loc_models <- workflow_set(preproc = preprocess_options, 
                           models = list(lm = model))

loc_models 

loc_models$info[[1]]

extract_workflow(loc_models, id = "coords_lm")

#' Workflow sets are designed to work with resampling
#' a better way to fit the models will be introduced later
loc_models <- loc_models |>
  mutate(fit = map(info, ~fit(.x$workflow[[1]], training)))

# last_fit() will fit and test the model in one go 

results <- last_fit(lm_wkf, ames_split)

results

# pull workflow using extract_workflow

extract_workflow(results)

collect_metrics(results)

collect_predictions(results)

###### RECIPES AND FEATURE ENGINEERING ########

#' Note that it is best practice to transform outcome
#'  column outside of the recipe

#' Spline Functions 
#' when predictors have non-linear relationships with outcomes, some models
#'   can approx. relationship, but often it makes sense to try and make
#'   a simpler model eg. .linear fit and add specific non-linear features
#'   for the predictors that may need them
#'   
#' do this with spline functions -- which is basically a mini gam

# step_other() will lump together factor levels that are very small

#' Feature extraction 
#' represent multiple features at once
#' 
#' PCA - extracts og info from predictor set using a smaller # of features
#'   linear combination of original predictors
#'   each new feature is uncorrelated from each other 
#'   
#' in this example, there are several predictors that measure 
#'   size of property -- could use PCA to represent vars as smaller set
#' step_pca(matches("(SF$|(Gr_Liv)")) 

#' can specify "ids" for steps for later identification

rec <- 
  recipe(Sale_Price ~ Neighborhood + Gr_Liv_Area + Year_Built + 
           Bldg_Type + Latitude + Longitude,
         data = training) |>
  step_log(Gr_Liv_Area, base = 10) |>
  step_other(Neighborhood, threshold= 0.01, id = "neightidy") |>
  step_dummy(all_nominal_predictors()) |>
  step_interact( ~ Gr_Liv_Area:starts_with("Bldg_Type_")) |>
  step_ns(Latitude, Longitude, deg_free = 20)

#' Row Sampling Steps 
#' 
#' subsampling will change class proportions in data being given to model
#' 
#' downsampling : keeps minority class, takes sample of majority class
#' upsampling: replicate samples from minority class 
#' hybrid: does both 
#' 
#' use themis package to add subsampling steps eg. step_downsample()
#' 
#' note that row-based functions should usually have skip() arg set to TRUE


#' all step functions has an argument called skip() that when TRUE< will
#' be ignored by the predict() function

#' all step functions have a "role" argument to assign roles to the 
#'  results of the step. 

# can call tidy on a recipe
tidy(rec)

# refitting workflow with recipe
new_wkf <- workflow() |>
  add_model(model) |>
  add_recipe(rec) 

wkf_fit <- fit(new_wkf, training)

wkf_fit |>
  extract_recipe(estimated = TRUE) |>
  tidy(id = "neightidy")

wkf_fit |>
  extract_recipe(estimated = TRUE) |>
  tidy(number = 2)

preds <- wkf_fit |>
  predict(testing) |>
  bind_cols(testing |> select(Sale_Price))

preds

#### YARDSTICK #####

#' tidymodels focuses on empirical validation ~ using testing data
#' 
#' yardstick functions have general format of:
#' function(data, truth, ...) where elipses are "prediction" columns

# plot first

ggplot(preds, aes(x=Sale_Price, y = .pred)) +
  theme_bw() +
  # diagonal line
  geom_abline(lty = 2) +
  geom_point(alpha = .5) +
  labs(y = "Predicted Sale Price (log10)", x = "Sale Price (log10)") +
  # uniform scale x y
  coord_obs_pred()

# root mean squared error 
rmse(preds, truth = Sale_Price, estimate = .pred)
# # A tibble: 1 × 3
# .metric .estimator .estimate
# <chr>   <chr>          <dbl>
#   1 rmse    standard      0.0873

# create a metric set to compute multiple metrics at once
ames_metrics <- metric_set(rmse, rsq, mae)
ames_metrics(preds, truth = Sale_Price, estimate = .pred)

# examples of Yardstick for two class examples 
# yardstick functions have standard arg event_level to distinguish
# positive and negative levels -- default is 1st level of outcome factor
# is the event of interest

head(two_class_example) 

conf_mat(two_class_example, truth = truth, estimate = predicted)

classification_metrics <- metric_set(accuracy, mcc, f_meas)
classification_metrics(two_class_example, truth = truth, estimate = predicted)



