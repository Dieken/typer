#!/usr/bin/env bash

export R=$HOME/tmp/input-method-analysis/yustar/宇浩星陳_v3.8.0/schema
a=$(grep '^\s*-\s\+yuhao/' $R/yustar_sc.dict.yaml | perl -lpE 's/\r//; s/^\s*\-\s*/-d $ENV{R}\//; s/$/.dict.yaml/')
./adjust-dict.pl $a -c ../简体字频表-2.5b.txt -w ../词频数据.txt -c override_weight.txt -w override_weight.txt > yustar_sc.all.dict.yaml

perl -CSDA -F'\t' -lanE '$ok = 1 if /^\.\.\./; next unless $ok && $F[1]; print "$F[1]\t$F[0]"' yustar_sc.all.dict.yaml | grep -v '^/' > q.txt
cp yustar_sc.all.dict.yaml ~/Library/Rime/yuhao
