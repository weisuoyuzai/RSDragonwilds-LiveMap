"""Generate data/Scripts/icon_paths.lua: texture name -> in-game asset path, used by the mod's LoadAsset.

    python scripts/gen_icon_paths.py <Game-Windows.utoc> data/Scripts/icon_paths.lua
"""
import re
import sys

from utoc_index import game_path, list_files

KEEP = re.compile(r'^(T_Icon_|T_NavIcons_|T_Map_|T_HealthAltar_|T_Agility_|T_[A-Za-z0-9]*MapIcon)')


def main(utoc, out):
    paths = {}
    for f in list_files(utoc):
        if not f.endswith('.uasset'):
            continue
        gp = game_path(f)
        if not gp:
            continue
        name = gp.rsplit('.', 1)[1]
        if KEEP.match(name) and name not in paths:
            paths[name] = gp
    with open(out, 'w', encoding='utf-8', newline='\n') as fh:
        fh.write('-- 由游戏资源目录索引生成: 贴图名 -> 资源路径 (供 LoadAsset 使用)\nreturn {\n')
        for k in sorted(paths):
            fh.write(f'  ["{k}"] = "{paths[k]}",\n')
        fh.write('}\n')
    print(f'{len(paths)} icon paths -> {out}')


if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2])
