"""Assemble the LiveMap mod (source + pre-extracted data) and build the release zip.

    python scripts/build_package.py --version v1.0.0 --tools-dir build/tools
    python scripts/build_package.py --install "<game>/RSDragonwilds/Binaries/Win64/ue4ss/Mods"   # dev install

Zip layout:
    README.txt          English guide
    使用说明.txt         Chinese guide
    LiveMap/            the mod folder, copied into ue4ss/Mods/
"""
import argparse
import os
import shutil
import sys
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD_SRC = os.path.join(ROOT, 'mod', 'LiveMap')
DATA = os.path.join(ROOT, 'data')
PACKAGING = os.path.join(ROOT, 'packaging')
CUE4PARSE = os.path.join(ROOT, 'external', 'CUE4Parse')


def copy_tree(src, dst):
    for dp, _dn, fn in os.walk(src):
        rel = os.path.relpath(dp, src)
        os.makedirs(os.path.join(dst, rel), exist_ok=True)
        for f in fn:
            shutil.copy2(os.path.join(dp, f), os.path.join(dst, rel, f))


def stage(dest, tools_dir=None):
    """Build the ready-to-use LiveMap folder at `dest` (mod source + extracted data [+ WorldExtract])."""
    if os.path.exists(dest):
        shutil.rmtree(dest)
    copy_tree(MOD_SRC, dest)
    copy_tree(DATA, dest)
    tools = os.path.join(dest, 'tools')
    os.makedirs(tools, exist_ok=True)
    if tools_dir:
        exe = os.path.join(tools_dir, 'WorldExtract.exe')
        if not os.path.exists(exe):
            sys.exit(f'WorldExtract.exe not found in {tools_dir}')
        shutil.copy2(exe, tools)
    for name in ('LICENSE', 'NOTICE'):
        src = os.path.join(CUE4PARSE, name)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(tools, f'CUE4Parse-{name}.txt'))
    return dest


def readme_bytes(path):
    """Windows-friendly text: UTF-8 with BOM, CRLF line endings."""
    data = open(path, 'rb').read()
    if data.startswith(b'\xef\xbb\xbf'):
        data = data[3:]
    data = data.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
    return b'\xef\xbb\xbf' + data


def build_zip(version, tools_dir, out_dir):
    work = os.path.join(out_dir, 'stage')
    mod = stage(os.path.join(work, 'LiveMap'), tools_dir)
    os.makedirs(out_dir, exist_ok=True)
    out = os.path.join(out_dir, f'LiveMap-RSDragonwilds-{version}.zip')
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name in ('README.txt', '使用说明.txt'):
            z.writestr(name, readme_bytes(os.path.join(PACKAGING, name)))
        for dp, _dn, fn in os.walk(mod):
            for f in sorted(fn):
                full = os.path.join(dp, f)
                z.write(full, os.path.relpath(full, work).replace(os.sep, '/'))
    shutil.rmtree(work)
    with zipfile.ZipFile(out) as z:
        bad = z.testzip()
        if bad:
            sys.exit(f'corrupt zip entry: {bad}')
        n = len(z.namelist())
    print(f'{out}  ({n} files, {os.path.getsize(out) / 1e6:.1f} MB)')
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--version', default='dev')
    ap.add_argument('--tools-dir', help='folder containing the published WorldExtract.exe')
    ap.add_argument('--out', default=os.path.join(ROOT, 'dist'))
    ap.add_argument('--install', metavar='MODS_DIR', help='copy the assembled mod into ue4ss/Mods instead of zipping')
    a = ap.parse_args()
    if a.install:
        dest = os.path.join(a.install, 'LiveMap')
        tmp = stage(os.path.join(a.out, 'install-stage'), a.tools_dir)
        copy_tree(tmp, dest)          # 合并复制: 保留游戏里已生成的记录/缓存
        shutil.rmtree(tmp)
        print(f'installed to {dest}')
    else:
        build_zip(a.version, a.tools_dir, a.out)


if __name__ == '__main__':
    main()
