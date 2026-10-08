"""Build the public URL query regression with independent pinned headers."""
import argparse
import json
import hashlib
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser()
parser.add_argument('--source-root', required=True, type=Path)
parser.add_argument('--runtime-root', required=True, type=Path)
parser.add_argument('--build-dir', required=True, type=Path)
parser.add_argument('--linker', required=True, type=Path)
parser.add_argument('--foundation-root', required=True, type=Path)
parser.add_argument('--query-item-root', type=Path)
args = parser.parse_args()
source = args.source_root.resolve()
runtime = args.runtime_root.resolve()
output = args.build_dir.resolve()
output.mkdir(parents=True, exist_ok=True)
component = args.foundation_root.resolve()
compile_extra = ['-I' + str(component / 'include'), '-I' + str(source / 'src/external/xnu/osfmk')]
resource = subprocess.check_output(['clang', '-print-resource-dir'], text=True).strip()
compile_flags = ['clang', '-target', 'aarch64-apple-darwin20', '-nostdinc',
                 '-isystem', resource + '/include', '-D__APPLE__', '-D__MACH__',
                 '-D_DARWIN_C_SOURCE', '-DTARGET_OS_MAC=1', '-DDARWIN', '-DDARLING',
                 '-D_LIBC_NO_FEATURE_VERIFICATION', '-fblocks', '-fobjc-arc',
                 '-Wno-nullability-completeness']
for directory in ('basic-headers',
                  'Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/include',
                  'framework-include', 'src/external/foundation/include',
                  'src/external/corefoundation/include',
                  'src/external/cocotron/CoreGraphics/include'):
    compile_flags += ['-I' + str(source / directory)]
compile_flags = compile_flags + compile_extra
linker = args.linker.resolve()
if not linker.is_file():
    raise SystemExit('a Darwin linker supporting -dylib_file is required')
link_flags = ['clang', '-target', 'aarch64-apple-darwin20', '-nostdlib',
              '-fuse-ld=' + str(linker), '-Wl,-platform_version,macos,11.0,11.0']
for path in sorted(runtime.rglob('*')):
    if path.is_file() and (path.suffix == '.dylib' or path.name + '.framework' in path.parts):
        guest = '/' + str(path.relative_to(runtime))
        link_flags += ['-Wl,-dylib_file,' + guest + ':' + str(path)]
libraries = [runtime / 'System/Library/Frameworks/Foundation.framework/Versions/C/Foundation',
             runtime / 'usr/lib/libobjc.A.dylib', runtime / 'usr/lib/libSystem.B.dylib']
commands = []

def run(command):
    command = [str(value) for value in command]
    commands.append(command)
    (output / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
    result = subprocess.run(command, capture_output=True, text=True)
    with (output / 'build.log').open('a') as log:
        log.write(result.stdout + result.stderr)
    if result.returncode:
        print(result.stderr[-6000:])
        raise SystemExit('command failed; see build.log and commands.json')

run(compile_flags + ['-MD', '-MF', output / 'test.d', '-c', component / 'test/urlcomponents-query/query.m', '-o', output / 'test.o'])
run(link_flags + ['-o', output / 'query-regression', output / 'test.o'] + libraries)

cf = source / 'src/external/corefoundation'
cf_flags = [flag for flag in compile_flags if flag != '-fobjc-arc'] + [
    '-x', 'c', '-I' + str(cf), '-I' + str(source / 'src/external/xnu/EXTERNAL_HEADERS'), '-DDEPLOYMENT_TARGET_MACOSX=1', '-DCF_BUILDING_CF',
    '-DINCLUDE_OBJC', '-D__CONSTANT_CFSTRINGS__=1', '-D__CONSTANT_STRINGS__=1',
    '-DOBJC_OLD_DISPATCH_PROTOTYPES=1', '-fconstant-cfstrings', '-fexceptions',
    '-include', cf / 'CoreFoundation_Prefix.h', '-include', cf / 'macros.h']
for filename in ('CFURLComponents.c', 'CFURLComponents_URIParser.c'):
    run(cf_flags + ['-MD', '-MF', output / (filename + '.d'), '-c', cf / filename,
                    '-o', output / (filename + '.o')])
run(link_flags + ['-dynamiclib', '-install_name', '/Volumes/SystemRoot' + str(output / 'DARQueryBackend.dylib'),
    '-o', output / 'DARQueryBackend.dylib', output / 'CFURLComponents.c.o',
    output / 'CFURLComponents_URIParser.c.o',
    runtime / 'System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation'] + libraries)

run(cf_flags + ['-c', cf / 'test/urlcomponents/query.c', '-o', output / 'backend-test.o'])
run(link_flags + ['-o', output / 'backend-regression', output / 'backend-test.o', output / 'DARQueryBackend.dylib',
    runtime / 'System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation'] + libraries)

if args.query_item_root:
    peer = args.query_item_root.resolve()
    # Compile the peer-owned implementation verbatim under a test-only class name.
    query_source = (peer / 'src/NSURL.m').read_text().split('@implementation NSURLQueryItem', 1)[1]
    (output / 'query-item.m').write_text('#import <Foundation/NSURL.h>\n#import <Foundation/NSCoder.h>\n#import <Foundation/NSException.h>\n@implementation NSURLQueryItem' + query_source)
    item_flags = [flag for flag in compile_flags if flag != '-fobjc-arc']
    item_flags = item_flags[:1] + ['-I' + str(peer / 'include')] + item_flags[1:] + ['-DNSURLQueryItem=DARTestURLQueryItem']
    run(item_flags + ['-c', output / 'query-item.m', '-o', output / 'query-item.o'])
    wrapper_flags = [flag for flag in compile_flags if flag != '-fobjc-arc']
    overlay = output / 'include/Foundation'
    overlay.mkdir(parents=True, exist_ok=True)
    (overlay / 'NSURL.h').write_text((peer / 'include/Foundation/NSURL.h').read_text())
    wrapper_flags = wrapper_flags[:1] + ['-I' + str(output / 'include')] + wrapper_flags[1:]
    wrapper_flags += ['-I' + str(cf)]
    run(wrapper_flags + ['-MD', '-MF', output / 'NSURLComponents.d', '-c', component / 'src/NSURLComponents.m', '-o', output / 'NSURLComponents.o'])
    wrapper_flags += ['-DNSURLComponents=DARTestURLComponents', '-DNSURLQueryItem=DARTestURLQueryItem']
    run(wrapper_flags + ['-c', component / 'src/NSURLComponents.m', '-o', output / 'components.o'])
    run(link_flags + ['-dynamiclib', '-install_name', '/tmp/DARQueryCandidate.dylib',
        '-o', output / 'DARQueryCandidate.dylib', output / 'query-item.o', output / 'components.o',
        output / 'CFURLComponents.c.o', output / 'CFURLComponents_URIParser.c.o',
        runtime / 'System/Library/Frameworks/CoreFoundation.framework/Versions/A/CoreFoundation'] + libraries)

roots = {'darling': source, 'foundation': component, 'corefoundation': cf,
         'swift-corelibs-foundation': cf / 'submodules/swift-corelibs-foundation'}
if args.query_item_root:
    roots['query-item'] = peer
provenance = {'runtime_root': str(runtime), 'sources': {}, 'artifacts': {}}
for name, root in roots.items():
    revision = subprocess.check_output(['git', '-C', str(root), 'rev-parse', 'HEAD'], text=True).strip()
    state = subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain', '--untracked-files=no'], text=True)
    provenance['sources'][name] = {'path': str(root), 'revision': revision, 'tracked_changes': state}
for path in output.iterdir():
    if path.is_file() and (path.suffix == '.dylib' or path.name.endswith('-regression')):
        provenance['artifacts'][path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
(output / 'PROVENANCE.json').write_text(json.dumps(provenance, indent=2) + '\n')
