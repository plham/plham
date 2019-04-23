# price-divergence.R
# データのあるフォルダに移動
setwd('/home/rice1982/programX10/plhamK/samples/ShockTransferPort')

# データを読み込み
datafile = 'settei1NEWresult.dat'
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

ymin = min(X1[,'market-price'], X2[,'market-price'])
ymax = max(X1[,'market-price'], X2[,'market-price'])

# 市場価格と理論価格をプロット
plot(X1[,'market-price'], type='l', col='red', ylim=c(ymin, ymax) )
lines(X2[,'market-price'], type='l', col='blue')
lines(X1[,'fundam-price'], type='l', col='green')
lines(X2[,'fundam-price'], type='l', col='green')
