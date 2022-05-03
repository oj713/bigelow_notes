library(tidymodels)
library(modeldata)
library(ggrepel)

# Setup code: ames, ames_folds lm_model, training, testing, control,
#  rf_resamples
if (TRUE) {
  data(ames)
  
  # log scaling outcome factor (want to do this outside of recipe!)
  ames <- ames |>
    mutate(Sale_Price = log10(Sale_Price))
  
  # training/testing splits
  set.seed(137)
  ames_split <- initial_split(ames, prop = 3/4, strata = Sale_Price)
  training <- training(ames_split)
  testing <- testing(ames_split)
  
  ames_folds <- vfold_cv(training, v = 5, repeats = 2)
  set.seed(NULL)
  
  #initializing a linear regression model 
  lm_model <- linear_reg() |> 
    set_engine("lm")
  
  # setting controls for resampling
  control <- control_resamples(save_pred = TRUE, save_workflow = TRUE) 
  
  # creating resampled workflow for rf
  rf_resamples <- workflow() |>
    add_formula(Sale_Price ~ Neighborhood + Gr_Liv_Area + Year_Built +
                  Bldg_Type + Latitude + Longitude) |>
    add_model(rand_forest(trees = 1000, 
                          engine = "ranger", 
                          mode = "regression")) |>
    fit_resamples(resamples = ames_folds, control = control)
}

##################

#' Sometimes we would like to evaluate how different preprocessing steps
#'   affect the model results. We can create these recipes incrementally,
#'   and then combine them into a workflow set 

# defining the three recipe options 
if (TRUE) {
  basic_rec <- recipe(Sale_Price ~ Neighborhood + Gr_Liv_Area +  
                        Year_Built + Bldg_Type + Latitude + Longitude, 
                      data = training) |>
    step_log(Gr_Liv_Area, base = 10) |>
    step_other(Neighborhood, threshold = 0.01) |>
    step_dummy(all_nominal_predictors())
  
  interaction_rec <- basic_rec |>
    # remember that the Bldg_Type has been converted to dummy variables
    step_interact( ~ Gr_Liv_Area:starts_with("Bldg_Type_")) 
  
  spline_rec <- interaction_rec |>
    step_ns(Latitude, Longitude, deg_free = 50)
} 

# creating a list of all the recipe options 
rec_list <- list(basic = basic_rec, 
                 interaction = interaction_rec, 
                 splines = spline_rec)

# creating workflow set 
workflows <- workflow_set(preproc = rec_list, 
                          models = list(lm = lm_model),
                          cross = FALSE)

# resampling each model using workflow_map 
workflows <- workflows |>
  workflow_map("fit_resamples",
               # options to workflow_map()
               seed = 120, verbose = TRUE,
               # options to fit_resamples()
               resamples = ames_folds, control = control)

#' the options columns includes the options to fit_resamples that were given
#'   - for reproducibility - and results column contains results
workflows

collect_metrics(workflows) |>
  filter(.metric == "rmse")

#' binding the random forest resamples - not that this requires that 
#'   save_workflow = TRUE was set in the control function

four_models <- 
  as_workflow_set(random_forest = rf_resamples) |>
  bind_rows(workflows)

four_models

# use autoplot to show confidence intervals for each model for a metric

autoplot(four_models, metric = "rsq") +
  geom_text_repel(aes(label = wflow_id), nudge_x = 1/9, nudge_y = 1/150) +
  theme(legend.position = "none")

#' based on plot, we can see that random forest does the best job and there are
#'   small improvements to linear models as we add more recipe steps

#####################

#' Although the difference n performance btwn the workflows with additional 
#'   steps is small, it might be statistically significant. We can formally
#'   test the hypothesis that the additional terms increase R^2

#' We would like to determine the resample-to-resample component of variation
#'  focusing on R^2

rsq_ind_est <- collect_metrics(four_models, summarize = FALSE) |>
  filter(.metric == "rsq") |>
  mutate(new_id = paste(id, id2))

# reshaping results
rsq_wider <- rsq_ind_est |>
  select(wflow_id, .estimate, new_id) |>
  # increases columns and decreases rows 
  pivot_wider(id_cols = "new_id", 
              names_from = "wflow_id", 
              values_from = ".estimate")

corrr::correlate(rsq_wider |> select(-new_id), quiet = TRUE)

#' High correlations show that there are large within-resample correlations
#'   Visual representation below - R^2 for each model with line 
#'     connecting resample  - if there is no resample-to-resample effect there
#'     would be no parallel lines

rsq_ind_est |>
  mutate(wflow_id = reorder(wflow_id, .estimate)) |>
  ggplot(aes(x = wflow_id, y = .estimate, group = new_id, color = new_id)) +
  geom_line(alpha = .5, lwd = 1.25) +
  theme(legend.position = "none")

# can perform statistical test for correlations to determine if its noise
rsq_wider |>
  with(cor.test(basic_lm, splines_lm)) |>
  tidy() |>
  select(estimate, starts_with("conf"))

#' results - estimate of correlation + confidence interval - shows that 
#'   within-resample correlation is real 

# Variance of difference of two variables
# Var[X - Y] = Var[X] + Var[Y] -2Cov[X,Y]

#' if the two variables are sig. positively correlated, then any statistical 
#'   test of difference would bias the model comparison towards finding no 
#'   difference

#' Practical effect size -- a realistic "difference that matters"
#'   eg. maybe we consider two models to not be practically different if 
#'   R^2 are within +- 2%, even if they are statistically significant differences

#' Using an ANOVA to evaluate difference 

compare_lm <-
  rsq_wider |>
  mutate(difference = splines_lm - basic_lm)

lm(difference ~ 1, data = compare_lm) |>
  tidy(conf.int = TRUE) |>
  select(estimate, p.value, starts_with("conf"))

# this shows that there is not a significant difference 
#' A posterior probability, in Bayesian statistics, is the revised or updated 
#'   probability of an event occurring after taking into 
#'   consideration new information.

# could also use Bayesian modeling 
library(tidyposterior)
library(rstanarm)

# perf_mod() determines an appropriate bayesian model and fits it 
# with resampling statistics 
rsq_anova <-
  tidyposterior::perf_mod(four_models,
                          metric = "rsq",
                          # specifying distribution of intercepts
                          # t distribution
                          prior_intercept = rstanarm::student_t(df = 1),
                          chains = 4,
                          # how long to run each iteration
                          iter = 5000,
                          seed = 1102)

model_post <- rsq_anova |>
  # extracts posterior distributions into a tibble
  tidy(seed = 118) |>
  glimpse()

#plotting
# These histograms describe the estimated probability distributions 
# of the mean R2 value for each model.
model_post |>
  mutate(model = forcats::fct_inorder(model)) |>
  ggplot(aes(x = posterior)) + 
  geom_histogram(bins = 50, color = "white", fill = "blue", alpha = 0.4) + 
  facet_wrap(~ model, ncol = 1)

# alternative way of showing the same data 
autoplot(rsq_anova) +
  geom_text_repel(aes(label = workflow), nudge_x = 1/8, nudge_y = 1/100) +
  theme(legend.position = "none")

# the nice part about bayesian models is that once we've computed it, 
# it's easy to compare individual models

rqs_diff <-
  tidyposterior::contrast_models(rsq_anova,
                                 list_1 = "splines_lm",
                                 list_2 = "basic_lm",
                                 seed = 1104)

# plotting shows that the distribution significantly overlaps with 0
rqs_diff |> 
  as_tibble() |>
  ggplot(aes(x = difference)) + 
  geom_vline(xintercept = 0, lty = 2) + 
  geom_histogram(bins = 50, color = "white", fill = "red", alpha = 0.4)

# use summary() to compute the mean of the distribution as well as 
#   credible intervals 
summary(rqs_diff) |>
  select(-starts_with("pract"))

# the "probability" column is the % that is over 0 -- therefore closer to 1 
# means its more likely there's a significant difference

# if we have a "practical effect size" we can also see the probability that
#  its over that... pract_equiv closer to 1 means its more likely that they are
#  the same according to PES
summary(rqs_diff, size = 0.02) %>% 
  select(contrast, starts_with("pract"))

# use autoplot() with a workflow set to compare each workflow to the "best" one
# this shows that the lm values are not practically the same as the random forest
autoplot(rsq_anova, type = "ROPE", size = 0.02) +
  geom_text_repel(aes(label = workflow)) +
  theme(legend.position = "none")

#' note that a higher number of resamples has a diminishing effect on 
#'   confidence interval -- so go high, but not too high




