library(nycflights13) #for flight data
library(tidymodels) #primarily for recipes package
library(skimr) #for variable summaries
library(lubridate) #for converting from date-time to date

#goal: predicting whether a plane arrives more than 30 minutes late

#making initial changes to data
flights_data <-
  nycflights13::flights |>
  #using mutate() to add new columns that are functions of prior ones
  mutate(
    #convert arrival delay to a factor
    #ifelse(condition, yes, no)
    arr_delay = ifelse(arr_delay >= 30, "late", "on_time"),
    #using factor() to transform the arr_delay vector into a factor
    arr_delay = factor(arr_delay),
    #converting date-time to just date
    date = lubridate::as_date(time_hour)
  ) |>
  #adding on weather data
  #inner_join adds rows from y to x based on if "key values" match 
  #in this case, weather data is matched to the departure origin/date
  dplyr::inner_join(nycflights13::weather, by=c("origin", "time_hour")) |>
  #only retain needed columns
  select(dep_time, flight, origin, dest, air_time, distance, carrier, 
         date, arr_delay, time_hour) |>
  #exclude missing data 
  na.omit() |>
  #when creating models, better to have qualitative be factors, not strings
  dplyr::mutate_if(is.character, as.factor)

#counting the number of data sets arriving late
flights_data |>
  count(arr_delay) |>
  #count creates a tbl where the number of each occurence is titled n
  mutate(prop = n/sum(n))

# # A tibble: 2 × 3
# arr_delay      n  prop
# <fct>      <int> <dbl>
# 1 late       52540 0.161
# 2 on_time   273279 0.839

#Note that 16% of flights were more than 30 minutes late








