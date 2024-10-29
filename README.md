# Typer - 形码输入法打字练习

利用形码的字根表、拆分表、码表练习打字，输入正确编码自动跳到下一条，或者直接回车跳到下一条。

## 文件格式

* 字根表格式： 空白字符分隔的两列，第一列是字根的字符，支持类似`{至上}`字样的字根，第二列是字根的编码， 默认文件为 `roots.tsv`；
* 拆分表格式： 空白字符分隔的两列，第一列是单个汉字，第二列是拆分的字根列表，不可包含空白字符， 默认文件为 `chaifen.tsv`；
* 码表格式： 空白字符分隔的两列，第一列是单字或者词组，第二列是编码， 默认文件为 `mabiao.tsv`；
* 待练习的词表格式： 一行一个单字或者词组，必须包含在码表中， 默认使用码表；

## 构建

参考 [Fyne Getting Started](https://docs.fyne.io/started/)，需要安装 C 编译器，可以使用
[Fyne Cross Compiling](https://docs.fyne.io/started/cross-compiling) 交叉编译。

```
go build
```

## 运行

```
./typer --help

#export FYNE_SCALE=2.0                          # 字体放大
exort FYNE_FONT=/path/to/TH-Tshyn-P0.ttf        # http://cheonhyeong.com/Simplified/download.html
./typer
```

## 预制文件

* sbfd/: [声笔飞单](https://sbxlm.github.io/sbfd/)字根表、拆分表、码表；
* sky/:  [天码](https://yuhao.forfudan.com/docs/tianma.html)字根表、拆分表、码表；
* yustar/: [宇浩星陈](https://yuhao.forfudan.com/learn/)字根表、拆分表、码表；
* yujoy/: [卿云](https://shurufa.app/docs/joy.html)字根表；
* tiger/: [虎码](https://tiger-code.com)字根表、拆分表、码表；
* top6000.txt: 高频单字表，由 `tiger/generate.sh` 生成；
