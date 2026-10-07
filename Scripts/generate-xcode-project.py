#!/usr/bin/env python3
"""Regenerate the native Xcode app target without third-party generators."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parent.parent
ids={}
def uid(key):
 ids[key]=hashlib.sha256(key.encode()).hexdigest()[:24].upper();return ids[key]
def q(v):return json.dumps(str(v))
objects=[]
def obj(key,body):
 ident=uid(key);objects.append(f'\t\t{ident} = {{ {body} }};');return ident
sources=sorted((root/'Sources/GlideMouse').rglob('*.swift'))
files=[];sourcebuild=[];resourcebuild=[]
for f in sources:
 rel=f.relative_to(root);ref=obj('file:'+str(rel),f'isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {q(f.name)}; path = {q(rel)}; sourceTree = SOURCE_ROOT;');files.append(ref)
 sourcebuild.append(obj('build:'+str(rel),f'isa = PBXBuildFile; fileRef = {ref};'))
for rel,kind in [('Sources/GlideMouse/Resources/AppIcon.png','image.png'),('Sources/GlideMouse/Resources/MouseIllustration.png','image.png'),('Sources/GlideMouse/Resources/Localizable.xcstrings','text.json.xcstrings'),('Assets/Assets.xcassets','folder.assetcatalog'),('Sources/GlideMouse/Resources/MouseGuide','folder')]:
 ref=obj('file:'+rel,f'isa = PBXFileReference; lastKnownFileType = {kind}; name = {q(Path(rel).name)}; path = {q(rel)}; sourceTree = SOURCE_ROOT;');files.append(ref)
 resourcebuild.append(obj('build:'+rel,f'isa = PBXBuildFile; fileRef = {ref};'))
product=obj('product','isa = PBXFileReference; explicitFileType = wrapper.application; path = GlideMouse.app; sourceTree = BUILT_PRODUCTS_DIR;')
products=obj('products',f'isa = PBXGroup; children = ({product},); name = Products; sourceTree = "<group>";')
group=obj('rootgroup',f'isa = PBXGroup; children = ({",".join(files+[products])},); sourceTree = "<group>";')
local=obj('localpackage','isa = XCLocalSwiftPackageReference; relativePath = ".";')
sparkle=obj('sparklepackage','isa = XCRemoteSwiftPackageReference; repositoryURL = "https://github.com/sparkle-project/Sparkle"; requirement = { kind = exactVersion; version = 2.10.0; };')
packages=[];link=[]
for name,package in [('MouseCore',local),('NativeBridge',local),('Sparkle',sparkle)]:
 dep=obj('dependency:'+name,f'isa = XCSwiftPackageProductDependency; package = {package}; productName = {name};');packages.append(dep)
 link.append(obj('link:'+name,f'isa = PBXBuildFile; productRef = {dep};'))
embed=obj('embed-sparkle',f'isa = PBXBuildFile; productRef = {packages[-1]}; settings = {{ ATTRIBUTES = (CodeSignOnCopy, RemoveHeadersOnCopy,); }};')
sourcephase=obj('sources',f'isa = PBXSourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(sourcebuild)},); runOnlyForDeploymentPostprocessing = 0;')
resourcephase=obj('resources',f'isa = PBXResourcesBuildPhase; buildActionMask = 2147483647; files = ({",".join(resourcebuild)},); runOnlyForDeploymentPostprocessing = 0;')
frameworkphase=obj('frameworks',f'isa = PBXFrameworksBuildPhase; buildActionMask = 2147483647; files = ({",".join(link)},); runOnlyForDeploymentPostprocessing = 0;')
embedphase=obj('embedphase',f'isa = PBXCopyFilesBuildPhase; buildActionMask = 2147483647; dstPath = ""; dstSubfolderSpec = 10; files = ({embed},); name = "Embed Frameworks"; runOnlyForDeploymentPostprocessing = 0;')
def configlist(prefix,base):
 configs=[]
 for name in ['Debug','Release']:
  settings=dict(base)
  settings['SWIFT_OPTIMIZATION_LEVEL']='-Onone' if name=='Debug' else '-O'
  settings['DEBUG_INFORMATION_FORMAT']='dwarf' if name=='Debug' else 'dwarf-with-dsym'
  settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS']='DEBUG' if name=='Debug' else ''
  body=' '.join(f'{k} = {q(v)};' for k,v in settings.items())
  configs.append(obj(prefix+name,f'isa = XCBuildConfiguration; name = {name}; buildSettings = {{ {body} }};'))
 return obj(prefix+'configlist',f'isa = XCConfigurationList; buildConfigurations = ({",".join(configs)},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release;')
projectconfigs=configlist('project',{'MACOSX_DEPLOYMENT_TARGET':'14.0','SDKROOT':'macosx','SWIFT_VERSION':'6.0','CLANG_ENABLE_MODULES':'YES'})
targetconfigs=configlist('app',{'PRODUCT_NAME':'GlideMouse','PRODUCT_BUNDLE_IDENTIFIER':'app.glidemouse.desktop','INFOPLIST_FILE':'Config/Info.plist','CODE_SIGN_ENTITLEMENTS':'Config/GlideMouse.entitlements','ENABLE_HARDENED_RUNTIME':'YES','ENABLE_APP_SANDBOX':'NO','CODE_SIGN_STYLE':'Automatic','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/../Frameworks','COMBINE_HIDPI_IMAGES':'YES','GENERATE_INFOPLIST_FILE':'NO','SWIFT_EMIT_LOC_STRINGS':'NO'})
target=obj('target',f'isa = PBXNativeTarget; buildConfigurationList = {targetconfigs}; buildPhases = ({sourcephase},{frameworkphase},{resourcephase},); buildRules = (); dependencies = (); name = GlideMouse; packageProductDependencies = ({",".join(packages)},); productName = GlideMouse; productReference = {product}; productType = "com.apple.product-type.application";')
project=obj('project',f'isa = PBXProject; attributes = {{ LastUpgradeCheck = 2700; }}; buildConfigurationList = {projectconfigs}; compatibilityVersion = "Xcode 14.0"; developmentRegion = en; hasScannedForEncodings = 0; knownRegions = (en, my, "zh-Hans", Base,); mainGroup = {group}; packageReferences = ({local},{sparkle},); productRefGroup = {products}; projectDirPath = ""; projectRoot = ""; targets = ({target},);')
dest=root/'GlideMouse.xcodeproj';dest.mkdir(exist_ok=True)
(dest/'project.pbxproj').write_text('// !$*UTF8*$!\n{\n archiveVersion = 1; classes = {}; objectVersion = 56; objects = {\n'+'\n'.join(objects)+f'\n }}; rootObject = {project};\n}}\n')
scheme=dest/'xcshareddata/xcschemes';scheme.mkdir(parents=True,exist_ok=True)
ref=f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="GlideMouse.app" BlueprintName="GlideMouse" ReferencedContainer="container:GlideMouse.xcodeproj"/>'
(scheme/'GlideMouse.xcscheme').write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2700" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{ref}</BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{ref}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')
print(dest)
