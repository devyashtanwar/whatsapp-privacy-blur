#!/usr/bin/env python3
"""Build a synthetic-only, separately identified experiment. Never installs or launches."""
from pathlib import Path
import hashlib
import json
import plistlib
import re
import shutil
import subprocess
import tempfile
from capability_policy import SENSITIVE_SYMBOLS, SOURCE_PATTERNS
from source_snapshot import stable_bytes
from install_bundle import install_bundle, build_output_destination

ROOT = Path(__file__).resolve().parents[1]
LAB = ROOT / 'Experiments/SelectiveBlurLab'
BUNDLE_ID = 'devyashtanwar.selective-blur-lab'

def verify_lab(app):
    app = Path(app)
    allowed = {'Contents/Info.plist', 'Contents/MacOS/SelectiveBlurLab',
               'Contents/Resources/lab-source-manifest.json', 'Contents/_CodeSignature/CodeResources'}
    if app.is_symlink() or any(p.is_symlink() for p in app.rglob('*')):
        raise ValueError('Lab must not contain symlinks')
    actual = {str(p.relative_to(app)) for p in app.rglob('*') if p.is_file()}
    if actual != allowed: raise ValueError('Unexpected/missing lab bundle files')
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != BUNDLE_ID or info.get('CFBundleExecutable') != 'SelectiveBlurLab':
        raise ValueError('Incorrect lab identity')
    if any(k.endswith('UsageDescription') or k in {'CFBundleURLTypes', 'CFBundleDocumentTypes', 'NSServices', 'NSExtension'} for k in info):
        raise ValueError('Unexpected permission/handler in lab')
    subprocess.run(['codesign', '--verify', '--strict', '--all-architectures', str(app)], check=True)
    result = subprocess.run(['codesign', '-d', '--entitlements', '-', '--xml', str(app)], check=True, capture_output=True)
    ent = plistlib.loads(result.stdout)
    if set(ent) != {'com.apple.security.app-sandbox'} or ent['com.apple.security.app-sandbox'] is not True:
        raise ValueError('Lab must have only the boolean sandbox entitlement')
    signature = subprocess.run(['codesign', '-d', '--verbose=4', str(app)], check=True, capture_output=True, text=True)
    flags = re.search(r'flags=(0x[0-9a-fA-F]+)', signature.stderr)
    if flags is None or not int(flags.group(1), 16) & 0x10000: raise ValueError('Missing hardened runtime')
    binary = app / 'Contents/MacOS/SelectiveBlurLab'
    symbols = subprocess.check_output(['nm', '-u', str(binary)], text=True)
    for pattern in SENSITIVE_SYMBOLS:
        if re.search(pattern, symbols): raise ValueError('Sensitive lab API: ' + pattern)
    # The experiment must not discover or query other applications either.
    if re.search(r'AXUIElement|SCShareableContent|CGWindowListCopyWindowInfo', symbols):
        raise ValueError('External application data discovery in lab')
    for line in subprocess.check_output(['otool', '-L', str(binary)], text=True).splitlines()[1:]:
        if not line.strip().startswith(('/System/Library/', '/usr/lib/')):
            raise ValueError('Non-system lab library')
    print('Verified separate lab identity, sandbox-only grants, runtime, sealed resources and APIs.')

def main():
    if LAB.is_symlink() or LAB.resolve(strict=True) != LAB:
        raise ValueError('Redirected experiment directory')
    output = build_output_destination(ROOT).parent / 'Selective Blur Lab.app'
    workspace = ROOT / '.build'
    if workspace.is_symlink(): raise ValueError('Redirected workspace')
    workspace.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='blur-lab-', dir=workspace) as temp:
        work = Path(temp); snapshot = work / 'inputs'; snapshot.mkdir()
        inputs = []
        for name in ['Package.swift', 'Sources', 'Tests']:
            source = LAB / name
            if source.is_symlink(): raise ValueError('Symbolic lab input')
            candidates = sorted(source.rglob('*')) if source.is_dir() else [source]
            for path in candidates:
                if path.is_symlink(): raise ValueError('Symbolic lab input')
                if path.is_dir(): continue
                data, _ = stable_bytes(path)
                relative = path.relative_to(LAB); target = snapshot / relative
                target.parent.mkdir(parents=True, exist_ok=True); target.write_bytes(data)
                if path.suffix == '.swift':
                    text = data.decode()
                    patterns = SOURCE_PATTERNS + [r'NSWorkspace|AXUIElement|CGWindowList|SCShareableContent|SCStream|SCScreenshotManager']
                    if any(re.search(pattern, text) for pattern in patterns): raise ValueError('Forbidden API in lab source')
                    if path.name == 'Package.swift' and re.search(r'\.(?:package|binaryTarget|plugin|unsafeFlags)\s*\(', text):
                        raise ValueError('Lab dependencies/plugins are forbidden')
                target.chmod(0o444)
                inputs.append({'path': str(relative), 'sha256': hashlib.sha256(data).hexdigest()})
        command = ['swift', 'build', '--package-path', str(snapshot), '--scratch-path', str(work / 'build'),
                   '--cache-path', str(workspace / 'lab-cache'), '--config-path', str(workspace / 'lab-config'),
                   '--security-path', str(workspace / 'lab-security'), '-c', 'release']
        subprocess.run(command + ['--product', 'SelectiveBlurLab'], check=True)
        binaries = Path(subprocess.check_output(command + ['--show-bin-path'], text=True).strip())
        app = work / 'Selective Blur Lab.app'; contents = app / 'Contents'
        (contents / 'MacOS').mkdir(parents=True); (contents / 'Resources').mkdir()
        shutil.copy2(binaries / 'SelectiveBlurLab', contents / 'MacOS/SelectiveBlurLab')
        info = dict(CFBundleIdentifier=BUNDLE_ID, CFBundleExecutable='SelectiveBlurLab', CFBundleName='Selective Blur Lab',
                    CFBundlePackageType='APPL', CFBundleVersion='1', LSMinimumSystemVersion='13.0', NSHighResolutionCapable=True)
        (contents / 'Info.plist').write_bytes(plistlib.dumps(info))
        (contents / 'Resources/lab-source-manifest.json').write_text(json.dumps({'syntheticOnly': True, 'inputs': inputs}, indent=2))
        ent = work / 'sandbox.plist'; ent.write_bytes(plistlib.dumps({'com.apple.security.app-sandbox': True}))
        subprocess.run(['codesign', '--force', '--sign', '-', '--options', 'runtime', '--timestamp=none', '--entitlements', str(ent), str(app)], check=True)
        verify_lab(app)
        backup = install_bundle(app, output, replace=True, validator=verify_lab)
        if backup is not None:
            if backup.parent != output.parent or backup.is_symlink(): raise ValueError('Unsafe generated backup')
            shutil.rmtree(backup)
    print('Built synthetic experiment:', output)
    print('Not installed or launched. No WhatsApp integration or visual acceptance is claimed.')

if __name__ == '__main__': main()
