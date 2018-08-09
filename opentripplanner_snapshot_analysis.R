

# Import required libraries for analysis
library(tidyverse)
library(rebus)
library(ggjoy)
library(ggthemes)
library(sf)
library(scales)
library(htmltools)

# Goal of this sript is to explore wheather there has been a decline in journey 
# times between output areas and key amenities over time. 

peak_hours <- c("0630", "0700", "0730", "0800", "0830", "0900", "1600", "1630", 
                "1700", "1730", "1800", "1830", "1900")

# Function to import timetable OTP snapshots. 
read_function <- . %>% read_csv(., col_types = "ccccccc") %>% 
  transmute(origin, type, travel_time) %>% 
  mutate(type = str_replace(
    type, START %R% DGT %R% DGT %R% DGT %R% DGT %R% "_", "")) %>%
  mutate(type = str_replace(type, 
                            zero_or_more("_" %R% DGT %R% DGT %R% DGT %R% DGT) %R% "_"
                            %R% DGT %R% DGT %R% DGT %R% DGT %R% END, "")) %>%
  group_by(type, origin) %>%
  summarise(travel_time = min(travel_time))


# This is currently specific to Weekdays. We need to consider how we
# will deal with weekends. Individuals or collectivly.

files_raw <- list.files("~/Desktop/Timetable_snapshots/", full.names = T)

# Creation of lookup table. File names contain dates and times.
files <- data_frame(file = files_raw,
                    source = as.character(1:length(files_raw)), 
                    date = str_sub(files_raw, 62, 67),
                    time = str_sub(files_raw, 69, 72))

# Using the map function import all data
tt_files <- map_df(files$file, read_function,.id = "source")

# Basedo on source, assign dates and time to the timetable snapshots.
tt_files <- tt_files %>% left_join(files[,c(2:4)], by = "source")

# Exploratory plot. Relationship between date, travel time and amenity type.
tt_files %>% 
  ggplot(aes(x = date, y = travel_time, color = type, group = origin)) +
  geom_path(alpha = 0.1) + 
  facet_grid(time~type) 


tt_data_spread <- tt_files %>%  
  group_by(date, time, type) %>%
  summarise(mean_travel_time = mean(travel_time)) %>% 
  spread(date, mean_travel_time)


# Percentage change plot between first year (2013) and subsequent  --------

tt_data_spread_perc_change <- tt_data_spread

for (i in 4:6) {
  tt_data_spread_perc_change[,i] = (tt_data_spread_perc_change[,i] - 
                                      tt_data_spread_perc_change[,3]) / 
    tt_data_spread_perc_change[,3] * 100
}

tt_data_spread_perc_change[,3] <- 0 

change_plot_1 <- 
  tt_data_spread_perc_change %>%
  filter(is.na(type) == F) %>%
  group_by(type) %>%
  gather(measure, value, -type, -time) %>% 
  ggplot(aes(x = measure, y = value, colour = time, group = str_c(type, time))) +
  geom_hline(aes(yintercept = 0), colour = "white") +
  geom_path() +
  ylim(c(0,10)) +
  facet_wrap(~type) +
  labs(x = "Year",
       y = "% Change Since 2013",
       title = "% Change in Transit Time Since 2013") +
  theme_dark()

ggsave(plot = change_plot_1, filename = "transit_time_vs_2013_time.png", 
       units = "cm", width = 25, height = 12.5, scale = 1.5)


# Verson 2, here we differentiate sequences by whether or not ehy occur during 
# peak times.
change_plot_2 <- 
  tt_data_spread_perc_change %>%
  filter(is.na(type) == F) %>%
  group_by(type) %>%
  mutate(peak = ifelse(time %in% peak_hours, "Peak", "Offpeak")) %>%
  gather(measure, value, -type, -time, -peak) %>% 
  ggplot(aes(x = measure, y = value, colour = peak, group = str_c(type, time))) +
  geom_hline(aes(yintercept = 0), colour = "white") +
  geom_path(alpha = 0.5) +
  ylim(c(0,10)) +
  scale_color_manual(name = "Peak Times", values = c("#ff7f00", "#4daf4a")) +
  facet_wrap(~type) +
  labs(x = "Date",
       y = "% Change Since 2013",
       title = "% Change in Transit Time Since 2013") +
  theme_dark()

ggsave(plot = change_plot_2, filename = "transit_time_vs_2013_peak.png", units = "cm",
       width = 25, height = 12.5, scale = 1.5)


# Percentage change rolling -----------------------------------------------

tt_data_spread_perc_change2 <- tt_data_spread

for (i in 4:6) {
  tt_data_spread_perc_change2[,i]  =   (tt_data_spread[,i] - tt_data_spread[,(i - 1)]) /
    tt_data_spread[,(i - 1)] * 100
}

tt_data_spread_perc_change2[,3] <- 0 

tt_data_spread_perc_change2 %>% 
  gather(measure, value, -time, -type) %>% 
  ggplot(aes(x = measure, y = value, colour = time, group = str_c(type, time))) +
  geom_hline(aes(yintercept = 0), colour = "white") +
  geom_path() +
  facet_wrap(~type) +
  theme_dark() 

write.csv()

# Creation of Accessibility Map Data --------------------------------------

# Here, the objective is to create a dataframe with the appropirate formatting to
# to be displayed on CDRC Maps. 

# Format should be:
# oallcd, <year_amenity>,<year_amenity_2_years_change>

tt_files <- tt_files %>% mutate(travel_time = as.numeric(travel_time))

# Step 1: 

tt_files_s1 <- 
  tt_files %>% 
  ungroup() %>%
  transmute(origin, `type`, date, `time`, travel_time) %>% 
  spread(`date`, travel_time)

# Step 2: Observed change over n years

# Needs to be undated if nore years are added.
tt_files_s2 <- tt_files_s1 %>% 
  mutate(`141007_change` = (`141007` - `131008`)/`131008` * 100,
         `151006_change` = (`151006` - `141007`)/`141007` * 100,
         `161011_change` = (`161011` - `151006`)/`151006` * 100) 

# as an initial estimate of daily acacessibility, calculate mean
# to read each destination.
tt_files_s2_out <- tt_files_s2 %>% 
  group_by(origin, type) %>%
  summarise_at(c("131008", "141007", "151006", "161011", 
                 "141007_change", "151006_change", "161011_change"), 
               mean, na.rm = T)

# quick map output
st_read("spatial_data/wm_oa_simp.shp") %>%
  left_join(tt_files_s2_out %>% filter(type == "clinic"), by = c("oa11cd" = "origin")) %>% 
  ggplot(aes(fill = `141007_change`)) + 
  scale_fill_distiller(limits = c(-10, 10), type = "div", palette = "RdYlBu", oob = squish) +
  geom_sf(size = 0) +
  theme_map()


# Step 3: Composite measure of accessibility

# mean of all travel times across the day.
tt_files_s3_out <- 
  tt_files %>% 
  group_by(origin, date) %>% 
  summarise(mean_travel_time = mean(travel_time)) %>%
  spread(date, mean_travel_time) %>%
  mutate(`141007_change` = (`141007` - `131008`)/`131008` * 100,
         `151006_change` = (`151006` - `141007`)/`141007` * 100,
         `161011_change` = (`161011` - `151006`)/`151006` * 100) %>% 
  ungroup() 

# Boxplot showing year on year change.
tt_files_s3_out %>% 
  select(origin, contains("change")) %>% 
  gather(change, value, -origin) %>% data.frame %>% 
  ggplot(aes(change, value)) +
  geom_point(position = "jitter", alpha = 0.03) +
  geom_boxplot(notch = T)
  

library(leaflet)



bins <- c(0,600,1200, 1800, 2400, 3000, 3600, Inf)
pal <- colorBin(palette = "YlOrRd", domain = tt_files_s3_out$`131008`, bins = bins, pretty = T)


wm_oas <- st_read("spatial_data/wm_oa.shp")

leaflet_map_data <- tt_files_s3_out %>%
  left_join(wm_oas %>% select(oa11cd), by = c("origin" = "oa11cd")) %>%
  st_as_sf() %>% 
  st_transform(4326)


labels <- str_c("<strong>OA ", tt_files_s3_out$origin , "</strong><br/> 
      2013: ", round(tt_files_s3_out$`131008`), "<br/>
      2014: ", round(tt_files_s3_out$`141007`), "<br>
      2015: ", round(tt_files_s3_out$`151006`), "<br>
      2016: ", round(tt_files_s3_out$`161011`)) %>% 
  lapply(htmltools::HTML)




leaflet_map <- leaflet() %>% 
  addTiles() %>%
  addPolygons(data = leaflet_map_data,
              color = "#444444", 
              weight = 1,
              smoothFactor = 0.5,
              opacity = 1.0, 
              fillOpacity = 1,
              fillColor = ~pal(`131008`),
              highlightOptions = highlightOptions(color = "white", weight = 2,
                                                  bringToFront = TRUE),
              group = "2013",
              popup = ~htmlEscape(origin),
              label = labels) %>%
  addPolygons(data = leaflet_map_data,
              color = "#444444", 
              weight = 1,
              smoothFactor = 0.5,
              opacity = 1.0, 
              fillOpacity = 1,
              fillColor = ~pal(`141007`),
              highlightOptions = highlightOptions(color = "white", weight = 2,
                                                  bringToFront = TRUE),
              group = "2014",
              popup = ~htmlEscape(origin),
              label = labels) %>%
  addPolygons(data = leaflet_map_data,
              color = "#444444", 
              weight = 1,
              smoothFactor = 0.5,
              opacity = 1.0, 
              fillOpacity = 1,
              fillColor = ~pal(`151006`),
              highlightOptions = highlightOptions(color = "white", weight = 2,
                                                  bringToFront = TRUE),
              group = "2015",
              popup = ~htmlEscape(origin),
              label = labels) %>%
  addPolygons(data = leaflet_map_data,
              color = "#444444", 
              weight = 1,
              smoothFactor = 0.5,
              opacity = 1.0, 
              fillOpacity = 1,
              fillColor = ~pal(`161011`),
              highlightOptions = highlightOptions(color = "white", weight = 2,
                                                  bringToFront = TRUE),
              group = "2016",
              popup = ~htmlEscape(origin),
              label = labels) %>%
  # Layers control
  addLayersControl(
    baseGroups = c("2013", "2014", "2015", "2016"),
    options = layersControlOptions(collapsed = FALSE)
  ) %>% 
  addLegend("bottomright", 
            pal = pal,
            values = leaflet_map_data$`131008`,
            title = "Travel Time",
            labFormat = labelFormat(suffix = "s"),
            opacity = 1
  )

# Export the accesibility leaflet map. This can be opened in chrome or another browser.
saveWidget(leaflet_map, "Accessability_leaflet_map.html", selfcontained = F)
