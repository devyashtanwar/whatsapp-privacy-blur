"""Build/verify the separate, picker-only access checkpoint. Never launches a GUI."""
from contextlib import contextmanager
from pathlib import Path
import hashlib
import json
import plistlib
import re
import shutil
import subprocess
import tempfile
from capability_policy import CAPABILITIES, SENSITIVE_SYMBOLS, SOURCE_PATTERNS
from source_snapshot import stable_bytes, revision
from install_bundle import install_bundle, build_output_destination

ROOT = Path(__file__).resolve().parents[1]
PREVIEW = ROOT / 'Experiments/DesktopIntegration'
BUNDLE_ID = 'devyashtanwar.whatsapp-blur-preview'
APP_NAME = 'WhatsApp Blur Integration Preview.app'
# Swift manifests are executable code, not a safely parseable dependency-list format.
# Any graph/source mapping change must be reviewed before updating this pin.
APPROVED_MANIFEST = 'fdae356548024538a0dfcc0df6df58474f1d261148fef418ceb7df30da554b05'
REQUIRED_POLICY = dict(schemaVersion=1, bundleIdentifier=BUNDLE_ID,
    entitlements={'com.apple.security.app-sandbox': True},
    forbiddenCapabilities=[v for v in CAPABILITIES if v != 'screen-capture'],
    allowedResources=['capability-policy.json', 'source-manifest.json'],
    captureScope='explicit-picker-single-authenticated-whatsapp-window')

def validate_policy(document):
    if document != REQUIRED_POLICY:
        raise ValueError('Preview capture scope/capabilities differ from the reviewed budget')

def audit_sources(sources):
    for path, source in sources.items():
        if not path.endswith('.swift'): continue
        if path.endswith('Package.swift') and re.search(r'\.(?:package|binaryTarget|plugin|unsafeFlags)\s*\(', source):
            raise ValueError('Preview dependencies/plugins are forbidden')
        if path == 'Package.swift' and hashlib.sha256(source.encode()).hexdigest() != APPROVED_MANIFEST:
            raise ValueError('Unreviewed package graph or source mapping')
        research_ocr = path == 'Sources/GeometryAnalysis/UIAnchorRecognition.swift'
        if not research_ocr and re.search(r'\b(?:VNRecognizeTextRequest|RecognizeTextRequest)\b', source):
            raise ValueError('OCR is authorized only in the isolated UI-anchor investigation')
        if path.startswith('Sources/') and not path.startswith('Sources/GeometryAnalysis/') and path != 'Sources/DesktopBlurPreview/IntegrationCoordinator.swift' and re.search(r'\bimport\s+GeometryAnalysis\b', source):
            raise ValueError('Geometry analysis is allowed only through the reviewed integration coordinator')
        patterns = SOURCE_PATTERNS + [
            r'AXUIElement|AXIsProcessTrusted|CGWindowListCreateImage|CGDisplayCreateImage|SCShareableContent|SCScreenshotManager|SCRecordingOutput',
            r'\b(?:capturesAudio|captureMicrophone)\s*=\s*true',
            r'add(?:Recording|ClipBuffering|VideoEffect)Output']
        if any(re.search(pattern, source) for pattern in patterns):
            raise ValueError('Forbidden preview source API: ' + path)
        calls = re.findall(r'\bSec(?:Static)?CodeCheckValidity\s*\(', source)
        flags = re.findall(r'\bSec(?:Static)?CodeCheckValidity\s*\([^;]*?SecCSFlags\(rawValue:\s*([^)]+)\)', source, re.S)
        if len(calls) != len(flags) or any('SecCSFlags.noNetworkAccess.rawValue' not in v or 'kSecCSStrictValidate' not in v for v in flags):
            raise ValueError('Code validation must stay strict and offline: ' + path)

# Fixed, small security bootstrap; intentional changes require explicit review of these pins.
# Guardrails catch regression, not a malicious actor who can rewrite the builder itself.
APPROVED_BOOTSTRAP = {'Sources/DesktopBlurPreview/main.swift': '08104e0e72d2c40bbdd095d983fc3b2de53bab6ffdd1a31d27cdf01195f9f8ae', 'Sources/DesktopBlurPreview/RuntimeConfinement.swift': 'a5c0b38bdedae460eaa758f324f2c1f3aa80c09166d3435da32bf674fbac9f1e', 'Sources/IntegrationCore/PreviewPolicy.swift': '9f4dc1a7d38820bc71aebad5408b6e633400b5eccc7051cc14067bc0599bdd24'}

def audit_bootstrap(sources):
    for path, expected in APPROVED_BOOTSTRAP.items():
        text = sources.get(path)
        if text is None or hashlib.sha256(text.encode()).hexdigest() != expected:
            raise ValueError('Missing or modified reviewed startup gate: ' + path)

@contextmanager
def snapshot_inputs(repo=ROOT):
    repo = Path(repo).resolve(strict=True)
    preview = repo / 'Experiments/DesktopIntegration'
    workspace = repo / '.build'
    if workspace.is_symlink(): raise ValueError('Redirected workspace')
    workspace.mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='desktop-preview-', dir=workspace) as temporary:
        work = Path(temporary); snapshot = work / 'inputs'; snapshot.mkdir()
        source_map = {}
        entries = []
        inputs = []
        for name in ['Package.swift', 'Sources', 'Tests', 'AdapterTests', 'GeometryTests', 'RenderTests', 'Security']:
            inputs.append((preview / name, Path(name)))
        inputs.extend([(repo / 'Sources/PrivacyCore', Path('Inputs/PrivacyCore')),
                       (repo / 'Sources/HideWhatsApp/ProcessIdentity.swift', Path('Sources/CaptureAdapter/ProcessIdentity.swift')),
                       (repo / 'Experiments/SelectiveBlurLab/Sources/LabViews/GaussianFilter.swift', Path('Sources/NativeRendering/GaussianFilter.swift'))])
        for source, target_root in inputs:
            if source.is_symlink() or not source.exists(): raise ValueError('Missing or symbolic preview input')
            if source.resolve(strict=True) != source: raise ValueError('Redirected preview input')
            candidates = sorted(source.rglob('*')) if source.is_dir() else [source]
            for path in candidates:
                if path.is_symlink(): raise ValueError('Symbolic preview source')
                if path.is_dir(): continue
                relative = target_root / path.relative_to(source) if source.is_dir() else target_root
                if relative.suffix not in {'.swift', '.json'}: raise ValueError('Unexpected preview input')
                data, _ = stable_bytes(path)
                target = snapshot / relative; target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(data); target.chmod(0o444)
                entries.append({'source': str(path.relative_to(repo)), 'compiledPath': str(relative), 'sha256': hashlib.sha256(data).hexdigest()})
                if relative.suffix == '.swift' and relative.parts[0] not in {'Tests', 'AdapterTests', 'GeometryTests', 'RenderTests'}:
                    source_map[str(relative)] = data.decode()
        validate_policy(json.loads((snapshot / 'Security/CapabilityPolicy.json').read_text()))
        audit_sources(source_map)
        audit_bootstrap(source_map)
        manifest = dict(schemaVersion=1, baseRevision=revision(repo), milestone='native-desktop-experimental-local-ocr', inputs=entries)
        yield work, snapshot, manifest

def swift_command(work, snapshot, mode):
    return ['swift', mode, '--package-path', str(snapshot), '--scratch-path', str(work / 'build'),
            '--cache-path', str(ROOT / '.build/desktop-cache'), '--config-path', str(ROOT / '.build/desktop-config'),
            '--security-path', str(ROOT / '.build/desktop-security')]

def verify_preview(app):
    app = Path(app)
    allowed = {'Contents/Info.plist', 'Contents/MacOS/DesktopBlurPreview',
               'Contents/Resources/capability-policy.json', 'Contents/Resources/source-manifest.json',
               'Contents/_CodeSignature/CodeResources'}
    if app.is_symlink() or any(p.is_symlink() for p in app.rglob('*')): raise ValueError('Symbolic preview bundle')
    actual = {str(p.relative_to(app)) for p in app.rglob('*') if p.is_file()}
    if actual != allowed: raise ValueError('Unexpected/missing preview bundle files')
    info = plistlib.loads((app / 'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier') != BUNDLE_ID or info.get('CFBundleExecutable') != 'DesktopBlurPreview' or info.get('LSMinimumSystemVersion') != '15.2':
        raise ValueError('Incorrect preview identity/OS floor')
    if any(k.endswith('UsageDescription') or k in {'CFBundleURLTypes', 'CFBundleDocumentTypes', 'NSServices', 'NSExtension'} for k in info):
        raise ValueError('Unexpected permission or handler')
    validate_policy(json.loads((app / 'Contents/Resources/capability-policy.json').read_text()))
    manifest = json.loads((app / 'Contents/Resources/source-manifest.json').read_text())
    entries = manifest.get('inputs')
    if manifest.get('milestone') != 'native-desktop-experimental-local-ocr' or not isinstance(entries, list) or not entries:
        raise ValueError('Invalid preview provenance')
    paths = set()
    for entry in entries:
        path = entry.get('compiledPath', '')
        if not path or Path(path).is_absolute() or '..' in Path(path).parts or path in paths or not re.fullmatch('[0-9a-f]{64}', entry.get('sha256', '')):
            raise ValueError('Invalid preview input record')
        paths.add(path)
    recorded = {entry['compiledPath']: entry['sha256'] for entry in entries}
    if recorded.get('Package.swift') != APPROVED_MANIFEST:
        raise ValueError('Unreviewed runtime graph provenance')
    if any(recorded.get(path) != expected for path, expected in APPROVED_BOOTSTRAP.items()):
        raise ValueError('Unreviewed or missing startup gate provenance')
    subprocess.run(['codesign', '--verify', '--strict', '--all-architectures', str(app)], check=True, capture_output=True)
    result = subprocess.run(['codesign', '-d', '--entitlements', '-', '--xml', str(app)], check=True, capture_output=True)
    ent = plistlib.loads(result.stdout)
    if set(ent) != {'com.apple.security.app-sandbox'} or ent['com.apple.security.app-sandbox'] is not True:
        raise ValueError('Preview must have only the boolean sandbox entitlement')
    signature = subprocess.run(['codesign', '-d', '--verbose=4', str(app)], check=True, capture_output=True, text=True)
    flags = re.search(r'flags=(0x[0-9a-fA-F]+)', signature.stderr)
    if flags is None or not int(flags.group(1), 16) & 0x10000: raise ValueError('Missing hardened runtime')
    binary = app / 'Contents/MacOS/DesktopBlurPreview'
    symbols = subprocess.check_output(['nm', '-u', str(binary)], text=True)
    for required in ['_SecCodeCopySelf', '_SecCodeCheckValidity', '_SecStaticCodeCheckValidity', '_SecCodeCopySigningInformation']:
        if not re.search(r'(?m)\b' + re.escape(required) + r'$', symbols):
            raise ValueError('Missing startup validation API: ' + required)
    for pattern in SENSITIVE_SYMBOLS:
        pattern = pattern.replace('|SCStream', '') # Only this reviewed capture API is allowed here.
        if re.search(pattern, symbols): raise ValueError('Forbidden preview linked API: ' + pattern)
    if re.search(r'_OBJC_CLASS_\$_SCShareableContent\b|SCRecordingOutput|SCClipBufferingOutput|CGEventTapCreate', symbols):
        raise ValueError('Broad content enumeration, recording or input monitoring')
    for line in subprocess.check_output(['otool', '-L', str(binary)], text=True).splitlines()[1:]:
        if not line.strip().startswith(('/System/Library/', '/usr/lib/')): raise ValueError('Non-system preview library')
        # Vision is explicitly authorized for local OCR in this test candidate.
        if any('/' + name + '.framework/' in line for name in ['Network', 'CFNetwork']):
            raise ValueError('Forbidden network framework in capture binary')
    print('Verified preview identity, sandbox-only grants, runtime, selected-window policy and sealed inputs.')

def run_tests():
    with snapshot_inputs() as (work, snapshot, _):
        for product in ['IntegrationTests', 'AdapterTests', 'GeometryTests', 'RenderTests']:
            subprocess.run(swift_command(work, snapshot, 'run') + [product], check=True)

def build():
    output = build_output_destination(ROOT).parent / APP_NAME
    with snapshot_inputs() as (work, snapshot, manifest):
        command = swift_command(work, snapshot, 'build') + ['-c', 'release']
        subprocess.run(command + ['--product', 'DesktopBlurPreview'], check=True)
        binaries = Path(subprocess.check_output(command + ['--show-bin-path'], text=True).strip())
        app = work / APP_NAME; contents = app / 'Contents'
        (contents / 'MacOS').mkdir(parents=True); (contents / 'Resources').mkdir()
        shutil.copy2(binaries / 'DesktopBlurPreview', contents / 'MacOS/DesktopBlurPreview')
        info = dict(CFBundleIdentifier=BUNDLE_ID, CFBundleExecutable='DesktopBlurPreview', CFBundleName='WhatsApp Blur Integration Preview',
                    CFBundlePackageType='APPL', CFBundleVersion='1', LSMinimumSystemVersion='15.2', NSHighResolutionCapable=True)
        (contents / 'Info.plist').write_bytes(plistlib.dumps(info))
        shutil.copyfile(snapshot / 'Security/CapabilityPolicy.json', contents / 'Resources/capability-policy.json')
        (contents / 'Resources/source-manifest.json').write_text(json.dumps(manifest, indent=2))
        ent = work / 'sandbox.plist'; ent.write_bytes(plistlib.dumps({'com.apple.security.app-sandbox': True}))
        subprocess.run(['codesign', '--force', '--sign', '-', '--options', 'runtime', '--timestamp=none', '--entitlements', str(ent), str(app)], check=True)
        verify_preview(app)
        backup = install_bundle(app, output, replace=True, validator=verify_preview)
        if backup is not None:
            if backup.parent != output.parent or backup.is_symlink(): raise ValueError('Unsafe generated backup')
            shutil.rmtree(backup)
    print('Built native Desktop test candidate:', output)
    print('Not installed or launched. Experimental geometry: real WhatsApp coverage and timing require harmless manual testing.')
