#!/usr/bin/env bash
#
# Usage: ./generate.sh path/to/露台V8.3

set -euo pipefail

D="${1:-}"

[ -d "$D" ] || {
    echo "Usage: $0 path/to/露台V8.3"
    exit 1
}

curl -s 'https://flauver.github.io/jdh/lutai/zigen.json' | perl -CO -lE '
    use JSON::PP;
    local $/;
    $a = <>;
    $a = decode_json($a);
    for (@$a) {
        @roots = map { length > 1 ? "{$_}" : $_ } split /\s+/, $_->{name};
        $code = ucfirst $_->{key};
        for (@roots) {
            print "$_\t$code";
        }
    }' | LC_ALL=C sort -k2,2 -k1,1 > roots.tsv

perl -CSDA -Mutf8 -F'\t' -lanE '$F[1] =~ tr/123456/一丨丿丶乛乙/; $F[1] = join("", map { length > 1 ? "{$_}" : $_ } split /\s+/, $F[1]); print "$F[0]\t$F[1]"' beneficialcf.txt > chaifen.tsv

perl -CSDA -lnE '$ok = 1 if !$ok && /^\.\.\./; print if $ok' "$D/lutai.dict.yaml" > mabiao.tsv

../scripts/turn-roots-chaifen-mabiao-into-js.pl roots.tsv chaifen.tsv mabiao.tsv > lutai.js

../scripts/generate-roots-chart.pl -u ../sbfd/ -e lutai.js -t '露台字根表 v20250407' roots.tsv chaifen.tsv ../top6000.txt > lutai-v20250407.html
