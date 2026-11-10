#!/usr/bin/env python3
"""灰盒草图 → Tiled 地图（计划 22；设计 2026-11-10 第 2 节，level-design：先灰盒、试玩、再上图）。

输入是一份"字符草图"JSON（就是计划 20、21 用的 data/maps/biohazard1.json 那种格式）：
  每个地点一张 rows（一行一个字符串），图例：
    # 墙（下面是屋里时画成墙面）  . 地面  = 地毯/过道  ~ 浅水  o 家具设备  x 墙上的激光发射器
    S 可以搜索的柜子  D 门
  doors：隔壁地点 → 门在哪条边（left/right/top/bottom）；start：开场格子；npc_fixed：{人物: 格子}；
  npc_spots：剧情人物按顺序站的格子；theme、ambient（#RRGGBB）、lights、glows（颜色 #RRGGBB 或 #RRGGBBAA）。
输出：每个地点一个 <地点>.tmj（Tiled 1.11 JSON，CSV 图块数据），图块集引用 ../tilesets/greybox.tsj。
  图层：floor（地面、地毯、浅水、门）、walls（墙、墙面、激光发射器）、decor（家具、柜子）、over（空）；
  物件：door{to}、arrive{from 或 start, facing}、search、npc{id}、npc_spot{order}、light、glow。
转换出来的 .tmj 就是以后的正本：可以用 Tiled 打开编辑，不要再从草图重新生成覆盖。

用法：python -I -X utf8 game/tools/blockout_to_tiled.py <草图.json> <输出目录> [图块集路径（相对输出目录，默认 ../tilesets/greybox.tsj）]
"""
import json
import sys
from pathlib import Path

TILE = 16
# greybox.tsj 里的图块编号（gid = 编号 + 1）
FLOOR, CARPET, WATER, WALL, WALL_FACE, PROP, LASER, SEARCH, DOOR = range(9)
SIDE_IN = {"left": (1, 0), "right": (-1, 0), "top": (0, 1), "bottom": (0, -1)}
DIR_NAME = {(1, 0): "right", (-1, 0): "left", (0, 1): "down", (0, -1): "up"}


def tiled_color(hex_color: str) -> str:
    """#RRGGBB / #RRGGBBAA → Tiled 的 #AARRGGBB。"""
    s = hex_color.lstrip("#")
    if len(s) == 6:
        return "#ff" + s.lower()
    if len(s) == 8:
        return "#" + s[6:8].lower() + s[0:6].lower()
    raise ValueError("颜色写错了：" + hex_color)


def prop(name, typ, value):
    return {"name": name, "type": typ, "value": value}


def side_of(x, y, w, h):
    if x == 0:
        return "left"
    if x == w - 1:
        return "right"
    if y == 0:
        return "top"
    if y == h - 1:
        return "bottom"
    return ""


def dir_between(a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    if abs(dx) > abs(dy):
        return "right" if dx > 0 else "left"
    return "up" if dy < 0 else "down"


def convert(loc, m, w, h, tileset="../tilesets/greybox.tsj"):
    rows = m["rows"]
    assert len(rows) == h and all(len(r) == w for r in rows), loc
    floor = [0] * (w * h)
    walls = [0] * (w * h)
    decor = [0] * (w * h)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            i = y * w + x
            if ch == ".":
                floor[i] = FLOOR + 1
            elif ch == "=":
                floor[i] = CARPET + 1
            elif ch == "~":
                floor[i] = WATER + 1
            elif ch == "#":
                below = rows[y + 1][x] if y + 1 < h else "#"
                walls[i] = (WALL_FACE if below != "#" else WALL) + 1
            elif ch == "o":
                floor[i] = FLOOR + 1
                decor[i] = PROP + 1
            elif ch == "x":
                walls[i] = LASER + 1
            elif ch == "S":
                floor[i] = FLOOR + 1
                decor[i] = SEARCH + 1
            elif ch == "D":
                floor[i] = DOOR + 1
            else:
                raise ValueError(f"{loc} 第 {y} 行有不认识的字符 {ch!r}")
    objects = []

    def obj(typ, x, y, cw=1, ch=1, props=None):
        objects.append({
            "id": len(objects) + 1, "name": "", "type": typ,
            "x": x * TILE, "y": y * TILE, "width": cw * TILE, "height": ch * TILE,
            "rotation": 0, "visible": True, "properties": props or [],
        })

    side_to_dest = {side: dest for dest, side in m.get("doors", {}).items()}
    door_cells = {}
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "D":
                dest = side_to_dest.get(side_of(x, y, w, h), "")
                assert dest, f"{loc} 的门 ({x},{y}) 不知道通向哪"
                door_cells.setdefault(dest, []).append((x, y))
    for dest in m.get("doors", {}):
        cells = sorted(door_cells.get(dest, []), key=lambda c: (c[1], c[0]))
        assert cells, f"{loc} 通向 {dest} 的门那条边上没有 D"
        xs = [c[0] for c in cells]
        ys = [c[1] for c in cells]
        obj("door", min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1, [prop("to", "string", dest)])
    if "start" in m:
        sx, sy = m["start"]
        first = sorted(door_cells[next(iter(m["doors"]))], key=lambda c: (c[1], c[0]))[0]
        obj("arrive", sx, sy, props=[prop("start", "bool", True), prop("facing", "string", dir_between((sx, sy), first))])
    for dest, side in m.get("doors", {}).items():
        first = sorted(door_cells[dest], key=lambda c: (c[1], c[0]))[0]
        dx, dy = SIDE_IN[side]
        obj("arrive", first[0] + dx, first[1] + dy, props=[prop("from", "string", dest), prop("facing", "string", DIR_NAME[(dx, dy)])])
    for y, row in enumerate(rows):
        x = row.find("S")
        if x >= 0:
            obj("search", x, y)
    for npc_id, (x, y) in m.get("npc_fixed", {}).items():
        obj("npc", x, y, props=[prop("id", "string", npc_id)])
    for i, (x, y) in enumerate(m.get("npc_spots", [])):
        obj("npc_spot", x, y, props=[prop("order", "int", i)])
    for l in m.get("lights", []):
        x, y = l["at"]
        props = [prop("color", "color", tiled_color(l["color"])), prop("radius", "float", float(l["radius"])), prop("energy", "float", float(l["energy"]))]
        if l.get("flicker"):
            props.append(prop("flicker", "bool", True))
        obj("light", x, y, props=props)
    for g in m.get("glows", []):
        x, y = g["at"]
        obj("glow", x, y, props=[prop("color", "color", tiled_color(g["color"])), prop("radius", "float", float(g["radius"]))])
    map_props = [prop("theme", "string", m.get("theme", ""))]
    if "ambient" in m:
        map_props.append(prop("ambient", "color", tiled_color(m["ambient"])))

    def tile_layer(lid, name, data):
        return {"id": lid, "name": name, "type": "tilelayer", "x": 0, "y": 0, "width": w, "height": h,
                "opacity": 1, "visible": True, "data": data}

    return {
        "type": "map", "version": "1.10", "tiledversion": "1.11.0",
        "orientation": "orthogonal", "renderorder": "right-down", "infinite": False,
        "width": w, "height": h, "tilewidth": TILE, "tileheight": TILE, "compressionlevel": -1,
        "properties": map_props,
        "tilesets": [{"firstgid": 1, "source": tileset}],
        "layers": [
            tile_layer(1, "floor", floor), tile_layer(2, "walls", walls), tile_layer(3, "decor", decor),
            tile_layer(4, "over", [0] * (w * h)),
            {"id": 5, "name": "objects", "type": "objectgroup", "x": 0, "y": 0, "opacity": 1, "visible": True,
             "draworder": "topdown", "objects": objects},
        ],
        "nextlayerid": 6, "nextobjectid": len(objects) + 1,
    }


def dumps(d, w):
    """跟 Tiled 一样的 JSON，但图块数据按地图的行换行，方便看 diff。"""
    text = json.dumps(d, ensure_ascii=False, indent="\t")
    # 把 "data": [ 后面一个数一行的写法压成一行一排
    result = []
    i = 0
    lines = text.split("\n")
    while i < len(lines):
        line = lines[i]
        if line.strip() == '"data": [':
            indent = line[: len(line) - len(line.lstrip())]
            nums = []
            i += 1
            while lines[i].strip() not in ("]", "],"):
                nums.append(lines[i].strip().rstrip(","))
                i += 1
            closing = lines[i].strip()
            result.append(indent + '"data": [')
            for r in range(0, len(nums), w):
                chunk = ",".join(nums[r:r + w])
                result.append(indent + "\t" + chunk + ("," if r + w < len(nums) else ""))
            result.append(indent + closing)
        else:
            result.append(line)
        i += 1
    return "\n".join(result) + "\n"


def main():
    src, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    tileset = sys.argv[3] if len(sys.argv) > 3 else "../tilesets/greybox.tsj"
    data = json.loads(src.read_text(encoding="utf-8"))
    w, h = data["size"]
    out_dir.mkdir(parents=True, exist_ok=True)
    for loc, m in data["maps"].items():
        d = convert(loc, m, w, h, tileset)
        text = dumps(d, w)
        json.loads(text)
        (out_dir / f"{loc}.tmj").write_text(text, encoding="utf-8", newline="\n")
        print("wrote", out_dir / f"{loc}.tmj")


if __name__ == "__main__":
    main()
