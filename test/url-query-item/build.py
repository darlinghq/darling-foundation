"""Build the public query-item regression without replacing the guest Foundation.

The candidate class is renamed only in this harness. Its implementation is taken
verbatim from NSURL.m; the whole production translation unit is also compiled.
"""
import argparse
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--headers-root', required=True, type=Path)
parser.add_argument('--runtime-root', required=True, type=Path)
parser.add_argument('--linker', required=True, type=Path)
parser.add_argument('--build-dir', required=True, type=Path)
parser.add_argument('--candidate', action='store_true')
args = parser.parse_args()
foundation = Path(__file__).resolve().parents[2]
headers = args.headers_root.resolve()
runtime = args.runtime_root.resolve()
output = args.build_dir.resolve()
output.mkdir(parents=True, exist_ok=True)
resource = subprocess.check_output(['clang', '-print-resource-dir'], text=True).strip()
compile_flags = ['clang', '-target', 'aarch64-apple-darwin20', '-nostdinc',
                 '-isystem', resource + '/include', '-D__APPLE__', '-D__MACH__',
                 '-D_DARWIN_C_SOURCE', '-DTARGET_OS_MAC=1', '-DDARWIN', '-DDARLING',
                 '-D_LIBC_NO_FEATURE_VERIFICATION', '-fblocks',
                 '-Wno-nullability-completeness', '-I' + str(foundation / 'include')]
for directory in ('basic-headers',
                  'Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include',
                  'framework-include', 'src/external/corefoundation/include'):
    compile_flags += ['-I' + str(headers / directory)]
link_flags = ['clang', '-target', 'aarch64-apple-darwin20', '-nostdlib',
              '-fuse-ld=' + str(args.linker.resolve()),
              '-Wl,-platform_version,macos,11.0,11.0']
for path in sorted(runtime.rglob('*')):
    if path.is_file() and (path.suffix == '.dylib' or path.name + '.framework' in path.parts):
        guest = '/' + str(path.relative_to(runtime))
        link_flags += ['-Wl,-dylib_file,' + guest + ':' + str(path)]
libraries = [runtime / 'System/Library/Frameworks/Foundation.framework/Versions/C/Foundation',
             runtime / 'usr/lib/libobjc.A.dylib', runtime / 'usr/lib/libSystem.B.dylib']
commands = []

def run(command):
    commands.append(list(map(str, command)))
    (output / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
    result = subprocess.run(commands[-1], capture_output=True, text=True)
    with (output / 'build.log').open('a') as log:
        log.write(result.stdout + result.stderr)
    if result.returncode:
        print(result.stderr)
        raise SystemExit(result.returncode)

objects = []
if args.candidate:
    compile_flags += ['-DNSURLQueryItem=DARTestURLQueryItem']
    source = (foundation / 'src/NSURL.m').read_text()
    marker = '@implementation NSURLQueryItem\n'
    if source.count(marker) != 1:
        raise SystemExit('expected exactly one query-item implementation')
    focused = output / 'query-item-implementation.m'
    focused.write_text('#import <Foundation/NSURL.h>\n#import <Foundation/NSCoder.h>\n'
                       '#import <Foundation/NSException.h>\n' + marker + source.split(marker)[1])
    run(compile_flags + ['-MD', '-MF', output / 'implementation.d', '-c', focused,
                         '-o', output / 'implementation.o'])
    objects.append(output / 'implementation.o')
run(compile_flags + ['-MD', '-MF', output / 'test.d', '-c', foundation / 'test/url-query-item/query-item.m',
                     '-o', output / 'test.o'])
run(link_flags + ['-o', output / 'query-item', output / 'test.o'] + objects + libraries)
if args.candidate:
    full_flags = [flag for flag in compile_flags if flag != '-DNSURLQueryItem=DARTestURLQueryItem']
    full_flags += ['-DNSBUILDINGFOUNDATION=1', '-DINCLUDE_OBJC', '-DDEPLOYMENT_TARGET_MACOSX=1',
                   '-D__CONSTANT_CFSTRINGS__=1', '-D__CONSTANT_STRINGS__=1', '-DOBJC_OLD_DISPATCH_PROTOTYPES=1',
                   '-I' + str(foundation / 'src'), '-I' + str(foundation / 'include/Foundation'),
                   '-I' + str(headers / 'src/external/corefoundation'),
                   '-include', headers / 'src/external/corefoundation/CoreFoundation_Prefix.h',
                   '-include', headers / 'src/external/corefoundation/macros.h']
    run(full_flags + ['-MD', '-MF', output / 'NSURL.d', '-c', foundation / 'src/NSURL.m',
                       '-o', output / 'NSURL.o'])
