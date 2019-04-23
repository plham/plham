# price-divergence.R
# データのあるフォルダに移動
setwd('_input')

# データを読み込み
datafile = '_stdout.txt'
X = read.table(datafile)

# データの各カラム名を設定
colnames(X) = c('phase', 'time', 'market.id','market-name', 'market-price', 'fundam-price', 'index-value')

# マーケット ID を 1 ベースに変更
# 1--2 : 現物
# 3    : 先物
X['market.id'] = X['market.id'] + 1




# 現物 i の時系列のみ抽出
X1 = X[X['market.id'] == 1,]
X2 = X[X['market.id'] == 2,]
X3 = X[X['market.id'] == 3,]
X4 = X[X['market.id'] == 4,]

ymin = min(X1[,'market-price'], X2[,'market-price'],X3[,'market-price'], X4[,'market-price'])
ymax = max(X1[,'market-price'], X2[,'market-price'],X3[,'market-price'], X4[,'market-price'])

# 市場価格と理論価格をプロット
plot(X1[,'market-price'], type='l', col='red', ylim=c(ymin, ymax), xlim=c(30000, 60000) )
lines(X2[,'market-price'], type='l', col='blue')
lines(X3[,'market-price'], type='l', col='darkblue')
lines(X4[,'market-price'], type='l', col='pink')
lines(X1[,'fundam-price'], type='l', col='green')
lines(X2[,'fundam-price'], type='l', col='green')
lines(X3[,'fundam-price'], type='l', col='green')
lines(X4[,'fundam-price'], type='l', col='green')

