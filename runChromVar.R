library(TFBSTools)
library(BiocParallel)
library(DBI)

# number of threads to use
register(MulticoreParam(20))

source('data/chromVarFns.R')
source('data/dirfns.R')
source("data/sqlfns.R")

con <- dbConnect(RSQLite::SQLite(),'data/atacCiona.db')

expDesign <- dbReadTable(con,"ataclib",row.names="lib")
ann <- getAnnotation(con)
peaksets <- getPeaksets(con)
scrna <- getScRNA(con)

row.names(expDesign) <- paste0(sub('^X','',row.names(expDesign)),'_q30_rmdup_KhM0_sorted')
row.names(expDesign) <- paste0(row.names(expDesign),'.bam')

expDesign <- expDesign[
  expDesign$tissue=='B7.5'&expDesign$omit==0,
]

motifs <- getHomerMotifs("known.motifs")

mespPeaks <- ann$peaks[peaksets$mespDep]
mespDesign <- expDesign[
  expDesign$time%in%c('6hpf','10hpf'),
]
mespDev <- getChromVAR(mespDesign,mespPeaks,motifs)

denovoCardiacPeaks <- ann$peaks[
  unique(geneToPeak(con,scrna$denovoCardiac)$PeakID)
]
cardiacDev <- getChromVAR(expDesign,denovoCardiacPeaks,motifs)

denovoASMPeaks <- ann$peaks[
  unique(geneToPeak(con,scrna$denovoASM)$PeakID)
]
asmDev <- getChromVAR(expDesign,denovoASMPeaks,motifs)

save(
  mespDev,cardiacDev,asmDev,
  file = mkdate('chromVarOut','Rdata')
)

mapply(
  dbWriteTable,
  c('mapk10chromVAR','denovoCardiacChomVAR','denovoAsmChromVAR'),
  lapply(list(mespDev,cardiacDev,asmDev),chromVarTable),
  MoreArgs = list(conn=con)
)