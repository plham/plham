# コマンドライン
#
#   $ Rscript price-divergence-all.R  directory  input-file-name
#
args = commandArgs(T)


params = function(datafile) {
	X = read.table(datafile)
	colnames(X) = c('numport','numgoods','seed')

	return (X)
}

raw = function(datafile,param) {
	X = read.table(datafile)
	#cat(dim(X),"\n")
	mX <- as.matrix(X)
	size <- dim(X)[1]*as.integer(param[,'numgoods'])
	#cat(size,"\n")
	seeds <- rep(as.integer(param[,'seed']),size)

	out <- cbind(seeds,mX )

	return ( out )
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
	ip <- grep("param",subsub)
	#cat(subsub[ip],"\n")
	param = params(subsub[ip])
	#cat(as.integer(param[,'seed']),"\n")
	#ここまでOK
	D = raw(args[2],param)
	write.table(D, file="", row.names=F, col.names=F,quote=F)
	setwd(home)
}

#ave <- sum/count

#print(ave)

#for(i in 1:length(ave)){
#	cat(ave[i],"\n")
#}


