"""Preview capture capability budget: does not access apps or screen content."""
import copy
import json
from pathlib import Path
import sys
import unittest
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from desktop_preview import validate_policy, audit_sources, audit_bootstrap

class PreviewPolicyTests(unittest.TestCase):
    def setUp(self):
        self.policy = json.loads((ROOT / 'Experiments/DesktopIntegration/Security/CapabilityPolicy.json').read_text())

    def test_exact_profile(self):
        validate_policy(self.policy)

    def test_changed_scope_or_removed_prohibition(self):
        for mutate in ('scope', 'network', 'grant', 'identity'):
            value = copy.deepcopy(self.policy)
            if mutate == 'scope': value['captureScope'] = 'display'
            elif mutate == 'network': value['forbiddenCapabilities'].remove('network')
            elif mutate == 'identity': value['bundleIdentifier'] = 'devyashtanwar.selective-blur-lab'
            else: value['entitlements']['com.apple.security.device.audio-input'] = True
            with self.subTest(mutate=mutate), self.assertRaises(ValueError): validate_policy(value)

    def test_forbidden_code_paths(self):
        for text in ['import Network', 'URLSession.shared', 'AXUIElementCreateApplication(12)',
                     'SCShareableContent.current', 'SCScreenshotManager.captureImage()',
                     'addGlobalMonitorForEvents()', 'NSPasteboard.general', 'UserDefaults.standard',
                     'SecCodeCheckValidity(code, [], nil)', 'captureMicrophone = true', 'capturesAudio = true',
                     'let output = SCRecordingOutput()', 'let p = Process()', 'VNRecognizeTextRequest()', 'RecognizeTextRequest()']:
            with self.subTest(text=text), self.assertRaises(ValueError):
                audit_sources({'Sources/Fixture.swift': text})

    def test_window_capture_and_offline_validation_allowed(self):
        audit_sources({'Sources/Fixture.swift': 'import ScreenCaptureKit\nlet stream: SCStream? = nil\nconfiguration.capturesAudio = false'})

    def test_dependencies_rejected(self):
        with self.assertRaises(ValueError):
            audit_sources({'Package.swift': '.package(url: "https://example.invalid", from: "1.0.0")'})

class PreviewBootstrapTests(unittest.TestCase):
    def bootstrap(self):
        names = ['Sources/DesktopBlurPreview/main.swift', 'Sources/DesktopBlurPreview/RuntimeConfinement.swift',
                 'Sources/IntegrationCore/PreviewPolicy.swift']
        return {name: (ROOT / 'Experiments/DesktopIntegration' / name).read_text() for name in names}

    def test_reviewed_bootstrap_passes(self):
        audit_bootstrap(self.bootstrap())

    def test_removed_guard_or_unconditional_validation_rejected(self):
        for mutate in ['guard', 'self-validation', 'policy', 'missing']:
            source = self.bootstrap()
            if mutate == 'guard':
                key = 'Sources/DesktopBlurPreview/main.swift'
                text = source[key]; start = text.index('guard confinementAllowed()'); end = text.index('let app =', start)
                source[key] = text[:start] + text[end:]
            elif mutate == 'self-validation':
                source['Sources/DesktopBlurPreview/RuntimeConfinement.swift'] = 'func confinementAllowed() -> Bool { true }'
            elif mutate == 'policy':
                source['Sources/IntegrationCore/PreviewPolicy.swift'] = 'enum PreviewPolicy { static func allows() -> Bool { true } }'
            else:
                del source['Sources/DesktopBlurPreview/main.swift']
            with self.subTest(mutate=mutate), self.assertRaises(ValueError):
                audit_bootstrap(source)

class OCRInvestigationScopeTests(unittest.TestCase):
    def test_only_the_isolated_research_source_can_request_ocr(self):
        audit_sources({'Sources/GeometryAnalysis/UIAnchorRecognition.swift': 'import Vision\nlet request = VNRecognizeTextRequest()'})
        with self.assertRaises(ValueError):
            audit_sources({'Sources/CaptureAdapter/Other.swift': 'import Vision\nlet request = VNRecognizeTextRequest()'})

    def test_local_ocr_does_not_allow_network_or_unreviewed_entrypoints(self):
        with self.assertRaises(ValueError):
            audit_sources({'Sources/GeometryAnalysis/UIAnchorRecognition.swift': 'URLSession.shared'})
        audit_sources({'Sources/DesktopBlurPreview/IntegrationCoordinator.swift': 'import GeometryAnalysis'})
        with self.assertRaises(ValueError):
            audit_sources({'Sources/CaptureAdapter/Other.swift': 'import GeometryAnalysis'})

    def test_research_dependency_cannot_enter_the_capture_graph(self):
        package = (ROOT / 'Experiments/DesktopIntegration/Package.swift').read_text()
        changed = package.replace('dependencies: ["IntegrationCore", "PrivacyCore"]', 'dependencies: ["IntegrationCore", "PrivacyCore", "GeometryAnalysis"]')
        with self.assertRaises(ValueError): audit_sources({'Package.swift': changed})

    def test_concatenated_dependency_or_source_remapping_rejected(self):
        package = (ROOT / 'Experiments/DesktopIntegration/Package.swift').read_text()
        changes = [package.replace('dependencies: ["IntegrationCore", "PrivacyCore"]',
                                   'dependencies: ["IntegrationCore", "PrivacyCore"] + ["GeometryAnalysis"]'),
                   package.replace('path: "Inputs/PrivacyCore"', 'path: "Sources/GeometryAnalysis"')]
        for changed in changes:
            with self.subTest(remapped=changed), self.assertRaises(ValueError):
                audit_sources({'Package.swift': changed})
