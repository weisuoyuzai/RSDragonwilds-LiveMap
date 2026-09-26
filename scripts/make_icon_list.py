"""Build the list of icons to pre-extract (name<TAB>package path) for `WorldExtract icons`.

Includes every journal portrait, all map / nav icons, rune icons, and every icon named in config.lua,
so a fresh install never has to export icons in game.

    python scripts/make_icon_list.py <Game-Windows.utoc> data/Scripts/icon_paths.lua mod/LiveMap/Scripts/config.lua <out.tsv>
"""
import re
import sys

from utoc_index import list_files

GROUPS = re.compile(r'^T_(Icon_Journal_|NavIcons_|Map_|Icon_Rune_|Agility_|HealthAltar_|LodestoneMapIcon)')


def main(utoc, icon_paths_lua, config_lua, out):
    names = set(re.findall(r'\["([^"]+)"\] = "', open(icon_paths_lua, encoding='utf-8').read()))
    want = {n for n in names if GROUPS.match(n)}
    want |= set(re.findall(r'icon = "([^"]+)"', open(config_lua, encoding='utf-8').read()))
    want |= {'T_NavIcons_Player_Self', 'T_Map_Icon_FriendArrow_1'}

    # CUE4Parse needs the real packaged path (plugin content is not reachable through /PluginName/ paths)
    real = {}
    for f in list_files(utoc):
        if f.endswith('.uasset'):
            name = f.rsplit('/', 1)[1][:-7]
            real.setdefault(name, f[:-7])
    missing = sorted(n for n in want if n not in real)
    with open(out, 'w', encoding='utf-8', newline='\n') as fh:
        for n in sorted(want):
            if n in real:
                fh.write(f'{n}\t{real[n]}.{n}\n')
    print(f'{len(want) - len(missing)} icons -> {out}' + (f' (not found: {missing})' if missing else ''))


if __name__ == '__main__':
    main(*sys.argv[1:5])
