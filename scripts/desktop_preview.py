"""Build/verify the explicit automatic beta profile. Never launches a GUI."""
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
BUNDLE_ID = 'devyashtanwar.whatsapp-blur-auto-beta'
APP_NAME = 'WhatsApp Blur Automatic Beta.app'
SCREEN_USAGE = 'Locally blur authenticated WhatsApp windows automatically. No audio, saving, telemetry or network access.'
# Swift manifests are executable code, not a safely parseable dependency-list format.
# Any graph/source mapping change must be reviewed before updating this pin.
APPROVED_MANIFEST = '34ccd98d7e35602d4a2ef906049d2ecad58d65051aa884eb6cfe9fb549b6a83b'
REQUIRED_POLICY = dict(schemaVersion=2, bundleIdentifier=BUNDLE_ID,
    entitlements={'com.apple.security.app-sandbox': True},
    forbiddenCapabilities=[v for v in CAPABILITIES if v not in {'screen-capture', 'persistent-settings'}],
    allowedResources=['capability-policy.json', 'source-manifest.json'],
    captureScope='automatic-independent-authenticated-whatsapp-windows',
    preferenceScope='private-container-non-content-blur-preferences')

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
        if path.startswith('Sources/') and not path.startswith('Sources/GeometryAnalysis/') and path not in {'Sources/DesktopBlurPreview/IntegrationCoordinator.swift', 'Sources/DesktopPipeline/FrameProcessor.swift'} and re.search(r'\bimport\s+GeometryAnalysis\b', source):
            raise ValueError('Geometry analysis is allowed only through the reviewed integration coordinator')
        if re.search(r'CG(?:Preflight|Request)ScreenCaptureAccess',source) and path != 'Sources/CaptureAdapter/ScreenPermission.swift':
            raise ValueError('Permission access outside reviewed adapter')
        if re.search(r'SCShareableContent',source) and path != 'Sources/CaptureAdapter/WhatsAppDiscovery.swift':
            raise ValueError('Catalog outside reviewed discovery')
        if re.search(r'SCContentFilter\s*\(',source) and (path != 'Sources/CaptureAdapter/AutomaticWindowCapture.swift' or re.search(r'SCContentFilter\s*\(\s*(?!desktopIndependentWindow\s*:)',source)):
            raise ValueError('Only authenticated independent-window filters permitted')
        if re.search(r'\.write\s*\(\s*to:|createFile\s*\(|createDirectory\s*\(|UserDefaults',source) and path != 'Sources/DesktopBlurPreview/PreferenceStore.swift':
            raise ValueError('Persistence outside reviewed preference store')
        patterns = SOURCE_PATTERNS + [
            r'AXUIElement|AXIsProcessTrusted|CGWindowListCreateImage|CGDisplayCreateImage|SCScreenshotManager|SCRecordingOutput',
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
APPROVED_BOOTSTRAP = {'Sources/DesktopBlurPreview/main.swift': '08104e0e72d2c40bbdd095d983fc3b2de53bab6ffdd1a31d27cdf01195f9f8ae', 'Sources/DesktopBlurPreview/RuntimeConfinement.swift': 'a5c0b38bdedae460eaa758f324f2c1f3aa80c09166d3435da32bf674fbac9f1e', 'Sources/IntegrationCore/PreviewPolicy.swift': '01946e96d9fcef9f35803c64b73b7f1b25939f518ec8a4f9bbc727ed6cbd49b0', 'Sources/CaptureAdapter/ScreenPermission.swift': '3ac9c739eda81fdedc9cf977b599261b8ce1dc35112a3f62c00178bb21f2ead6', 'Sources/CaptureAdapter/WhatsAppDiscovery.swift': '237b27104faeff5476279de510f03500622c399ee9fdd6279f83f6711d369d23', 'Sources/CaptureAdapter/AutomaticWindowCapture.swift': '04d656c45690baa36dd4d77de6ad89f5dbfb9ef2184df117a07939917f5606ee', 'Sources/DesktopBlurPreview/PreferenceStore.swift': '24898506ce39744555bd0d5143880f45f338c75c11f66e9a621a0448f0a59529'}

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
        for name in ['Package.swift', 'Sources', 'Tests', 'AdapterTests', 'GeometryTests', 'RenderTests', 'IntegrationHarness', 'PreferenceTests', 'Security']:
            inputs.append((preview / name, Path(name)))
        for name in ['IntegrationCoordinator.swift','AutomaticController.swift','TargetPresentation.swift']:
            inputs.append((preview / 'Sources/DesktopBlurPreview' / name, Path('IntegrationHarness') / name))
        inputs.append((preview / 'Sources/DesktopBlurPreview/PreferenceStore.swift', Path('PreferenceTests/PreferenceStore.swift')))
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
                if relative.suffix == '.swift' and relative.parts[0] not in {'Tests', 'AdapterTests', 'GeometryTests', 'RenderTests', 'IntegrationHarness', 'PreferenceTests'}:
                    source_map[str(relative)] = data.decode()
        validate_policy(json.loads((snapshot / 'Security/CapabilityPolicy.json').read_text()))
        audit_sources(source_map)
        audit_bootstrap(source_map)
        manifest = dict(schemaVersion=1, baseRevision=revision(repo), milestone='automatic-desktop-experimental-local-ocr', inputs=entries)
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
    if info.get('NSScreenCaptureUsageDescription') != SCREEN_USAGE: raise ValueError('Missing or changed capture explanation')
    if any((k.endswith('UsageDescription') and k != 'NSScreenCaptureUsageDescription') or k in {'CFBundleURLTypes', 'CFBundleDocumentTypes', 'NSServices', 'NSExtension'} for k in info):
        raise ValueError('Unexpected permission or handler')
    validate_policy(json.loads((app / 'Contents/Resources/capability-policy.json').read_text()))
    manifest = json.loads((app / 'Contents/Resources/source-manifest.json').read_text())
    entries = manifest.get('inputs')
    if manifest.get('milestone') != 'automatic-desktop-experimental-local-ocr' or not isinstance(entries, list) or not entries:
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
    if re.search(r'SCRecordingOutput|SCClipBufferingOutput|CGEventTapCreate', symbols):
        raise ValueError('Broad content enumeration, recording or input monitoring')
    for line in subprocess.check_output(['otool', '-L', str(binary)], text=True).splitlines()[1:]:
        if not line.strip().startswith(('/System/Library/', '/usr/lib/')): raise ValueError('Non-system preview library')
        # Vision is explicitly authorized for local OCR in this test candidate.
        if any('/' + name + '.framework/' in line for name in ['Network', 'CFNetwork']):
            raise ValueError('Forbidden network framework in capture binary')
    print('Verified automatic beta identity, sandbox-only grants, runtime, exact capture/preferences policy and sealed inputs.')

def run_tests():
    with snapshot_inputs() as (work, snapshot, _):
        # Build one reviewed immutable graph, then run only non-GUI test executables.
        subprocess.run(swift_command(work, snapshot, 'build'), check=True)
        for product in ['IntegrationTests', 'AdapterTests', 'GeometryTests', 'RenderTests', 'IntegrationHarness', 'PreferenceTests']:
            subprocess.run(swift_command(work, snapshot, 'run') + ['--skip-build', product], check=True)

def build():
    output = build_output_destination(ROOT).parent / APP_NAME
    with snapshot_inputs() as (work, snapshot, manifest):
        command = swift_command(work, snapshot, 'build') + ['-c', 'release']
        subprocess.run(command + ['--product', 'DesktopBlurPreview'], check=True)
        binaries = Path(subprocess.check_output(command + ['--show-bin-path'], text=True).strip())
        app = work / APP_NAME; contents = app / 'Contents'
        (contents / 'MacOS').mkdir(parents=True); (contents / 'Resources').mkdir()
        shutil.copy2(binaries / 'DesktopBlurPreview', contents / 'MacOS/DesktopBlurPreview')
        info = dict(CFBundleIdentifier=BUNDLE_ID, CFBundleExecutable='DesktopBlurPreview', CFBundleName='WhatsApp Blur Automatic Beta',
                    CFBundlePackageType='APPL', CFBundleVersion='1', PrivacyBuildIdentifier=manifest['baseRevision'][:12]+'-'+hashlib.sha256(json.dumps(manifest,sort_keys=True).encode()).hexdigest()[:8], LSMinimumSystemVersion='15.2', NSHighResolutionCapable=True, NSScreenCaptureUsageDescription=SCREEN_USAGE)
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
