#!/usr/bin/env python3
"""Build only: two invented-content visibility fixtures, never launched here."""
from pathlib import Path
import hashlib,json,plistlib,shutil,subprocess,tempfile
from source_snapshot import stable_bytes
from capability_policy import SOURCE_PATTERNS,SENSITIVE_SYMBOLS
import re
ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'Experiments/DesktopIntegration'

def build():
    workspace=ROOT/'.build';workspace.mkdir(exist_ok=True)
    if workspace.is_symlink(): raise ValueError('Redirected build workspace')
    with tempfile.TemporaryDirectory(prefix='visibility-fixture-',dir=workspace) as temporary:
        work=Path(temporary);inputs=work/'inputs';inputs.mkdir()
        sources=[(BASE/'VisibilityFixture/Package.swift',Path('Package.swift')),
                 (BASE/'VisibilityFixture/Sources',Path('Sources')),
                 (BASE/'Sources/DesktopBlurPreview/TargetPresentation.swift',Path('Sources/FixtureObserver/TargetPresentation.swift')),
                 (BASE/'Sources/NativeRendering/FrameCompositor.swift',Path('Sources/NativeRendering/FrameCompositor.swift')),
                 (ROOT/'Experiments/SelectiveBlurLab/Sources/LabViews/GaussianFilter.swift',Path('Sources/NativeRendering/GaussianFilter.swift'))]
        sources += [(BASE/'Sources/IntegrationCore'/name,Path('Sources/IntegrationCore')/name) for name in ['BlurSettings.swift','RegionSnapshot.swift','VisibleRegionPolicy.swift']]
        records=[]
        for source,destination in sources:
            if source.is_symlink():raise ValueError('Symbolic fixture input')
            for path in sorted(source.rglob('*')) if source.is_dir() else [source]:
                if path.is_dir():continue
                if path.is_symlink():raise ValueError('Symbolic fixture source')
                data,_=stable_bytes(path)
                if path.suffix!='.swift' or any(re.search(p,data.decode()) for p in SOURCE_PATTERNS+[r'SCStream|SCShareableContent|SCScreenshotManager|AXUIElement']):raise ValueError('Forbidden fixture API')
                relative=destination/path.relative_to(source) if source.is_dir() else destination
                target=inputs/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data);target.chmod(0o444)
                records.append(dict(path=str(relative),sha256=hashlib.sha256(data).hexdigest()))
        command=['swift','build','--package-path',str(inputs),'--scratch-path',str(work/'build'),'-c','release']
        subprocess.run(command,check=True)
        binaries=Path(subprocess.check_output(command+['--show-bin-path'],text=True).strip())
        ent=work/'sandbox.plist';ent.write_bytes(plistlib.dumps({'com.apple.security.app-sandbox':True}))
        output=ROOT/'dist'
        if output.is_symlink() or output.resolve()!=output:raise ValueError('Redirected fixture output')
        output.mkdir(exist_ok=True)
        for product,title,bundle in [('FixtureOwner','Visibility Fixture Owner','devyashtanwar.visibility-fixture-owner'),('FixtureObserver','Visibility Fixture Observer','devyashtanwar.visibility-fixture-observer')]:
            app=work/(title+'.app');contents=app/'Contents';(contents/'MacOS').mkdir(parents=True);(contents/'Resources').mkdir()
            shutil.copyfile(binaries/product,contents/'MacOS'/product)
            (contents/'Info.plist').write_bytes(plistlib.dumps(dict(CFBundleIdentifier=bundle,CFBundleExecutable=product,CFBundleName=title,CFBundlePackageType='APPL',CFBundleVersion='1',LSMinimumSystemVersion='15.2')))
            (contents/'Resources/source-manifest.json').write_text(json.dumps(records,indent=2))
            subprocess.run(['codesign','--force','--sign','-','--options','runtime','--timestamp=none','--entitlements',str(ent),str(app)],check=True,capture_output=True)
            subprocess.run(['codesign','--verify','--strict',str(app)],check=True,capture_output=True)
            from install_bundle import install_bundle
            def validate(p):
                subprocess.run(['codesign','--verify','--strict',str(p)],check=True,capture_output=True)
                signed=plistlib.loads(subprocess.check_output(['codesign','-d','--entitlements','-','--xml',str(p)],stderr=subprocess.DEVNULL))
                if signed!={'com.apple.security.app-sandbox':True} or type(signed.get('com.apple.security.app-sandbox')) is not bool:raise ValueError('Unexpected fixture grant')
                signature=subprocess.run(['codesign','-d','--verbose=4',str(p)],check=True,capture_output=True,text=True).stderr
                flags=re.search(r'flags=(0x[0-9a-fA-F]+)',signature)
                if flags is None or not int(flags.group(1),16)&0x10000:raise ValueError('Missing fixture runtime')
                binary=p/'Contents/MacOS'/product
                symbols=subprocess.check_output(['nm','-u',str(binary)],text=True)
                if any(re.search(pattern,symbols) for pattern in SENSITIVE_SYMBOLS):raise ValueError('Forbidden fixture symbol')
                libraries=subprocess.check_output(['otool','-L',str(binary)],text=True).splitlines()[1:]
                if any(not line.strip().startswith(('/System/Library/','/usr/lib/')) for line in libraries):raise ValueError('External fixture library')
            backup=install_bundle(app,output/(title+'.app'),replace=True,validator=validate)
            if backup is not None:shutil.rmtree(backup)
            print('Built, not launched:',output/(title+'.app'))
if __name__=='__main__':build()
