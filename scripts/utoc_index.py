"""Read the directory index of an Unreal IoStore container (.utoc) and list the packaged file paths.

Only the (unencrypted) directory index is parsed - no asset data is read.

    python scripts/utoc_index.py <path/to/Game-Windows.utoc>
"""
import struct
import sys

MAGIC = b'-==--==--==--==-'
NONE = 0xFFFFFFFF


def list_files(utoc_path):
    """Return every file path in the container, e.g. 'RSDragonwilds/Content/Art/UI/Map/T_Map.uasset'."""
    d = open(utoc_path, 'rb').read()
    if d[:16] != MAGIC:
        raise ValueError('not an IoStore .utoc file')
    (hdr_size, entry_count, cblock_count, cblock_size, cm_count, cm_len, _cblock_sz,
     _dir_index_size, _partitions) = struct.unpack_from('<9I', d, 20)
    flags = d[80]
    seeds_count, = struct.unpack_from('<I', d, 84)
    no_hash_count, = struct.unpack_from('<I', d, 96)

    off = hdr_size
    off += entry_count * 12             # chunk ids
    off += entry_count * 10             # offsets and lengths
    off += seeds_count * 4              # perfect hash seeds
    off += no_hash_count * 4            # chunks without perfect hash
    off += cblock_count * cblock_size   # compression blocks
    off += cm_count * cm_len            # compression method names
    if flags & 0x4:                     # signed container
        hash_size, = struct.unpack_from('<i', d, off)
        off += 4 + hash_size * 2 + cblock_count * 20
    if flags & 0x2:
        raise ValueError('directory index is encrypted')

    pos = off

    def fstring():
        nonlocal pos
        n, = struct.unpack_from('<i', d, pos)
        pos += 4
        if n < 0:
            s = d[pos:pos - n * 2].decode('utf-16le')
            pos += -n * 2
        else:
            s = d[pos:pos + n].decode('latin-1')
            pos += n
        return s.rstrip('\0')

    mount = fstring()
    n, = struct.unpack_from('<I', d, pos); pos += 4
    dirs = [struct.unpack_from('<4I', d, pos + i * 16) for i in range(n)]; pos += n * 16
    n, = struct.unpack_from('<I', d, pos); pos += 4
    files = [struct.unpack_from('<3I', d, pos + i * 12) for i in range(n)]; pos += n * 12
    n, = struct.unpack_from('<I', d, pos); pos += 4
    strings = [fstring() for _ in range(n)]

    out = []
    stack = [(0, '')]
    while stack:
        di, prefix = stack.pop()
        name, first_child, _next_sibling, first_file = dirs[di]
        here = prefix + (strings[name] + '/' if name != NONE else '')
        f = first_file
        while f != NONE:
            fname, nxt, _ = files[f]
            out.append((mount + here + strings[fname]).replace('../../../', ''))
            f = nxt
        # 子目录按原顺序深度优先访问 (栈是后进先出, 所以反着压); 同名文件以先遇到的为准
        children = []
        c = first_child
        while c != NONE:
            children.append(c)
            c = dirs[c][2]
        stack.extend((ch, here) for ch in reversed(children))
    return out


def game_path(file_path):
    """'RSDragonwilds/Content/X/T.uasset' -> '/Game/X/T.T', plugin content -> '/<Plugin>/...'. None if not content."""
    import re
    m = re.match(r'[^/]+/Content/(.*)\.uasset$', file_path)
    if m:
        p = '/Game/' + m.group(1)
    else:
        m = re.match(r'(?:[^/]+)/Plugins/(?:.*/)?([^/]+)/Content/(.*)\.uasset$', file_path)
        if not m:
            return None
        p = '/' + m.group(1) + '/' + m.group(2)
    name = p.rsplit('/', 1)[1]
    return f'{p}.{name}'


if __name__ == '__main__':
    for path in list_files(sys.argv[1]):
        print(path)
