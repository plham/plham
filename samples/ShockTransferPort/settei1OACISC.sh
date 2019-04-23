#!/bin/bash
# a.out や template.json を含むフォルダ（絶対パス）
# パラメータを別ファイルに保存
echo "$@" >paramsC$1-$2-$3-seed$4.txt

sed "s/C1/$1/g; s/C2/$2/g; s/C3/$3/g" ./samples/ShockTransferPort/settei1OACISC.json > ./settei1cC$1-$2-$3-seed$4.json

./samples/ShockTransferPort/FCNMarkowitzFundamentalPriceShockMain.out ./settei1cC$1-$2-$3-seed$4.json $4



