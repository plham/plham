#!/bin/bash

# a.out や template.json を含むフォルダ（絶対パス）

# パラメータを別ファイルに保存
echo "$@" >paramsR$1-G$2-seed$3.txt

NUMLOCAL=$1

NUMPORT=$(echo "1000-${NUMLOCAL}" | bc)

NUMGOODS=$2

# $1: ポートフォリオエージェントのうち，agent-1の人数NUMPORT（agent-2の人数はNUMBASEL1000-numPort）
# $2: 市場で扱われる商品の数．

declare -i NUMNORMALPORT
declare -i NUMBASELPORT

declare -i NUMNORMALLOCAL
declare -i NUMBASELLOCAL
declare -i DIF


export NUMNORMALLOCAL=$(echo "4*${NUMLOCAL}/5" | bc)
export NUMBASELLOCAL=$(echo "${NUMLOCAL}/5" | bc)

export NUMNORMALPORT=$(echo "4*${NUMPORT}/5" | bc)
export NUMBASELPORT=$(echo "${NUMPORT} / 5" )


#echo "${NUMNORMALLOCAL}*3"
#echo "${NUMBASELLOCAL}*3"
#echo "${NUMNORMALPORT}"
#echo "${NUMBASELPORT}"
export SUM=$(echo "${NUMNORMALLOCAL} + ${NUMBASELLOCAL} + ${NUMNORMALPORT} + ${NUMBASELPORT}" |bc)
#echo "$SUM"

export SETMARKET1=`$HOME/programX10/plham_portfolioOACIS3/oacisfile/WriteSETMARKET.out 1 $2`
export SETMARKET2=`$HOME/programX10/plham_portfolioOACIS3/oacisfile/WriteSETMARKET.out 2 $2`
export SETCASH=`$HOME/programX10/plham_portfolioOACIS3/oacisfile/WriteSETMARKET.out 3 $2`
export SETLOCALAGENT1=`$HOME/programX10/plham_portfolioOACIS3/oacisfile/WriteSETMARKET.out 4 $2`
export SETLOCALAGENT2=`$HOME/programX10/plham_portfolioOACIS3/oacisfile/WriteSETMARKET.out 5 $2`


LF=$(printf '\\\012_')
LF=${LF%_}
export SETMARKET2=`echo -e $SETMARKET2 | sed 's/\\n/'"$LF"'/g'`
export SETLOCALAGENT2=`echo -e $SETLOCALAGENT2 | sed 's/\\n/'"$LF"'/g'`

sed "s/NUMGOODS/$NUMGOODS/g; s/NUMNORMALPORT/$NUMNORMALPORT/g; s/NUMBASELPORT/$NUMBASELPORT/g; s/SETLOCALAGENT1/$SETLOCALAGENT1/g; s/SETLOCALAGENT2/$SETLOCALAGENT2/g; s/SETMARKET1/$SETMARKET1/g; s/SETMARKET2/$SETMARKET2/g; s/SETCASH/$SETCASH/g" $HOME/programX10/plham_portfolioOACIS3/oacisfile/baselPortfolioPortRate.json > ./interBaselR$1-G$2-seed$3.json
sed "s/NUMNORMALLOCAL/$NUMNORMALLOCAL/g; s/NUMBASELLOCAL/$NUMBASELLOCAL/g" ./interBaselR$1-G$2-seed$3.json > ./baselR$1-G$2-seed$3.json
#$HOME/programX10/plham_portfolioOACIS3/baselPortfolioFP.out baselR$1-G$2-seed$3.json $3
rm interBaselR$1-G$2-seed$3.json
#rm baselR$1-G$2-seed$3.json

