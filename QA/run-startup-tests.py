#!/usr/bin/env python3
"""Test real capability preflight and the exact Xcode resource build script."""
import json
import os
from pathlib import Path
import plistlib
import re
import subprocess
import tempfile

root = Path(__file__).resolve().parent.parent
source = (root / 'Planning/Services/PersistenceService.swift').read_text()
configuration = source[source.index('enum PlanningCloudConfiguration'):source.index('@Model')]
project = (root / 'Planning.xcodeproj/project.pbxproj').read_text()
script = json.loads(re.search(r'shellScript = ("(?:[^"\\]|\\.)*");', project).group(1))
with tempfile.TemporaryDirectory(prefix='planning-startup-') as tmp:
    temp = Path(tmp)
    swift = temp / 'main.swift'
    swift.write_text('import Foundation\n' + configuration + r'''
func check(_ value: [String: Any], _ expected: String?) throws {
    for format in [PropertyListSerialization.PropertyListFormat.xml, .binary] {
        let raw = try PropertyListSerialization.data(fromPropertyList: value, format: format, options: 0)
        precondition(PlanningCloudConfiguration.containerIdentifier(in: raw) == expected)
    }
}
let service = "com.apple.developer.icloud-services"
let containers = "com.apple.developer.icloud-container-identifiers"
try check([:], nil)
try check([service: ["CloudKit"]], nil)
try check([containers: ["iCloud.example"]], nil)
try check([service: ["CloudDocuments"], containers: ["iCloud.example"]], nil)
try check([service: "CloudKit", containers: ["iCloud.example"]], nil)
try check([service: ["CloudKit"], containers: ["iCloud.example"]], "iCloud.example")
try check([service: ["CloudKit"], containers: ["iCloud.other", "iCloud.com.aiplanyourday.app"]], "iCloud.com.aiplanyourday.app")
try check([service: ["CloudKit"], containers: ["iCloud.", "iCloud.*", "iCloud.$(PRODUCT_BUNDLE_IDENTIFIER)", "iCloud.bad name"]], nil)
precondition(PlanningCloudConfiguration.containerIdentifier(in: Data("bad plist".utf8)) == nil)
precondition(PlanningCloudConfiguration.containerIdentifier == nil)
print("Cloud configuration: PASS (18 XML/binary/malformed/missing-resource checks)")
''')
    subprocess.run(['swiftc', '-swift-version', '6', str(swift), '-o', str(temp / 'startup-tests')], check=True)
    subprocess.run([str(temp / 'startup-tests')], check=True)
    env = dict(os.environ, TARGET_BUILD_DIR=str(temp / 'build'), UNLOCALIZED_RESOURCES_FOLDER_PATH='Planning.app', SRCROOT=str(temp))
    entitlement = temp / 'Configured.entitlements'
    output = temp / 'build/Planning.app/PlanningCapabilities.plist'
    valid = {'com.apple.developer.icloud-services': ['CloudKit'], 'com.apple.developer.icloud-container-identifiers': ['iCloud.example']}
    def run(path, expected):
        subprocess.run(['/bin/sh', '-c', script], env=dict(env, CODE_SIGN_ENTITLEMENTS=path), check=True)
        assert plistlib.loads(output.read_bytes()) == expected
    entitlement.write_bytes(plistlib.dumps(valid))
    run(entitlement.name, valid)
    run(str(entitlement), valid)
    entitlement.write_bytes(plistlib.dumps({}))
    run(entitlement.name, {})
    entitlement.unlink()
    run(entitlement.name, {})
    run('', {})
    print('Build capability resource: PASS (relative, absolute, removed capability, missing file, unset path)')
print('Startup checks passed. Apple SDK / device crash reproduction still required.')
