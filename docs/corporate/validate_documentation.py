"""Validate static artifacts without running the application."""
from pathlib import Path
import json,re,xml.etree.ElementTree as ET
base=Path(__file__).parent
broken=[]
for p in base.glob('*.md'):
    for target in re.findall(r'\]\(([^)]+)\)',p.read_text(encoding='utf-8')):
        if target.startswith(('http:','https:','#')):continue
        if not (p.parent/target.split('#')[0]).exists():broken.append((p.name,target))
for p in (base/'diagrams').glob('*.svg'):ET.parse(p)
inventory=json.loads((base/'source-inventory.json').read_text(encoding='utf-8'))
assert len(inventory['endpoints'])==len({(x['method'],x['path']) for x in inventory['endpoints']}), 'Duplicate route mapping; inspect controller overlap'
pdf=(base/'PROJECT-HANDBOOK.pdf').read_bytes()
assert pdf.startswith(b'%PDF-'), 'Invalid PDF header'
pages=len(re.findall(rb'/Type\s*/Page\b',pdf))
assert pages>20, 'Unexpectedly short PDF'
assert not broken, broken
print(json.dumps({'broken_local_links':len(broken),'svg_files':len(list((base/'diagrams').glob('*.svg'))),'pdf_pages':pages,'pdf_bytes':len(pdf),'unique_http_mappings':len(inventory['endpoints'])}))
