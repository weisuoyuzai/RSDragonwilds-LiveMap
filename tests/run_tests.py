"""Offline tests for LiveMap (no game needed).

    pip install lupa
    python tests/run_tests.py

1. every Lua file compiles (Lua 5.4, same as UE4SS)
2. main.lua runs against a simulated UE4SS API and produces the expected data files
3. the web page script parses (needs Node.js; skipped if node is missing)
4. server.ps1 parses (needs PowerShell; skipped if missing)
"""
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'scripts'))
from build_package import stage  # noqa: E402

import lupa.lua54 as lupa  # noqa: E402

failures = []


def check(cond, msg):
    print(('  ok   ' if cond else '  FAIL ') + msg)
    if not cond:
        failures.append(msg)


def test_compile(mod):
    print('[lua compile]')
    lua = lupa.LuaRuntime()
    compile_ = lua.eval('function(src, name) local f, err = load(src, "@" .. name) return err end')
    for path in sorted(glob.glob(os.path.join(mod, 'Scripts', '*.lua'))):
        err = compile_(open(path, encoding='utf-8').read(), os.path.basename(path))
        check(err is None, f'{os.path.basename(path)} {err or ""}')


def test_runtime(mod):
    print('[main.lua with simulated UE4SS]')
    # 旧版本的存档: 里面有被当成地点存下来的队友箭头, 应在加载时清掉
    with open(os.path.join(mod, 'saved_pois.lua'), 'w', encoding='utf-8') as f:
        f.write('return {\n["L_World"]={\n'
                '["MapIcon|1236|1279|0"]={c="landmark",n="T_Map_Icon_FriendArrow_1",x=123610.0,y=127897.0,z=0.0,t=1,'
                'i="T_Map_Icon_FriendArrow_1"},\n},\n}\n')
    lua = lupa.LuaRuntime()
    run = lua.eval('function(src, mod) return load(src, "@harness")(mod) end')
    logs = run(open(os.path.join(ROOT, 'tests', 'harness.lua'), encoding='utf-8').read(), mod + os.sep)
    check('[LiveMap]' in logs and 'L_World' in logs, 'mod started and loaded world data')

    data = os.path.join(mod, 'web', 'data')
    load = lambda name: json.load(open(os.path.join(data, name), encoding='utf-8'))

    static = load('static_L_World.json')['pois']
    counts = Counter(p['c'] for p in static)
    check(len(static) > 10000, f'full-map data: {len(static)} points')
    for cat, minimum in [('lodestone', 4), ('anima', 200), ('geyser', 200), ('chest', 400), ('teleporter', 100),
                         ('ore', 2000), ('fishing', 150), ('shrine', 30)]:
        check(counts[cat] >= minimum, f'{cat}: {counts[cat]} (>= {minimum})')
    vents = [p for p in static if p['c'] == 'anima']
    check(all(p.get('i', '').startswith('T_Icon_Rune_') for p in vents), 'anima vents have rune icons')
    geysers = [p for p in static if p['c'] == 'geyser']
    check(all(not p['n'].startswith('BP_OreNode') for p in geysers), 'geysers not swallowed by ore category')

    # 细分: 键是英文名, 中文名在 names.json (优先游戏官方译名)
    names = load('names.json')
    zh = names['subs']
    subs = {}
    for p in static:
        if p.get('s'):
            subs.setdefault(p['c'], Counter())[p['s']] += 1
    runes = {s: zh.get(s) for s in subs.get('anima', {})}
    check(len(runes) == 7 and runes.get('Law Rune') == '法则符文', f'anima split by rune (official names): {runes}')
    for cat, expect in [('gather', {'Onion': '洋葱', 'Anima-infused Bark': '灵蕴树皮', 'Stone': '石头'}),
                        ('ore', {'Mithril Ore': '秘银矿', 'Iron Ore': '铁矿石', 'Coal': '煤', 'Rune Essence': '符文精粹'}),
                        ('stone', {'Sandstone': '砂石', 'Granite': '花岗岩'}),
                        ('chest', {'Chest T6': '野外宝箱 T6', 'Buried Chest T7': '埋藏宝箱 T7'}),
                        ('fishing', {'Net · Fellhollow': '网捕 · 沉落谷', 'Rod · Brynmoor': '钓竿 · 布林莫尔'}),
                        ('teleporter', {'Vault Entrance': '穹殿入口'})]:
        got = {s: zh.get(s) for s in subs.get(cat, {}) if s in expect}
        check(got == expect, f'{cat} sub-categories {expect}' + ('' if got == expect else f' (got {got})'))
    for cat, c in subs.items():
        other = c.get('Other', 0)
        check(other <= sum(c.values()) * 0.02, f'{cat}: {len(c)} sub-categories, {other} unmatched')
    spawn = subs.get('spawn', Counter())
    translated = sum(n for s, n in spawn.items() if zh.get(s, s) != s)
    check(translated >= 0.95 * sum(spawn.values()),
          f'monster spawns with official Chinese names: {translated}/{sum(spawn.values())}')
    check(names['icons'].get('T_Icon_Rune_Law') == ['Law Rune', '法则符文'], 'official item names by icon in names.json')
    cats_json = load('categories.json')
    check(all(c.get('en') and c['en'] != c['label'] or c['id'] == 'npc' for c in cats_json),
          'every category has an English label')

    dyn = load('pois.json')['worlds'].get('L_World', [])
    names = [p['n'] for p in dyn]
    check('BP_BaseBuilding_Bed_C' in names, 'player-built bed recorded by live scan')
    # 游戏运行时生成的采集物: 按类名自动得到官方名称和图标, 不落到 "其他"
    live_gather = {p['n']: p for p in dyn if p['c'] == 'gather'}
    cab, pot = live_gather.get('BP_Spawner_Cabbage_C', {}), live_gather.get('BP_Spawner_Potato_C', {})
    check(cab.get('s') == 'Cabbage' and zh.get('Cabbage') == '卷心菜' and pot.get('s') == 'Potato' and zh.get('Potato') == '土豆',
          f'runtime gatherables named from the game: {cab.get("s")} / {pot.get("s")}')
    check('Cabbage' in cab.get('i', ''), f'runtime gatherable gets a matching icon: {cab.get("i")}')
    check(all(p.get('s') not in (None, 'Other') for p in live_gather.values()),
          f'no runtime gatherable left unnamed: {[(p["n"], p.get("s")) for p in live_gather.values()]}')
    check('BP_AnimaVent_C' not in names, 'live-scanned vent deduplicated against full-map data')

    exported = set(load('icons.json'))
    cats = load('categories.json')
    needed = {p['i'] for p in static if p.get('i')} | {c['icon'] for c in cats} | {'T_NavIcons_Player_Self'}
    missing = sorted(needed - exported)
    check(not missing, f'all {len(needed)} needed icons are pre-extracted' + (f' (missing {missing[:5]})' if missing else ''))
    hidden = {c['id'] for c in cats if c['hidden']}
    check({'stone', 'gather', 'spawn', 'creature'} <= hidden, f'noisy categories hidden by default: {sorted(hidden)}')

    live = load('live.json')
    check(live['world'] == 'L_World' and live['players'] and live['players'][0]['me'], 'live.json has local player')
    check(live.get('staticVersion', 0) > 0, 'live.json announces full-map data')
    marker_names = [m['n'] for m in live.get('markers', [])]
    check('T_NavIcons_QuestMarker' in marker_names, 'game map markers are sent live')
    check(not any('Friend' in n for n in marker_names), 'teammate arrows are not treated as map markers')
    check(not any(p['c'] == 'landmark' for p in dyn), 'map markers are not persisted (old saved ones purged)')

    maps = load('maps_L_World.json')
    for m in maps:
        check(os.path.exists(os.path.join(mod, 'web', m['image'])), f'map image present: {m["image"]}')


def test_page(mod):
    print('[web page]')
    node = shutil.which('node')
    if not node:
        print('  skip (node not found)')
        return
    html = open(os.path.join(mod, 'web', 'index.html'), encoding='utf-8').read()
    js = html[html.index('<script>') + 8:html.index('</script>')]
    with tempfile.NamedTemporaryFile('w', suffix='.js', delete=False, encoding='utf-8') as f:
        f.write(js)
    r = subprocess.run([node, '--check', f.name], capture_output=True, text=True)
    os.unlink(f.name)
    check(r.returncode == 0, 'index.html script parses ' + r.stderr.strip()[:300])


def test_server(mod):
    print('[server.ps1]')
    ps = shutil.which('pwsh') or shutil.which('powershell')
    if not ps:
        print('  skip (PowerShell not found)')
        return
    path = os.path.join(mod, 'server.ps1').replace("'", "''")
    cmd = ("$e=$null; [System.Management.Automation.Language.Parser]::ParseFile('" + path +
           "',[ref]$null,[ref]$e) | Out-Null; if ($e.Count) { $e | ForEach-Object { $_.Message }; exit 1 }")
    r = subprocess.run([ps, '-NoProfile', '-Command', cmd], capture_output=True, text=True)
    check(r.returncode == 0, 'server.ps1 parses ' + r.stdout.strip()[:300])


def main():
    tmp = tempfile.mkdtemp(prefix='livemap-test-')
    try:
        mod = stage(os.path.join(tmp, 'LiveMap'))
        print('[package]')
        files = [f for _dp, _dn, fn in os.walk(mod) for f in fn]
        exe = [f for f in files if f.lower().endswith(('.exe', '.dll', '.bat', '.cmd', '.com', '.msi', '.scr', '.vbs'))]
        check(not exe and not os.path.exists(os.path.join(mod, 'tools')),
              f'mod package has no executables or tools ({len(files)} files)' + (f': {exe}' if exe else ''))
        test_compile(mod)
        test_runtime(mod)
        test_page(mod)
        test_server(mod)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    print(f'\n{len(failures)} failure(s)' if failures else '\nall tests passed')
    sys.exit(1 if failures else 0)


if __name__ == '__main__':
    main()
