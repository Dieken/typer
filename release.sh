#!/usr/bin/env sh

set -euo pipefail

DATE=$(date +%Y%m%d)
COMMIT=$(git rev-parse --short HEAD)
TAG=$DATE-$COMMIT

git archive --prefix=typer-$TAG/ -o typer-$TAG.tar.gz HEAD

rm -rf fyne-cross/

fyne-cross darwin -app-id typer.$TAG
fyne-cross windows -app-id typer.$TAG
fyne-cross linux -app-id typer.$TAG

tar xvf typer-$TAG.tar.gz
rm typer-$TAG.tar.gz

cp -a fyne-cross/dist/* typer-$TAG/

tar cvf typer-$TAG.tar.gz typer-$TAG
