# iNat_data_to_TBN

### iNaturalist對應TBN填入資料欄位

| iNat 原始欄位名稱 | TBN 欄位名稱 | Note |
| -------- | -------- | -------- |
| quality_grade || 僅使用"research"紀錄 |
| id | dwcID ||
| observed_on_string |||
| observed_on |  year; month; day |若dataSensitiveCategory為"t"，month和day將不填入數值，以做時間模糊化|
| time_observed_at |||
| created_at |||
| updated_at |||
| captive_cultivated | establishmentMeans | [2024/1/19] 僅篩選 "f"(野生) 上傳|
| positional_accuracy | coordinateUncertaintyInMeters ||
|latitude|||
|longitude|||
|public_positional_accuracy|||
|private_latitude|||
|private_longitude|||
|geoprivacy|||
|coordinates_obscured|dataSensitiveCategory|若coordinates_obscured為"t"，dataSensitiveCategory填入"重度"；若f，填入空值|
|scientific_name|||
|common_name|||
|taxon_id|||
|taxon_geoprivacy|||
||originalVernacularName|若scientific_name有字串，則填入scientific_name; 反之若scientific_name為空值，則填入common_name|
||county|由decimalLatitude及decimalLongitude計算之衍生欄位，使用政府資料開放平台「臺灣縣市和鄉鎮區界線圖層」（原始資料來源：[直轄市、縣市界線](https://data.gov.tw/dataset/32158)、[鄉鎮市區界線](https://data.gov.tw/dataset/32157)），與海洋保育署「海洋行政區範圍圖層」（原始資料來源:[海洋保育地理資訊圖台](https://iocean.oca.gov.tw/iOceanMap/map.aspx)）進行套疊，再根據經緯度座標抓取縣市資料。|	
||municipality|由decimalLatitude及decimalLongitude計算之衍生欄位，使用政府資料開放平台「臺灣縣市和鄉鎮區界線圖層」（原始資料來源：[直轄市、縣市界線](https://data.gov.tw/dataset/32158)、[鄉鎮市區界線](https://data.gov.tw/dataset/32157)），與海洋保育署「海洋行政區範圍圖層」（原始資料來源:[海洋保育地理資訊圖台](https://iocean.oca.gov.tw/iOceanMap/map.aspx)）進行套疊，再根據經緯度座標抓取鄉鎮區資料。|
| id | catalogNumber ||
||issue|若相對應municipality和minimumElevationInMeters欄位不為空值，則分別填入"County and Municipality derived from coordinates by TBN"，與"minimumElevationInMeters derived from coordinates by TBN"。|
||minimumElevationInMeters|由decimalLatitude及decimalLongitude計算之衍生欄位，使用美國國家航空暨太空總署(National Aeronautics and Space Administration, NASA)「臺灣30米數值地形模型資料(DEM)第三版」圖層（原始資料來源：[ASTER GDEM V3](https://asterweb.jpl.nasa.gov/gdem.asp?fbclid=IwAR1TdjOyhS-fNUav-CQHQdMz4Ad7GkqGY5ZY2Lq_CqpFNZ5c6ogS0DxI-aY)），根據經緯度座標抓取最低海拔欄位資料。此外，若coordinateUncertaintyInMeters為空值，或該數值大於5000，則此欄位不予填入。|
|license|license|僅上傳 licence = CC0 ; CC-BY; CC-BY-NC 三種授權資料|
||basisOfRecord|填寫"人為觀測"|
||decimalLatitude|若private_latitude不為空值，則從private_latitude抽取數值填入，反之，則從latitude抽取數值並填入|
||decimalLongitude|若private_longtitude不為空值，則從private_longtitude抽取數值填入，反之，則從longtitude抽取數值並填入|
|user_login|recordedBy||
|url|source||

### Script [240112_iNat_transformation_code.R]() 細節說明

#### 1. initialization
  * 建立相對路徑 "D:/Mong Chen/240110_iNat to OP")
  * 載入所需套件
  * 輸入 iNat 資料集-20231231_iNat_Taiwan_all.csv

#### 2. transformation (expect county ,municipality and minimumElevationInMeters, issue)
* 篩選清理與轉換資料所需iNat欄位
* 根據上表「iNaturalist對應TBN填入資料欄位」重新命名與轉換欄位

#### 3. catch county, Municipality, minimumElevationInMeters, issue
說明: 使用 [Taiwanlandsea_TownCounty.shp]() 圖層和 [twdtm_asterV2_30m.tif]() 圖層抓取行政區、最低海拔欄位資料
  * 根據有無經緯度資訊分割成: 無經緯度資料 `iNat_locNA` 和 有經緯度資料 `iNat_loc`
  *  有經緯度資料`iNat_loc`使用`catchlocation` function 抓取座標的行政區，並執行平行運算
  *  使用 `extract` 從 [twdtm_asterV2_30m.tif]() 抽取 `minimumElevationInMeters` 資料
  *  合併無經緯度資料和修改後資料 `iNat_loc_result`
  * `minimumElevationInMeters`: 1. 只有: `uncertaintyMeters`資訊才填入、 2. 數值須小於5000公尺時，才會填入數值
  * `issue`: TBN自行新增的縣市和海拔要加註: "County and Municipality derived from coordinates by TBN" ; "minimumElevationInMeters derived from coordinates by TBN"
  * [2024/1/19] 暫僅上傳"野生"動植物資料，"圈養/栽植"資料暫不上傳

#### 4. select licence = CC0 ; CC-BY; CC-BY-NC & time blur
* OP上傳資料僅包含 licence = CC0 ; CC-BY; CC-BY-NC 三種授權資料
* 若dataSensitiveCategory為重度，該紀錄的 month 和 day 欄位資訊刪除

#### 5. save file 
* 分割並儲存檔案

### Script [240117_iNat_data_exploration_plot_code.R]() 細節說明

#### 1. initialization
  * 建立相對路徑
  * 載入所需套件
  * 載入plot中文文字格式"微軟正黑體"和"微軟正黑體-粗"
  * 輸入資料集 iNat 資料集-20231231_iNat_Taiwan_all (all.data)

#### 2. plot 1: bar plot of the data numbers by state and county
* data re-subset & chainng: 篩選並轉換為縣市和鄉鎮區資料筆數資料表，設定好相關格式。
* 分別繪製縣市和鄉鎮區資料筆數 bar plot，並結合為一張 ( "無資訊" 代表county或municipality欄位為空值)。

#### 3. plot 2: histogram plot of the ebd's elevation distribution
iNat上傳資料的海拔分布圖。

#### 4. task 3: originalVernacularName vertification list
iNat物種名錄清單。

#### 5. sample
隨機抽取1000筆的資料表。
