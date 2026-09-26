"""Assemble the LiveMap mod (source + pre-extracted data) and build the release zips.

    python scripts/build_package.py --version v1.2.0 --tools-dir build/tools
    python scripts/build_package.py --install "<game>/RSDragonwilds/Binaries/Win64/ue4ss/Mods" [--tools-dir build/tools]

Outputs (in dist/):
    LiveMap-RSDragonwilds-<version>.zip   the mod for players (and Nexus Mods): no executables
        README.txt / 使用说明.txt
        LiveMap/                          copied into ue4ss/Mods/
    LiveMap-Tools-<version>.zip           optional, only with --tools-dir: WorldExtract.exe + UpdateWorldData.bat
        LiveMap/tools/...                 extracted into the same place as the mod
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
TOOLS_PKG = os.path.join(ROOT, 'tools', 'package')
CUE4PARSE = os.path.join(ROOT, 'external', 'CUE4Parse')

# 模组包里不允许出现的文件类型 (Nexus Mods 等不接受可执行文件)
EXECUTABLE = ('.exe', '.dll', '.bat', '.cmd', '.com', '.msi', '.scr', '.vbs')


def copy_tree(src, dst):
    for dp, _dn, fn in os.walk(src):
        rel = os.path.relpath(dp, src)
        os.makedirs(os.path.join(dst, rel), exist_ok=True)
        for f in fn:
            shutil.copy2(os.path.join(dp, f), os.path.join(dst, rel, f))


def stage(dest):
    """Build the ready-to-use LiveMap mod folder at `dest` (mod source + extracted data, no tools)."""
    if os.path.exists(dest):
        shutil.rmtree(dest)
    copy_tree(MOD_SRC, dest)
    copy_tree(DATA, dest)
    bad = [os.path.join(dp, f) for dp, _dn, fn in os.walk(dest) for f in fn if f.lower().endswith(EXECUTABLE)]
    if bad:
        sys.exit(f'executable files must not be in the mod package: {bad}')
    return dest


def stage_tools(dest, tools_dir):
    """Build the optional tools folder (LiveMap/tools) at `dest`."""
    exe = os.path.join(tools_dir, 'WorldExtract.exe')
    if not os.path.exists(exe):
        sys.exit(f'WorldExtract.exe not found in {tools_dir}')
    if os.path.exists(dest):
        shutil.rmtree(dest)
    os.makedirs(dest)
    shutil.copy2(exe, dest)
    for f in os.listdir(TOOLS_PKG):
        shutil.copy2(os.path.join(TOOLS_PKG, f), dest)
    for name in ('LICENSE', 'NOTICE'):
        src = os.path.join(CUE4PARSE, name)
        if os.path.exists(src):
            shutil.copy2(src, os.path.join(dest, f'CUE4Parse-{name}.txt'))
    return dest


def text_bytes(path):
    """Windows-friendly text: UTF-8 with BOM, CRLF line endings."""
    data = open(path, 'rb').read()
    if data.startswith(b'\xef\xbb\xbf'):
        data = data[3:]
    data = data.replace(b'\r\n', b'\n').replace(b'\n', b'\r\n')
    return b'\xef\xbb\xbf' + data


def write_zip(out, root, extra=()):
    """Zip everything under `root` (paths relative to root) plus (name, bytes) extras."""
    with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, data in extra:
            z.writestr(name, data)
        for dp, _dn, fn in os.walk(root):
            for f in sorted(fn):
                full = os.path.join(dp, f)
                rel = os.path.relpath(full, root).replace(os.sep, '/')
                if f.lower().endswith('.txt') and rel.startswith('LiveMap/tools/'):
                    z.writestr(rel, text_bytes(full))
                else:
                    z.write(full, rel)
    with zipfile.ZipFile(out) as z:
        bad = z.testzip()
        if bad:
            sys.exit(f'corrupt zip entry: {bad}')
        n = len(z.namelist())
    print(f'{out}  ({n} files, {os.path.getsize(out) / 1e6:.1f} MB)')
    return out


def build(version, tools_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    work = os.path.join(out_dir, 'stage')

    if os.path.exists(work):
        shutil.rmtree(work)
    stage(os.path.join(work, 'LiveMap'))
    readmes = [(name, text_bytes(os.path.join(PACKAGING, name))) for name in ('README.txt', '使用说明.txt')]
    write_zip(os.path.join(out_dir, f'LiveMap-RSDragonwilds-{version}.zip'), work, readmes)
    shutil.rmtree(work)

    if tools_dir:
        stage_tools(os.path.join(work, 'LiveMap', 'tools'), tools_dir)
        write_zip(os.path.join(out_dir, f'LiveMap-Tools-{version}.zip'), work)
        shutil.rmtree(work)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--version', default='dev')
    ap.add_argument('--tools-dir', help='folder containing the published WorldExtract.exe (builds the tools zip)')
    ap.add_argument('--out', default=os.path.join(ROOT, 'dist'))
    ap.add_argument('--install', metavar='MODS_DIR', help='copy the assembled mod (and tools) into ue4ss/Mods instead of zipping')
    a = ap.parse_args()
    if a.install:
        dest = os.path.join(a.install, 'LiveMap')
        tmp = os.path.join(a.out, 'install-stage')
        stage(tmp)
        if a.tools_dir:
            stage_tools(os.path.join(tmp, 'tools'), a.tools_dir)
        copy_tree(tmp, dest)          # 合并复制: 保留游戏里已生成的记录/缓存
        shutil.rmtree(tmp)
        print(f'installed to {dest}')
    else:
        build(a.version, a.tools_dir, a.out)


if __name__ == '__main__':
    main()
