# Import required files
library(stringr)
library(tidyverse)
library(readr)
library(rebus)

# Set the working directory to where the CIF file is stored.
setwd("~/Desktop/Cif Parser Final/atco_cif_data/2010-October/")

# Import the cif files on a line by line bases.
cif_file_raw <- readLines(con = "ATCO_430_Bus.cif")
# Keep only the rows which are important
qb_rows <- cif_file_raw[str_sub(cif_file_raw, 1,2) %in% c("QB", "QL")]


regex4 <- START %R% "QBN" %R% one_or_more(char_class("a-zA-z0-9"))

for (i in 1:length(qb_rows)) {
  string <- qb_rows[i]
  if (str_sub(string,1,3) == "QBN") {
    stop_id <- str_sub(str_extract(string, regex4),1,15)
    coords <- rev(str_extract_all(string, DGT %R% DGT %R% DGT %R% DGT %R% DGT %R% DGT, simplify = T))
    easting <- coords[2]
    northing <- coords[1]
    details <- str_extract(string, pattern = "(?<=\\d\\d\\d\\d\\d\\d  \\d\\d\\d\\d\\d\\d).*$")
    qb_rows[i] <- str_sub(str_pad(str_c(str_pad(stop_id, width = 15, side = "right"), easting, "  ", northing, details), width = 79, side = "right"), 1, 79)
  } else {
    next()
  }
}

regex_1 <- DGT %R% DGT %R% DGT %R% DGT %R% DGT %R% DGT %R% "  " %R% DGT %R% DGT %R% DGT %R% DGT %R% DGT %R% DGT
regex_2 <- DGT %R% DGT %R% DGT %R% DGT %R% DGT %R% DGT

# Determine the extent of the stops and add a margin of 4000. This will be used to subset the stops being added to the end of the naptan file.
qb_easting_min <- min(as.numeric(str_trim(str_extract_all(str_extract_all(qb_rows, regex_1, simplify = T), regex_2, simplify = T)[,1])),na.rm = T) - 4000
qb_easting_max <- max(as.numeric(str_trim(str_extract_all(str_extract_all(qb_rows, regex_1, simplify = T), regex_2, simplify = T)[,1])),na.rm = T) + 4000
qb_northing_min <- min(as.numeric(str_trim(str_extract_all(str_extract_all(qb_rows, regex_1, simplify = T), regex_2, simplify = T)[,2])),na.rm = T) - 4000
qb_northing_max <- max(as.numeric(str_trim(str_extract_all(str_extract_all(qb_rows, regex_1, simplify = T), regex_2, simplify = T)[,2])),na.rm = T) + 4000

# Import the stops table and filter based on the aforemention data extent.
stops_key_data <- read_csv("Stops.csv", na = " ", quoted_na = "") %>% 
  select(ATCOCode, Easting, Northing, CommonName, 
         NptgLocalityCode, Bearing, Indicator, LocalityName, ParentLocalityName) %>% 
  filter(Easting >= qb_easting_min & Easting <= qb_easting_max) %>%
  filter(Northing >= qb_northing_min & Northing <= qb_northing_max)


keep_index <- str_sub(cif_file_raw, 1,2) %in% c("QS", "QO", "QI", "QT")
keep_index[1] = TRUE

cif_file_clean <- cif_file_raw[keep_index]

file_type <- str_pad("ATCO-CIF")
file_date <- str_sub(cif_file_clean[1], start = 61, end = 74)
file_name <- str_sub(cif_file_clean[1], start = 13, 30)
file_originator <- str_sub(cif_file_clean[1], 46, 48)
  
cif_file_clean[1] <- str_replace(cif_file_clean[1], "^CIF", "ATCO-CIF")

# fixes a particular case of a typo. 
cif_file_clean <- str_replace(cif_file_clean, "430G08701  ", "43000870101")

missing_stops <- stops_key_data[(!stops_key_data$ATCOCode %in% (qb_rows %>% str_sub(4,14))),]

missing_stops$CommonName <- stri_enc_toutf8(missing_stops$CommonName)

# Create an empty object to store the output.
output <- c()

# Create the stop reference data to be included at the end of the file. 
# QL and QB are both requried.

for (i in 1:nrow(missing_stops)){
  test_stringa <- str_c("QL",
                        "N", 
                        str_pad(missing_stops$ATCOCode[i], width = 12, "right"),
                        str_sub(str_pad(
                          str_c(
                            stri_enc_toutf8(missing_stops$LocalityName[i]), 
                            " : ", stri_enc_toutf8(missing_stops$Indicator[i]), " ", 
                            stri_enc_tonative(missing_stops$CommonName[i]))
                          , width = 48, "right"), start = 1, end = 48),
                        "B", 
                        missing_stops$NptgLocalityCode[i])
  test_stringb <- str_c("QB", 
                        "N", 
                        str_sub(str_pad(missing_stops$ATCOCode[i], width = 12, "right"), 1,12),
                        str_pad(missing_stops$Easting[i], width = 8, "right"),
                        str_pad(missing_stops$Northing[i], width = 8, "right"),
                        str_pad("", width = 24, "right"),
                        str_pad(str_to_upper(missing_stops$ParentLocalityName[i]), width = 24, "right"))
  
  output <- c(output, test_stringa, test_stringb)
}

# Create a fiel to output the processed CIF file. 
fileConn <- file("ATCO_430_BUS_Processed.CIF")

# Write the new CIF file.
writeLines(c(cif_file_clean, qb_rows, output), fileConn, sep="\n")

# Close the file connection.
close(fileConn)
