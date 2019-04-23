#!/bin/bash

# a.out や template.json を含むフォルダ（絶対パス）

# パラメータを別ファイルに保存
echo "$@" >paramsN$1-G$2-seed$3.txt


NUMPORT=$1
NUMBASEL=$(echo "1000-${1}" | bc -l)
NUMGOODS=$2

#echo $NUMPORT $NUMBASEL $NUMGOODS $3

# $1: ポートフォリオエージェントのうち，agent-1の人数NUMPORT（agent-2の人数はNUMBASEL1000-numPort）
# $2: 市場で扱われる商品の数．

export SETMARKET1=`$HOME/programX10/plham_portfolioOACIS3/oacisfile/WriteSETMARKET.out 1 $2`
export SETMARKET2=`$HOME/programX10/plham_portfolioOACIS3/oacisfile/WriteSETMARKET.out 2 $2`
export SETCASH=`$HOME/programX10/plham_portfolioOACIS3/oacisfile/WriteSETMARKET.out 3 $2`

LF=$(printf '\\\012_')
LF=${LF%_}
export SETMARKET2=`echo $SETMARKET2 | sed 's/\\n/'"$LF"'/g'`

#echo $SETMARKET1
#echo $SETMARKET2

sed "s/NUMGOODS/$NUMGOODS/g; s/NUMPORT/$NUMPORT/g; s/NUMBASEL/$NUMBASEL/g; s/SETMARKET1/$SETMARKET1/g; s/SETMARKET2/$SETMARKET2/g; s/SETCASH/$SETCASH/g" $HOME/programX10/plham_portfolioOACIS3/oacisfile/baselPortfolioNAsset.json > ./baselV2N$1-G$2-seed$3.json
$HOME/programX10/plham_portfolioOACIS3/baselPortfolioFP.out baselV2N$1-G$2-seed$3.json $3
#rm baselV2N$1-G$2-seed$3.json

