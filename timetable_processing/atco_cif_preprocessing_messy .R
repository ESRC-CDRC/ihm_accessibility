

library(stringr)
library(tidyverse)
library(readr)
library(rebus)


setwd("~/Desktop/Cif Parser Final/atco_cif_data/2012-August/")

files <- list.files(pattern = ".cif")
result <- readLines(con = files[1])

for (i in 2:length(files)) {
  if (i %% 10 == 0) print(i)
  holder <- readLines(con = files[i])
  holder <- holder[2:length(holder)]
  result <- c(result, holder)
}

head(result)
tail(result)

cif_file_raw <- result
qb_keep <- str_sub(cif_file_raw, 1,2) %in% c("QB", "QL")
qb_rows <- cif_file_raw[qb_keep]
qb_rows <- qb_rows %>% unique


regex_1 <- " " %R% DGT %R% DGT %R% DGT %R% DGT %R% DGT %R% DGT %R% or(" ", "")
regex_1 <- " " %R% DGT %R% DGT %R% DGT %R% DGT %R% DGT %R% DGT %R% or(" ", "")

qb_easting_min <- min(as.numeric(str_trim(str_extract_all(qb_rows, regex_1, simplify = T)[,1])),na.rm = T) - 4000
qb_easting_max <- max(as.numeric(str_trim(str_extract_all(qb_rows, regex_1, simplify = T)[,1])),na.rm = T) + 4000
qb_northing_min <- min(as.numeric(str_trim(str_extract_all(qb_rows, regex_1, simplify = T)[,2])),na.rm = T) - 4000
qb_northing_max <- max(as.numeric(str_trim(str_extract_all(qb_rows, regex_1, simplify = T)[,2])),na.rm = T) + 4000

stops_key_data <- 
  read_csv("../../Stops.csv", na = " ", quoted_na = "") %>% 
  select(ATCOCode, Easting, Northing, CommonName, 
         NptgLocalityCode, Bearing, Indicator, LocalityName, ParentLocalityName) %>% 
  filter(Easting >= qb_easting_min & Easting <= qb_easting_max) %>%
  filter(Northing >= qb_northing_min & Northing <= qb_northing_max)


keep_index <- str_sub(cif_file_raw, 1,2) %in% c("QS", "QO", "QI", "QT", "QL", "QB")
keep_index[1] = TRUE
cif_file_clean <- cif_file_raw[keep_index]
cif_file_clean[1] <- str_replace(cif_file_clean[1], "^CIF", "ATCO-CIF")

cif_file_clean <- str_replace(cif_file_clean, "430G08701  ", "43000870101")

cif_file_clean <- cif_file_clean %>% unique

missing_stops <- stops_key_data[(!stops_key_data$ATCOCode %in% (qb_rows %>% str_sub(4,14))),]

missing_stops$CommonName <- stri_enc_toutf8(missing_stops$CommonName)

output <- c()

head(cif_file_clean)

for (i in 1:nrow(missing_stops)){
  
  test_stringa <- str_c("QL",
                        "N", 
                        str_pad(missing_stops$ATCOCode[i], width = 12, "right"),
                        str_sub(str_pad(
                          str_c(
                            stri_enc_toutf8(missing_stops$LocalityName[i]), 
                            " : ", stri_enc_toutf8(missing_stops$Indicator[i]), " ", stri_enc_tonative(missing_stops$CommonName[i]))
                          , width = 48, "right"), start = 1, end = 48),
                        "B", 
                        missing_stops$NptgLocalityCode[i])
  
  test_stringb <- str_c("QB", 
                        "N", 
                        str_pad(missing_stops$ATCOCode[i], width = 12, "right"),
                        str_pad(missing_stops$Easting[i], width = 8, "right"),
                        str_pad(missing_stops$Northing[i], width = 8, "right"),
                        str_pad("", width = 24, "right"),
                        str_pad(str_to_upper(missing_stops$ParentLocalityName[i]), width = 24, "right"))
  
  output <- c(output, test_stringa, test_stringb)
  
}

cif_file_clean %>% head
cif_file_clean %>% tail
output %>% head()
output %>% tail()

fileConn <- file("ATCO_430_BUS_Processed.CIF")
writeLines(c(cif_file_clean, output), fileConn, sep="\n")
close(fileConn)
