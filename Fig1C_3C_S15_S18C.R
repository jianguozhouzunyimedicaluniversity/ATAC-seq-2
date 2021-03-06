# Figs. 1C, 3C, S15, S18C

library(DBI)
library(ComplexHeatmap)
library(circlize)

source('data/sqlfns.R')
source('data/dirfns.R')
source("data/corHeatmap.R")

con <- dbConnect(RSQLite::SQLite(),'data/atacCiona.db')

gene.names <- dbReadTable(con,'gene_name',row.names="GeneID")

bulkGS <- getBulkRNA(con)
scrna <- getScRNA(con)
prime.denovo <- scrna[c(
  'primedCardiac','primedASM','denovoCardiac','denovoASM','TVCP','STVC','ATM','mesenchyme'
)]
cardiac.asm <- scrna[c(
  'Cardiac','ASM','TVCP','STVC','ATM','mesenchyme'
)]
cardiac.asm$mesenchyme <- intersect(cardiac.asm$mesenchyme,unlist(bulkGS))

scrnaGenePeak <- lapply(scrna,function(x)geneToPeak(con,x))
peaksets <- getPeaksets(con)
DApeaks <- peaksets[c('timeDep','mespDep','handrDep','tissueDep')]
DAunion <- Reduce(union,DApeaks)
atacdat <- getAtacLib(con,c(
  "condition_mesp_dnFGFR_vs_control","condition_FoxF_KO_vs_control",
  "condition_mesp_MekMut_vs_control",
  "condition_handr_dnFGFR_vs_control","condition_handr_MekMut_vs_control"
))

daAnnotation <- function(mat,sets=DApeaks) rowAnnotation(sapply(
  sets,
  function(x) row.names(mat)%in%x
),col=lapply(
  sets,
  function(x) c(`FALSE`='white',`TRUE`='black')
))

splitPeakHmap <- function(
  peak.gene,mat,sets=DApeaks,
  col=colorRamp2(c(-2,0,2),c('blue','white','red')),...
){
  mat <- do.call(rbind,sapply(peak.gene,function(x) mat[x[,"PeakID"],,drop=F]))
  hm <- Heatmap(
    mat,
    split = do.call(c,mapply(rep,names(peak.gene),sapply(peak.gene,nrow))),
    col = col,
    cluster_columns = F,gap=unit(.5,'cm'),...
  )
  if(!is.null(sets)) hm <- hm+daAnnotation(mat,sets)
  return(hm)
}

genePeakHmap <- function(peak.gene,mat,file,sets=NULL,...){
  peak.gene <- peak.gene[sapply(peak.gene,length)>0]
  hm <- splitPeakHmap(peak.gene,mat,sets,...)
  ann <- rowAnnotation(text=row_anno_text(
    sub('(.{,12}).*','\\1',sub(
      "KH2013:","",gene.names[
        do.call(c,sapply(peak.gene,'[',,'GeneID')),"UniqueNAME"
        ]
    ))
  ),width=unit(3.5,'cm'))
  
  dir.eps(file,height=sum(sapply(
    peak.gene,
    function(x) length(intersect(row.names(mat),x[,"PeakID"]))
  ))/6+2)
  draw(hm+ann)
  dev.off()
}

timect <- dbReadTable(con,'timect',row.names="PeakID")
timeavg <- apply(timect,1,mean)
timeavg <- timect/timeavg
avg6 <- apply(timeavg[,1:3],1,mean)
avg10 <- apply(timeavg[,4:7],1,mean)
avg18 <- apply(timeavg[,9:12],1,mean)

tissuect <- dbReadTable(con,'tissuect')
tissue10 <- log2(apply(tissuect[,2:5],1,mean)/apply(tissuect[,6:7],1,mean))
tissue18 <- log2(apply(tissuect[,15:18],1,mean)/apply(tissuect[,10:12],1,mean))

peakmat <- cbind(
  log2(cbind(avg6,avg10,avg18)),
  sapply(atacdat,'[[','log2FoldChange'),
  B75vGFP10=tissue10,B75vGFP18=tissue18
)
peakmat[!is.finite(peakmat)] <- NaN

# dbGetQuery(con,paste("SELECT * FROM geneToPeak WHERE GeneID IN (",paste()))
prime.denovoGenePeak <- lapply(prime.denovo,function(x) geneToPeak(con,x))
prime.denovoDA <- lapply(prime.denovoGenePeak,function(x) x[x$PeakID%in%DAunion,])

DAmat <- do.call(rbind,sapply(prime.denovoDA,function(x) peakmat[x$PeakID,]))


cardiac.asmGenePeak <- lapply(cardiac.asm,function(x) geneToPeak(con,x))
cardiac.asmDA <- lapply(cardiac.asmGenePeak,function(x) x[x$PeakID%in%DAunion,])

cardiac.asmMat <- do.call(rbind,sapply(cardiac.asmDA,function(x) peakmat[x$PeakID,]))


# Fig. 1C
dir.eps('time',height=12)
col.hmap(
  peakmat[peaksets$timeDep,c(-5,-7:-8)],
  split=peakmat[peaksets$timeDep,1]>0,
  # col=colorRamp2(c(-1,0,1),c('blue','white','red')),
  cluster_columns = F,show_row_names = F,gap = unit(.5,'cm')
)
dev.off()


acc <- list(
  cardiac=peaksets$heartAcc,
  ASM=peaksets$asmAcc,
  TVC=Reduce(setdiff,list(
    # row.names(subset(atacdat$condition_mesp_dnFGFR_vs_control,log2FoldChange< -.5&padj<.05)),
    peaksets$tvcAcc,
    peaksets$closedFoxf,
    peaksets$heartAcc,peaksets$asmAcc
  )),
  FoxF=peaksets$closedFoxf
  # FoxF=Reduce(setdiff,list(closedFoxf,heartAcc,asmAcc))
)
timeacc <- sapply(acc,intersect,peaksets$timeDep)

# Fig. 3C, S18C
mapply(
  function(genes,file) {
    genePeakHmap(
      lapply(timeacc,function(x) mergeGenePeak(con,genes,x)),
      peakmat,
      file
    )
  },
  prime.denovo,paste0(names(prime.denovo),'AccTime')
)

# Fig. S15
tmp <- mergeGenePeak(con,bulkGS$FoxFactivated,peaksets$timeDep)
tmp[,1] <- gene.names[tmp$GeneID,"UniqueNAME"]
dir.eps('foxfTime',height=nrow(tmp)/6+2)
Heatmap(
  peakmat[tmp[,2],c(1:5,9)],
  cluster_columns = F,
  split=tmp[,1],row_title_rot = 0,
  row_title_gp = gpar(cex=1)
  # col = colorRamp2(c(-2,0,2),c('dodgerblue4','white','firebrick4'))
)
dev.off()

tmp <- mergeGenePeak(con,bulkGS$FoxFactivated,unique(unlist(peaksets[c('closed6','closed18')])))
tmp[,1] <- gene.names[tmp$GeneID,"UniqueNAME"]
dir.eps('foxf_closed6_18',height=nrow(tmp)/6+2)
Heatmap(
  peakmat[tmp[,2],c(1:5,9)],
  cluster_columns = F,
  split=tmp[,1],
  row_title_rot = 0,
  row_title_gp = gpar(cex=1)
  # col = colorRamp2(c(-2,0,2),c('dodgerblue4','white','firebrick4'))
)
dev.off()

