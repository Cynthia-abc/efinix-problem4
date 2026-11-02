from pathlib import Path
import hashlib
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
NS = {'e': 'http://www.efinixinc.com/enf_proj'}
project = ET.parse(ROOT / 'Ti60_Demo.xml').getroot()
missing = []
refs = project.findall('.//e:design_file', NS)
for item in refs:
    if not (ROOT / item.attrib['name']).is_file():
        missing.append(item.attrib['name'])
for key in ('sdc_file', 'default_peri_file', 'peri_file'):
    for item in project.findall(f'.//e:{key}', NS):
        if item.attrib.get('name') and not (ROOT / item.attrib['name']).is_file():
            missing.append(item.attrib['name'])
for ip in project.findall('.//e:ip', NS):
    settings = ROOT / ip.attrib['path']
    if not settings.is_file():
        missing.append(ip.attrib['path'])
    for src in ip:
        if not (settings.parent / src.attrib['name']).is_file():
            missing.append(str(settings.parent / src.attrib['name']))
if missing:
    raise SystemExit('Missing project inputs: ' + repr(missing))
release = json.loads((ROOT / 'reports/build_20261029/release.json').read_text(encoding='utf-8'))
for original, record in release['artifacts'].items():
    path = ROOT / 'bitstreams' / Path(original.replace('\\', '/')).name
    assert path.stat().st_size == record['bytes'], path
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'], path
manifest_path = ROOT / 'reports/submission_manifest.json'
if manifest_path.exists():
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    for name, digest in manifest['files_sha256'].items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
print(f'PASS: {len(refs)} project RTL entries, constraints, IP inputs, bitstream hashes and release manifest')
