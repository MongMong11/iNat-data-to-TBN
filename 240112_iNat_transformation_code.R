#### 1. initialization ####

#path
setwd("D:/Mong Chen/240110_iNat to OP")

#package
library(data.table)
library(dplyr)
library(parallel)
library(sf)
library(raster)
library(stringr)

#iNat
f_iNat <- "20231231_iNat_Taiwan_all.csv"
iNat_table <- fread(f_iNat,encoding = "UTF-8", colClasses = "character")

#### 2. data transformation ####

#only research grade
iNat_research_grade<-iNat_table %>% filter(quality_grade=="research")

#transformation
iNat_table <- iNat_research_grade %>%
  
  #as.data.table
  setDT() %>%
  
  #select
  .[, list(id, observed_on, positional_accuracy,
           captive_cultivated, coordinates_obscured, scientific_name,
           common_name, url, user_login,
           geoprivacy, private_latitude, latitude,
           private_longitude, longitude)] %>%
  
  #dwcID
  setnames(., "id", "dwcID") %>%
  
  #catalogNumber
  .[, catalogNumber := dwcID] %>%
  
  #year; month; day
  .[, year := substring(observed_on, 1, 4)] %>%
  .[, month := substring(observed_on, 6, 7)] %>%
  .[, day := substring(observed_on, 9, 10)] %>%
  
  #coordinateUncertaintyInMeters
  setnames(., "positional_accuracy", "coordinateUncertaintyInMeters") %>%
  
  #establishmentMeans
  .[, establishmentMeans := ifelse(captive_cultivated=="t", "圈養/栽植", "野生")] %>%
  
  #dataSensitiveCategory
  .[, dataSensitiveCategory := ifelse(coordinates_obscured=="t", "重度", "")] %>%
  
  #originalVernacularName
  .[, originalVernacularName := ifelse(scientific_name != "", scientific_name, common_name)] %>% 
  
  #basicOfrecord
  .[, basisOfRecord := "人為觀測"] %>%
  
  #source
  setnames(., "url", "source") %>%
  
  #record by
  setnames(., "user_login", "recordedBy") %>%
  
  #license
  
  #decimalLatitude
  .[, decimalLatitude := ifelse(geoprivacy=="private"|private_latitude != "", private_latitude, latitude)] %>%
  #decimalLongitude
  .[, decimalLongitude := ifelse(geoprivacy=="private"|private_longitude != "", private_longitude, longitude)] %>%
  
  #delete columns
  .[, c("observed_on", "captive_cultivated", "coordinates_obscured") := NULL] %>%
  .[, c("scientific_name", "common_name", "geoprivacy") := NULL] %>%
  .[, c("private_latitude", "latitude", "private_longitude", "longitude") := NULL]


#### 3. catch county, Municipality, minimumElevationInMeters ####

#iNat data without location
iNat_locNA <- subset(iNat_table, iNat_table$decimalLatitude=="")
iNat_locNA$county <- ""
iNat_locNA$municipality <- ""
iNat_locNA$minimumElevationInMeters <- ""

#iNatdata with location
iNat_loc<- subset(iNat_table, iNat_table$decimalLatitude != "")

iNat_loc <- iNat_loc %>%
  setDT() %>%
  .[, file_ID := rep(1:ceiling(nrow(.)/250000), each=250000, length.out=nrow(.))] %>%
  .[, decimalLongitude := as.numeric(decimalLongitude)] %>%
  .[, decimalLatitude := as.numeric(decimalLatitude)] 


iNat_loc_table <- iNat_loc %>% 
  dplyr::select(file_ID, dwcID, decimalLatitude, decimalLongitude) %>% 
  .[!duplicated(.[ , c("dwcID","decimalLatitude", "decimalLongitude")]), ]

iNat_loc_list <- iNat_loc_table %>% split(., .$file_ID)

#catchlocation function
catchlocation <- function(x){
  x %>%
    st_as_sf(coords = c("decimalLongitude", "decimalLatitude"), remove=FALSE) %>% # set coordinates
    st_set_crs(4326) %>%  # table transform to polygon
    st_join(., town, join = st_intersects, left = TRUE, largest=TRUE) %>% 
    st_drop_geometry(.)
}

#parallel
cpu.cores <- detectCores()
cl <- makeCluster(cpu.cores-1)
clusterEvalQ(cl, { # make sure all clusters are ready
  library(tidyverse)
  library(data.table)
  library(sf)
  town <- st_read("polygon/Taiwanlandsea_TownCounty/Taiwanlandsea_TownCounty.shp")
  town<- as(town, "sf")%>%
    st_set_crs(4326)
  sf_use_s2(FALSE)
}
)

system.time(
  inat_loc_final<- parLapply(cl, iNat_loc_list, catchlocation)%>% 
    do.call(rbind,.)
)
stopCluster(cl)

names(inat_loc_final)[names(inat_loc_final) == 'COUNTYNAME'] <- "county"
names(inat_loc_final)[names(inat_loc_final) == 'TOWNNAME'] <- "municipality"

# add minimumElevationInMeters
elevation_raster <- raster("polygon/twdtm_asterV3_30m/twdtm_asterV3_30m.tif")

inat_loc_final<- inat_loc_final %>%
  setDT() %>%
  .[,decimalLongitude := as.numeric(decimalLongitude)] %>%
  .[,decimalLatitude := as.numeric(decimalLatitude)] %>%
  .[, minimumElevationInMeters := extract(elevation_raster, .[,c("decimalLongitude", "decimalLatitude")])]

catch_table<- inat_loc_final[,.(dwcID,county,municipality,minimumElevationInMeters)]
iNat_loc <- subset(iNat_loc, select = -c(county,municipality,minimumElevationInMeters))

iNat_loc_result <- merge(iNat_loc, catch_table, by="dwcID")
iNat_loc_result <- subset(iNat_loc_result, select = -c(file_ID))
iNat_dataset_result<- rbind(iNat_loc_result, iNat_locNA)

iNat_dataset_result<-iNat_dataset_result %>%
  .[, county := str_replace(county,'臺','台')] %>%
  .[, municipality := ifelse(is.na(municipality), "", municipality)]


#minimumElevationInMeters cleaning
all.data<-iNat_dataset_result %>%
  .[, coordinateUncertaintyInMeters := as.numeric(coordinateUncertaintyInMeters)] %>%
  .[, minimumElevationInMeters := ifelse(!is.na(coordinateUncertaintyInMeters)&coordinateUncertaintyInMeters<5000, minimumElevationInMeters, "")]

#issue

  all.data<-all.data %>%
  mutate(issue = case_when(
    county != "" &  minimumElevationInMeters != "" ~ "County and Municipality derived from coordinates by TBN; minimumElevationInMeters derived from coordinates by TBN",
    county != "" &  minimumElevationInMeters == "" ~ "County and Municipality derived from coordinates by TBN",
    county == "" &  minimumElevationInMeters != "" ~ "minimumElevationInMeters derived from coordinates by TBN",
    TRUE ~ ""
  ))

#remove captive_cultivated
all.data<-all.data[establishmentMeans=="野生"]

#select licence = CC0 ; CC-BY; CC-BY-NC & time blur
all.data<-all.data %>%
  setDT() %>%
  .[license %in% c("CC-BY-NC", "CC-BY", "CC0")] %>%
  .[, month := ifelse(dataSensitiveCategory=="重度", "", month)] %>%
  .[, day := ifelse(dataSensitiveCategory=="重度", "", day)]

#### 4. save final file ####

iNat_split<- all.data %>% split(., rep(1:ceiling(nrow(.)/250000), each=250000, length.out=nrow(.)))

dir.create("result")

for (i in 1:ceiling(nrow(all.data)/250000)) {
  table<-setDT(iNat_split[[i]])
  fwrite(table, sprintf("result/iNat_split_%s.csv", i))
}
