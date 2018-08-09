# Code to transfer asset tracker data from raw files into a single table.

library(readxl)    
library(stringr)
library(plyr)
library(dplyr)

# Set the working directory where the asset tracker data is held.
setwd("~/Desktop/Asset Tracker/")

# Create function for reading in all sheets from excel workbook
read_excel_allsheets <- function(filename) {
  sheets <- readxl::excel_sheets(filename)
  x <-    lapply(sheets, function(X) readxl::read_excel(filename, sheet = X))
  names(x) <- sheets
  x
}

# list all files with the working directory.
file_list <- list.files(pattern = ".xlsm")
# Check that the file names are legitmate
file_list <- edit(file_list)

#Create a list to store dataframe for each worbook
finaldataframes <- list()


j=1 # set counter
for(file in file_list){ # loop through each file
  mysheets <- read_excel_allsheets(file) # read in workbook
  
  names <- names(mysheets)[!grepl(1.6, names(mysheets))] # remove any sheets with 1.6 in name.
  
  dataframes <- list() # empty list to compile each sheets dataframe
  
  for(i in 1:length(names)){ # Loop through each sheet
    data <- mysheets[[names[i]]] # Select each sheet in turn
    data <- data[,c(1:9)] %>% select(1,2,3,6,7) # select required columns
    date <- str_sub(names[i],1,10) # substring the names to remove 
    dataframes[[i]] <- cbind(date, data) # cbind to add date to each row based on sheet name
  }
  
  final <- data.table::rbindlist(dataframes) # combine each sheets dataframe from current workbook
  finaldataframes[[j]] <- final # write the full worbook dataframe into main list.
  
  write.csv(final, paste0("file", j, ".csv"), row.names=F) # write constituent dataframe to csv.
  j=j+1 # Increment the counter.
}

# combine each workbooks full dataframe into one table.
finaldataframe <- data.table::rbindlist(finaldataframes)

# Write out the final file.
finaldataframe %>% write.csv("AssetTracker_2013-2017.csv", row.names=F)

library(sf)
library(ggmap)

lsoa_wm <- st_read("~/Downloads/E47000007/shapefiles/E47000007.shp")

plot(lsoa_wm$geometry)

plot(lsoa_wm)

geom_sf()

ggplot(lsoa_wm) +
  geom_sf(aes(fill = AREA))







