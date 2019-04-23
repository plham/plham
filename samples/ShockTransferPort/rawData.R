


# コマンドライン
#
#   $ Rscript price-divergence-all.R  directory  input-file-name
#
args = commandArgs(T)



raw = function(datafile,count) {
  X = read.table(datafile)
  #cat(dim(X),"\n")
  mX <- as.matrix(X)
  size <- dim(X)[1]
  #cat(size,"\n")
  seeds <- rep(count,size)
  #cat(seeds)
  out <- cbind(seeds,mX )
  
  return ( out )
  #return (mX)
}

# すべてのサブフォルダについてループ
home = getwd()
pattern = paste(args[1], '/*/', sep='')
count <- 0
#sum <- c()
for (d in Sys.glob(pattern)) {
  count <- count+1
  setwd(d)
  subsub = list.files()

  #cat(as.integer(param[,'seed']),"\n")
  #ここまでOK
  D = raw(args[2],count)
  #D = raw("settei1result.dat",count)
  #write.table(D)  

  if(count==1){
   write.table(D, file="", row.names=F, col.names=F,quote=F,append=F)
  }else{
   write.table(D, file="", row.names=F, col.names=F,quote=F,append=T)
  }
  setwd(home)
#}


