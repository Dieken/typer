from genanki import Note, Model, Package, Deck, guid_for
import random
import sys

## Author: @Jigsaw

# deck_id = 2123361570
deck_id = 2123361571  # 灵明
牌组 = Deck(deck_id, "灵明字根")

model_id = 1857619794
font_file =  sys.argv[1] if len(sys.argv) > 1 else "_Yuniversus.woff"
模版 = Model(
    model_id,
    "字根",
    [{"name": "字例"}, {"name": "编码"}, {"name": "音托解析"}],
    templates=[
        {
            "name": "字根-编码",
            "qfmt": "{{字例}}<br>{{hint:音托解析}}",
            "afmt": "{{FrontSide}}<hr id='answer'>答案是：{{编码}}",
        }
    ],
    css="""
.flex-col {
    flex: 1;
    justipy-content:center;
}

.flex-container {
    display: flex;
    gap: 8px;
}

.zigen {
    font-size: 50px;
}

.lizi {
    font-family: SourceHansSerifCN, serif;
}

.card {
    font-family: myfont, serif;
    font-size: 20px;
    text-align: center;
    color: black;
    background-color: white;
}

@font-face {
  font-family: myfont;
  src: url("{font_file}");
}
""".replace("{font_file}", font_file),
)

拆分表 = []
with open("./chaifen.csv", "r") as f:
    for line in f.readlines()[1:]:
        字, 拆, 台拆, 区块 = line.strip().split(",")
        if 区块 != "CJK":
            continue
        拆分表.append((字, 拆, 台拆, 区块))

with open("./zigen-ling.csv", "r") as f:
    pre = None
    字例 = ""
    音托解析 = ""
    for line in f.readlines()[1:]:
        字根, 编码, 拼音 = line.strip().split(",")
        例字 = []
        for 字, 拆, 台拆, 区块 in 拆分表:
            if 字根 in 拆:
                例字.append(字)
            if len(例字) >= 4:
                break
        if pre is not None and 编码 != pre[1]:
            牌组.add_note(
                Note(
                    model=模版,
                    fields=[
                        '<div class="flex-container">' + 字例 + "</div>",
                        pre[1],
                        音托解析,
                    ],
                )
            )
            字例 = ""
            音托解析 = ""
        pre = (字根, 编码, 拼音)
        字例 += f"""
<div class="flex-col">
<div class="zigen">{字根}</div>
<div class="lizi">{"".join(例字)}</div>
</div>
"""
        if 拼音:
            音托解析 += f"{字根}（{拼音}）<br/>"
    牌组.add_note(
        Note(
            model=模版,
            fields=[
                '<div class="flex-container">' + 字例 + "</div>",
                pre[1],
                音托解析,
            ],
        )
    )

my_package = Package(牌组)
my_package.media_files = [font_file]
my_package.write_to_file("灵明字根.apkg")
