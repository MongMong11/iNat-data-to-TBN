#path
setwd("D:/Mong Chen/240110_iNat to OP")


#library
library(data.table)
library(ggplot2)
library(dplyr)
library(gridExtra)
library(showtext)
showtext_auto() 
font_add("Microsoft_JhengHei", regular = "C:/Windows/Fonts/msjh.ttc")
font_add("Microsoft_JhengHei_bold", regular = "C:/Windows/Fonts/msjhbd.ttc")

#fread
all.data <- 
  lapply(1:4, function(i)
    fread(file.path("D:/Mong Chen/240110_iNat to OP/output_to_op/", 
                    sprintf("inat_split_%s.csv", i)), encoding = "UTF-8"
    )
  )
all.data<- do.call(rbind,all.data)

#plot 1: bar plot of the data numbers by state and county

#all.data re-subset & chainng
plot1_data<-all.data[,.N, by=.(county, municipality)]


plot1_data2<-plot1_data[,.(N.Sum=sum(N)), by=county]
plot1_data2$county<-ifelse(plot1_data2$county=="",
                           "無資訊",plot1_data2$county)
plot1_data2$county2 <- factor(plot1_data2$county, levels=c("連江縣", "金門縣", "澎湖縣", "台東縣", "花蓮縣", "宜蘭縣",
                                                           "屏東縣", "高雄市", "台南市", "嘉義縣", "嘉義市", "雲林縣",
                                                           "彰化縣", "南投縣", "台中市", "苗栗縣", "新竹縣", "新竹市",
                                                           "桃園市", "新北市", "台北市", "基隆市", "無資訊"))
plot1_data2$N.Sum<-round(plot1_data2$N.Sum/1000, digits=2)
plot1_data3 <- plot1_data
plot1_data3$municipality<-ifelse(plot1_data3$municipality=="",
                                 "無資訊",plot1_data3$municipality)
plot1_data3 <- plot1_data3[which(plot1_data3$county!=""),]

#plot1-1: state
plot_state<-ggplot(plot1_data2, aes(x=county2, y=N.Sum)) +
  geom_bar(stat="identity", fill="steelblue")+
  xlab("縣市")+
  ylab("資料筆數(千)")+
  geom_text(aes(label=N.Sum), hjust=-0.05, size=5)+
  theme_bw(base_size = 20)+
  theme(
    text = element_text(family = "Microsoft_JhengHei"),
    axis.title = element_text(family = "Microsoft_JhengHei_bold")
  )+ coord_flip()

#plot1-2: county
datalist = list()
for (i in 1:length(unique(plot1_data3$county))) {
  #list
  list<-unique(plot1_data3$county)
  #input
  table<-plot1_data3[grepl(list[i],county)]
  datalist[[i]] <- table
}



for (i in 1:length(unique(plot1_data3$county))) {
  table<-datalist[[i]]
  #  table$N<-round(table$N/100, digits = 2)
  state<-unique(table$county)
  p<-ggplot(table, aes(x=municipality, y=N)) +
    geom_bar(stat="identity", fill="grey")+
    xlab("鄉鎮市")+
    ylab("資料筆數")+
    scale_y_continuous(breaks=seq(0,50000,10000),limits=c(0, 50000))+
    ggtitle(state)+
    geom_text(aes(label=N), hjust=0, size=3)+
    theme_bw( base_size = 14)+
    theme(
      axis.title.x = element_blank(), axis.title.y = element_blank(),
      text = element_text(family = "Microsoft_JhengHei"),
      plot.title = element_text(family = "Microsoft_JhengHei_bold"),
    )+ coord_flip()
  assign(paste("p", i, sep=""),p)
}

p.all<-grid.arrange(p1, p2, p3, p4, p5, p6, p7, p8, p9, p10,
                    p11, p12, p13, p14, p15, p16, p17, p18, p19, p20,
                    p21, p22, ncol = 6)

p.all2<-grid.arrange(plot_state,p.all, ncol = 2)

#plot 2: histogram plot of the iNat's elevation distribution
plot2_data<-all.data[which(all.data$minimumElevationInMeters!=""),]


ggplot(plot2_data, aes(x=minimumElevationInMeters)) + 
  geom_histogram(aes(y=..density..), colour="black", fill="white", bins = 1000)+
  geom_density(alpha=.2, fill="#FF6666")+
  xlab("minimumElevationInMeters")+
  ylab("density")+
  scale_x_continuous(breaks=seq(0,4000,500),limits=c(0, 4000))+
  theme_bw(base_size = 20)

#task 3: originalVernacularName vertification list
ver_list<-unique(all.data$originalVernacularName)
table<-data.frame(matrix(NA,length(ver_list),2))
colnames(table)<-c("ID", "scientific_name")
table[,1]<-1:length(ver_list)
table[,2]<-ver_list
View(table)
fwrite(table, "D:/Mong Chen/240110_iNat to OP/output/scientificname_vertification_list.csv")

x<-table
x_split<-split(x, rep(1:ceiling(nrow(x)/5000), each=5000, length.out=nrow(x)))
dir.create("output/vertification_list")
for (i in 1:ceiling(nrow(x)/5000)) {
  table<-as.data.table(x_split[[i]])
  fwrite(table, sprintf("output/vertification_list/verlist_split_%s.csv", i))
}



#sample
random_ls<-sample(1:nrow(all.data), size = 1000)
table<-data.frame(matrix(NA,1000,19))
colnames(table)<-colnames(all.data)

for (i in 1:1000) {
  table[i,]<-all.data[random_ls[i],]
}
head(table)
fwrite(table, "D:/Mong Chen/240110_iNat to OP/output/random_table.csv")

