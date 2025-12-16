#!/usr/bin/env bash

export R=$HOME/tmp/input-method-analysis/yujoy/卿雲輸入法_v3.10.2/schema
a=$(grep '^\s*-\s\+yuhao/' $R/yujoy_sc.dict.yaml | grep -v compatible | perl -lpE 's/\r//; s/\s*#.*//; s/^\s*\-\s*/-d $ENV{R}\//; s/$/.dict.yaml/')
./adjust-dict.pl $a -c ../简体字频表-2.5b.txt -w ../词频数据.txt -c override_weight.txt -w override_weight.txt > yujoy_sc.all.dict.yaml

perl -CSDA -F'\t' -lanE '$ok = 1 if /^\.\.\./; next unless $ok && $F[1]; print "$F[1]\t$F[0]"' yujoy_sc.all.dict.yaml | grep -v '^/' > q.txt
cp yujoy_sc.all.dict.yaml ~/Library/Rime/yuhao
