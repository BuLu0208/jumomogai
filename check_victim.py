import zipfile, plistlib, os, sys

zf = zipfile.ZipFile('Victim/InstallerVictim.ipa')
names = zf.namelist()

for n in names:
    if '/Info.plist' in n and 'Payload/' in n and 'Frameworks/' not in n and '.bundle/' not in n:
        raw = zf.read(n)
        d = plistlib.loads(raw)
        print(f"File: {n}")
        print(f"BundleID: {d.get('CFBundleIdentifier')}")
        print(f"Binary: {d.get('CFBundleExecutable')}")
        print(f"Version: {d.get('CFBundleShortVersionString')}")
        print(f"Build: {d.get('CFBundleVersion')}")
        parts = n.split('/')
        if len(parts) >= 2:
            print(f"App Dir: {parts[1]}")
        break

payload_files = [n for n in names if n.startswith('Payload/')]
dirs = list(set('/'.join(n.split('/')[:2]) for n in payload_files))
for d2 in sorted(dirs):
    print(f"  Payload: {d2}")
