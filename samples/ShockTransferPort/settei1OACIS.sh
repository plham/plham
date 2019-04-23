#!/bin/bash
# a.out や template.json を含むフォルダ（絶対パス）
# パラメータを別ファイルに保存
echo "$@" >paramsF$1-$2-$3-seed$4.txt

sed "s/F1/$1/g; s/F2/$2/g; s/F3/$3/g" $HOME/plhamK/samples/ShockTransferPort/settei1OACIS.json > ./settei1c$1-$2-$3-seed$4.json

$HOME/plhamK/samples/ShockTransferPort/FCNMarkowitzFundamentalPriceShockMain.out ./settei1c$1-$2-$3-seed$4.json $4



