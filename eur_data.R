# Get the data

# Read in with tidytuesdayR package 
# Install from CRAN via: install.packages("tidytuesdayR")
# This loads the readme and all the datasets for the week of interest

# Either ISO-8601 date or year/week works!

tuesdata <- tidytuesdayR::tt_load('2020-08-04')
tuesdata <- tidytuesdayR::tt_load(2020, week = 32)

energy_types <- tuesdata$energy_types

# Or read in the data manually

energy_types <- readr::read_csv('https://raw.githubusercontent.com/rfordatascience/tidytuesday/master/data/2020/2020-08-04/energy_types.csv')
country_totals <- readr::read_csv('https://raw.githubusercontent.com/rfordatascience/tidytuesday/master/data/2020/2020-08-04/country_totals.csv')



# Clean the data
library(tidyverse)
library(readxl)
library(countrycode) #remove 00LOCK folder if package fails to install

raw_code <- countrycode::codelist %>% 
    select(country_name = country.name.en, country = eurostat)

raw_excel <- read_excel("Electricity_generation_statistics_2019.xlsx", sheet = 3)
  
raw_excel %>% 
    filter(!is.na(...4)) %>% 
    mutate(country = str_remove_all(...4, "[:digit:]"), .before = ...1) %>% 
    mutate(country = if_else(
      str_length(country) > 1, country, NA_character_), 
      country = str_extract(country, "[:alpha:]+")
      ) %>% 
    fill(country) %>% 
  select(-c(...1, ...2, ...14:...18))


row_stat <- read_excel("Electricity_generation_statistics_2019.xlsx", 
                       sheet = 3,
                       range = "C48:C61", col_names = FALSE)[[1]][c(1,3:14)] %>% 
  str_remove("[:digit:]") %>% 
  str_remove("of which: ") %>% 
  str_remove("\\.") %>% str_trim()

country_range <- tibble(row_start = seq(from = 46, to = 454, by = 34), 
       row_end = seq(from = 61, to = 469, by = 34)) %>% 
  mutate(col1 = 4, col2 = col1 + 5, col3 = col2 + 5) %>% 
  pivot_longer(cols = col1:col3, names_to = "col_var", 
               values_to = "col_start") %>% 
  mutate(col_end = col_start + 2) %>% 
  select(-col_var) %>% 
  slice(-n(), -(n()-1)) %>% 
  mutate(row_stat = list(row_stat))


get_country_stats <- function(row_start, row_end, col_start, col_end, row_stat){
  
  # # pull the row_stat names
  # row_stat <- row_stat

  # create the range programatically
  col_range <- glue::glue("{LETTERS[col_start]}{row_start}:{LETTERS[col_end]}{row_end}")
  
  # read in the data section quietly
  raw_data <- suppressMessages(
    read_excel("Electricity_generation_statistics_2019.xlsx", 
                         sheet = 3,
                         col_names = FALSE,
                         range = col_range))
  
  
  country_data <-  raw_data %>% 
    # set appropriate names
    set_names(nm = c(2016:2018)) %>% 
    # drop the year ranges
    filter(!is.na(`2016`), `2016` != "2016") %>% 
    # get the country into a column rather than a header
    mutate(country = if_else(
      is.na(`2017`), 
      `2016`, 
      NA_character_), 
      .before = `2016`) %>% 
    # fill country down
    fill(country) %>% 
    # drop old country header
    filter(!is.na(`2017`)) %>% 
    # add row stat in
    mutate(type = row_stat, 
           .after = country, 
           # add levels of the stats
           level = c("Total", "Level 1", "Level 1", "Level 1", "Level 2", 
                     "Level 1", "Level 1", "Level 1", "Level 1", "Total", 
                     "Total", "Total", "Total")) %>% 
    # format as double
    mutate(across(c(`2016`:`2018`), as.double))
  
  # return data
  country_data
}

all_countries <- country_range %>% 
  pmap_dfr(get_country_stats) %>% 
  left_join(raw_code, by = "country") %>% 
  select(country, country_name, everything())

country_totals <- all_countries %>% 
  filter(level == "Total")

country_production <- all_countries %>% 
  filter(level != "Total")

# sanity check
country_totals %>% 
  # filter(type == "Total net production") %>% 
  pivot_longer(cols = `2016`:`2018`, names_to = "year", values_to = "value") %>% 
  filter(type == "Total net production") %>%
  # count(type)%>% 
  ggplot(aes(y = value, x = year, color = country, group = country)) +
  geom_line()

write_csv(country_totals, "country_totals.csv")

write_csv(country_production, "energy_types.csv")
