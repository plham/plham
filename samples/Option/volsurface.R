
#args = commandArgs(T)
#if (length(args) < 2) {
#	cat("Usage: Rscript plot.R DATAFILE OUTFILE.png\n");
#	quit()
#}

#datafile = args[1]
#pngfile = args[2]

datafile = 'testOut.dat'
pngfile = 'output.png'

# https://en.wikipedia.org/wiki/Volatility_smile#Implied_volatility_surface
# An implied volatility surface is a 3-D plot that plots volatility smile and term structure of volatility in a consolidated three-dimensional surface for all options on a given underlying asset.
# It is believed that investor reassessments of the probabilities of fat-tail have led to higher prices for out-the-money options.
# Note: all the options. The figure in Wikipedia shows the put options only (delta = strike - under.price > 0).
#        \     smile     /
#         \_____________/
# Call: OTM <-- ATM --> ITM
# Put:  ITM <-- ATM --> OTM

cat('Extracting IMPLIED_VOLATILITY lines from', datafile, '\n')
temp = tempfile(tmpdir=tempdir()) # NOTE: Use "tempdir" to create "tempfile"
cat(grep('IMPLIED_VOLATILITY', readLines(datafile), value=T), file=temp, sep='\n')
datafile = temp
data = read.table(datafile, comment.char='')
colnames(data) = c('IMP-VOL', 't', 'option.id', 'option.name', 'under.id', 'premium', 'under.price', 'strike', 'maturity', 'time.to.maturity', 'imp.vol.call', 'imp.vol.put')
write(nrow(data),"")

data = data[data$t > 500,]
data = data[data$imp.vol.call < 5.0,] # Remove numerical errors (5 sigma will be okay)
data = data[data$imp.vol.put < 5.0,]  # Remove numerical errors (5 sigma will be okay)

data = data[data$time.to.maturity < 300,] # Just for visibility

otm.call = data$strike > data$under.price
otm.put  = data$strike < data$under.price

all.call = data$imp.vol.call > 0
all.put  = data$imp.vol.put > 0

no.call = c()
no.put = c()

filter.call = all.call # in {all, otm, no}
filter.put = all.put   # in {all, otm, no}

data.call = data[filter.call,]
data.put  = data[filter.put,]

# See Tompkins (2001)
x = c(log(data.call$strike / data.call$under.price) , log(data.put$strike / data.put$under.price))
y = c(data.call$time.to.maturity, data.put$time.to.maturity)
z = c(data.call$imp.vol.call, data.put$imp.vol.put)

# Discretizing
x = as.integer(x / (sd(x) / 4))   # binsize = sigma / 4 
y = as.integer(y / (max(y) / 30)) # binsize = oneyear / 30

xrange = range(x)
yrange = range(y)

# Smoothing: duplicating data 10 times, taking average over random neighbors with distance 3
ndup = 10
grid = -2:2
x = rep(x, ndup) + sample(grid, length(x) * ndup, replace=T)
y = rep(y, ndup) + sample(grid, length(y) * ndup, replace=T)
z = rep(z, ndup)

x = pmin(pmax(x, xrange[1]), xrange[2])
y = pmin(pmax(y, yrange[1]), yrange[2])

# Smoothing: Taking average over random neighbors with distance -2:2
out = tapply(z, list(x, y), mean)
cat('The number of NA =', sum(is.na(out)), '\n')
out[is.na(out)] = NA # Replace with a good interpolation

out.x = as.numeric(rownames(out))
out.y = as.numeric(colnames(out))
out.normalized = t(t(out) / out[which.min(abs(out.x)),]) # Approximately normalized version
if (1) {
	out = out.normalized
}

if (1) {
	# Quadratic curve fitting
	for (t in seq(out.y)) {
		m = nls(y ~ a * x**2 + b * x + c, list(x=out.x, y=out[,t]), start=list(a=1, b=1, c=0))
		out[,t] = predict(m, list(x=out.x))
	}
}

library(lattice)
png(pngfile, width=640, height=480)
wireframe((out), col.regions=rainbow(100), xlab='Moneyness', ylab='Time to Maturity', drape=T, scales=list(arrows=F, cex=.5, tick.number=10))
png(gsub('.png', '-2d.png', pngfile), width=640, height=480)
levelplot(log(out), col.regions=rainbow(100), xlab='Moneyness', ylab='Time to Maturity')

