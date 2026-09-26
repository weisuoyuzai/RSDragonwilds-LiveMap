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
    check(all(p.get('i', '').startswith('T_Icon_Rune_') and p.get('l', '').endswith('符文') for p in vents),
          'anima vents have rune icon + label')
    geysers = [p for p in static if p['c'] == 'geyser']
    check(all(not p['n'].startswith('BP_OreNode') for p in geysers), 'geysers not swallowed by ore category')

    dyn = load('pois.json')['worlds'].get('L_World', [])
    names = [p['n'] for p in dyn]
    check('BP_BaseBuilding_Bed_C' in names, 'player-built bed recorded by live scan')
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
