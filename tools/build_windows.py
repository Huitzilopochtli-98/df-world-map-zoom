"""Build against matched DFHack headers and import libraries from the installed DLLs."""
from pathlib import Path
import os, re, subprocess, sys, argparse, hashlib, json, shutil

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--dfhack-source',type=Path,required=True)
parser.add_argument('--hack-path',type=Path,required=True,help='Directory containing dfhack.dll and lua53.dll')
parser.add_argument('--msvc-root',type=Path,help='Optional portable MSVC/Windows SDK root; otherwise use an x64 developer shell')
parser.add_argument('--build-dir',type=Path,default=Path.cwd()/'work/worldmap-zoom-build')
args=parser.parse_args()
project=Path(__file__).resolve().parents[1]
root=args.dfhack_source.resolve()
compat=json.loads((project/'compatibility.json').read_text())
for repo,expected in ((root,compat['dfhackCommit']),(root/'library/xml',compat['structuresCommit'])):
    actual=subprocess.check_output(['git','-c','safe.directory='+repo.as_posix(),'rev-parse','HEAD'],cwd=repo,text=True).strip()
    if actual!=expected: raise SystemExit('Source commit does not match the tested release: '+str(repo))
if not (root/'library/include/df/renderer_2d.h').exists():
    raise SystemExit('Generate matched df-structures headers with codegen.pl before building; see README.md.')
env = os.environ.copy()
if args.msvc_root:
    msvc = args.msvc_root.resolve()
    versions=sorted(p for p in (msvc/'VC/Tools/MSVC').iterdir() if p.is_dir() and p.name.startswith('14.44.'))
    if not versions:raise SystemExit('Use the tested MSVC 14.44 toolchain.')
    vc = versions[-1]
    sdk = msvc / 'Windows Kits/10'
    sdkver = sorted(p.name for p in (sdk/'Include').iterdir() if p.is_dir())[-1]
    binpath = vc / 'bin/Hostx64/x64'
    env['PATH'] = str(binpath) + ';' + env['PATH']
    env['INCLUDE'] = ';'.join(map(str, [vc/'include', sdk/'Include'/sdkver/'ucrt', sdk/'Include'/sdkver/'shared', sdk/'Include'/sdkver/'um']))
    env['LIB'] = ';'.join(map(str, [vc/'lib/x64', sdk/'Lib'/sdkver/'ucrt/x64', sdk/'Lib'/sdkver/'um/x64']))
else:
    compiler = shutil.which('cl.exe')
    if (not compiler or not os.environ.get('VCToolsVersion','').startswith('14.44.') or
            env.get('VSCMD_ARG_TGT_ARCH','').lower() != 'x64' or
            not env.get('INCLUDE') or not env.get('LIB')):
        raise SystemExit('Use an x64 VS developer shell initialized with -vcvars_ver=14.44, or pass --msvc-root.')
    binpath = Path(compiler).parent
build = args.build_dir.resolve()
build.mkdir(parents=True,exist_ok=True)
hack = args.hack_path.resolve()
if hashlib.sha256((hack/'dfhack.dll').read_bytes()).hexdigest().upper()!=compat['dfhackSha256']:
    raise SystemExit('The DFHack DLL differs from the tested release; do not build against an unmatched ABI.')

def run(args):
    subprocess.run([str(x) for x in args], cwd=build, env=env, check=True)

# Link.exe accepts exported symbols as import entries; the DATA marker is
# required for exported globals. Classify exported addresses via PE sections.
import struct
def imports(dll):
    data = dll.read_bytes()
    nt = struct.unpack_from('<I', data, 0x3c)[0]
    nsections = struct.unpack_from('<H', data, nt + 6)[0]
    optsize = struct.unpack_from('<H', data, nt + 20)[0]
    opt = nt + 24
    sections = []
    for i in range(nsections):
        off = opt + optsize + i * 40
        size, rva, rawsize, raw = struct.unpack_from('<IIII', data, off + 8)
        flags = struct.unpack_from('<I', data, off + 36)[0]
        sections.append((rva, max(size, rawsize), raw, flags))
    def offset(rva):
        for start, size, raw, _ in sections:
            if start <= rva < start + size: return raw + rva - start
        raise ValueError(rva)
    erva = struct.unpack_from('<I', data, opt + 112)[0]
    ed = offset(erva)
    nfunc, nname, func, names, ords = struct.unpack_from('<IIIII', data, ed + 20)
    lines = ['LIBRARY ' + dll.name, 'EXPORTS']
    for i in range(nname):
        nameoff = offset(struct.unpack_from('<I', data, offset(names) + i * 4)[0])
        name = data[nameoff:data.index(b'\0', nameoff)].decode('ascii')
        ordinal = struct.unpack_from('<H', data, offset(ords) + i * 2)[0]
        addr = struct.unpack_from('<I', data, offset(func) + ordinal * 4)[0]
        flags = next((fl for st, sz, _, fl in sections if st <= addr < st + sz), 0)
        lines.append(name + ('' if flags & 0x20000000 else ' DATA'))
    deffile = build / (dll.stem + '.def')
    deffile.write_text('\n'.join(lines))
    libfile = build / (dll.stem + '.lib')
    run([binpath/'lib.exe', '/nologo', '/machine:x64', '/def:' + str(deffile), '/out:' + str(libfile)])
    return libfile

libs = [imports(hack/'dfhack.dll'), imports(hack/'lua53.dll')]
(build/'git-describe.h').write_text('''#define DFHACK_GIT_DESCRIPTION "53.16-r3-0-g0bf381cc"
#define DFHACK_GIT_COMMIT "0bf381cc1615656acf756e6e67573fffca715125"
#define DFHACK_GIT_XML_COMMIT "d8ff8a6326db37c11dc4173fadcf30b56e51b42d"
#define DFHACK_GIT_XML_EXPECTED_COMMIT DFHACK_GIT_XML_COMMIT
#define DFHACK_BUILD_ID ""
#define DFHACK_GIT_XML_MATCH
#define DFHACK_GIT_TAGGED
''')
source = project / 'plugins/worldmap-zoom-render.cpp'
out = project / 'hack/plugins/worldmap-zoom-render.plug.dll'
out.parent.mkdir(parents=True, exist_ok=True)
run([binpath/'cl.exe', '/nologo', '/std:c++20', '/O2', '/MD', '/EHsc', '/vmg', '/vmm', '/bigobj',
     '/DWIN32', '/DNOMINMAX', '/DLUA_BUILD_AS_DLL', '/D_CRT_SECURE_NO_WARNINGS',
     '/DDF_VERSION="53.16"', '/DDFHACK_VERSION="53.16-r3"', '/DDFHACK_RELEASE="r3"',
     '/DDFHACK_ABI_VERSION=2', '/DDFHACK_RUN_URL=""', '/I' + str(build),
     '/wd4068', '/I' + str(root/'library/include'), '/I' + str(root/'depends/lua/include'),
     '/LD', source, root/'library/DFHackVersion.cpp', '/link', *libs, '/OUT:' + str(out)])
print(out)
