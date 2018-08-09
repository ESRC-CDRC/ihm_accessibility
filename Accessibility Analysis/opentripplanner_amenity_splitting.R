# Script to split amenity data into single tables.

# All required libraries are within the tidyverse
library(tidyverse)

# which year are the dataa for? this si used to select table and specify file names.
year <- 2012

# Import the full origin destination table for the given year.
od_raw <- read_csv(str_c("~/Desktop/Yearly_oa_dest_combos/oa_dest_combos_", year,".csv"))

# Create an empty directory to record the split tables.
dir.create(str_c("~/Desktop/OD_", year))

# First table contains unique origin data.
od_raw %>%
  select(oa11cd, oa_lat, oa_lon) %>%
  distinct() %>% 
  write_csv(str_c("~/Desktop/OD_", year, "/_OA", year, "_origs.csv" ))

# loop through each OA code and create the sub table.
for (oa in unique(od_raw$oa11cd)) {
  od_raw[od_raw$oa11cd == oa,] %>%
    write_csv(str_c("~/Desktop/OD_", year, "/OA", year, "_", oa, "_dests.csv"))
}

# For uploading to the server, it is best that these files be zipped and then unzipped on the server.
