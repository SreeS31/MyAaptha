"""Create a portable Word handoff document using only the Python standard library."""
from pathlib import Path
from xml.sax.saxutils import escape
from zipfile import ZipFile, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parent.parent
W = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

def paragraph(text, style=None):
    prop = f'<w:pPr><w:pStyle w:val="{style}"/></w:pPr>' if style else ''
    return f'<w:p>{prop}<w:r><w:t xml:space="preserve">{escape(text)}</w:t></w:r></w:p>'

def generate(source=None):
    source = Path(source) if source else ROOT / 'docs/MYAAPTHA-DEPLOYMENT-HANDOFF.md'
    parts = []
    rows = []
    def flush_table():
        if not rows: return
        parts.append('<w:tbl><w:tblPr><w:tblStyle w:val="TableGrid"/><w:tblW w:w="9360" w:type="dxa"/></w:tblPr>')
        for index, row in enumerate(rows):
            parts.append('<w:tr>' + ('<w:trPr><w:tblHeader/></w:trPr>' if index == 0 else ''))
            for cell in row:
                parts.append('<w:tc><w:tcPr><w:tcW w:w="2340" w:type="dxa"/></w:tcPr>' + paragraph(cell) + '</w:tc>')
            parts.append('</w:tr>')
        parts.append('</w:tbl>'); rows.clear()
    for line in source.read_text(encoding='utf-8').splitlines():
        if line.startswith('|'):
            cells = [cell.strip() for cell in line.strip('|').split('|')]
            if not all(set(cell) <= {'-', ':', ' '} for cell in cells): rows.append(cells)
            continue
        flush_table()
        if not line.strip(): continue
        if line.startswith('# '): parts.append(paragraph(line[2:], 'Title'))
        elif line.startswith('## '): parts.append(paragraph(line[3:], 'Heading1'))
        else: parts.append(paragraph(line))
    flush_table()
    document = f'<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="{W}"><w:body>' + ''.join(parts) + '<w:sectPr><w:pgSz w:w="12240" w:h="15840"/><w:pgMar w:top="1080" w:right="1440" w:bottom="1080" w:left="1440"/></w:sectPr></w:body></w:document>'
    styles = f'''<?xml version="1.0" encoding="UTF-8"?><w:styles xmlns:w="{W}">
    <w:style w:type="paragraph" w:default="1" w:styleId="Normal"><w:name w:val="Normal"/><w:pPr><w:spacing w:after="120"/></w:pPr><w:rPr><w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/><w:sz w:val="21"/></w:rPr></w:style>
    <w:style w:type="paragraph" w:styleId="Title"><w:name w:val="Title"/><w:basedOn w:val="Normal"/><w:rPr><w:b/><w:sz w:val="36"/></w:rPr></w:style>
    <w:style w:type="paragraph" w:styleId="Heading1"><w:name w:val="heading 1"/><w:basedOn w:val="Normal"/><w:pPr><w:keepNext/><w:spacing w:before="240"/></w:pPr><w:rPr><w:b/><w:sz w:val="27"/></w:rPr></w:style>
    <w:style w:type="table" w:styleId="TableGrid"><w:name w:val="Table Grid"/><w:tblPr><w:tblBorders>{''.join(f'<w:{side} w:val="single" w:sz="4" w:color="B8C5D1"/>' for side in ['top','left','bottom','right','insideH','insideV'])}</w:tblBorders></w:tblPr></w:style></w:styles>'''
    target = source.with_suffix('.docx')
    with ZipFile(target, 'w', ZIP_DEFLATED) as archive:
        archive.writestr('[Content_Types].xml', '<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/><Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/></Types>')
        archive.writestr('_rels/.rels', '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>')
        archive.writestr('word/_rels/document.xml.rels', '<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>')
        archive.writestr('word/document.xml', document)
        archive.writestr('word/styles.xml', styles)
    print(target)

if __name__ == '__main__':
    import sys
    generate(sys.argv[1] if len(sys.argv)>1 else None)
