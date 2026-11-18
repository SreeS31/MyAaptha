import argparse,json
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
SOURCE=ROOT/'backend/spring-boot-app/src/main/resources/display-copy.json'
def outputs():
 values=json.loads(SOURCE.read_text(encoding='utf-8-sig'))
 if not values or any(not isinstance(v,str) or not v.strip() or len(v)>100 for v in values.values()):raise ValueError('Default copy must be a non-empty string of at most 100 characters')
 web='// Generated from the API display-copy.json by infrastructure/sync_display_copy.py.\nexport const displayCopy = '+json.dumps(values,ensure_ascii=True,indent=2)+' as const;\n'
 dart='// Generated from the API display-copy.json by infrastructure/sync_display_copy.py.\nabstract final class DisplayCopy {\n'+''.join('  static const '+k+' = '+json.dumps(v,ensure_ascii=True)+';\n' for k,v in values.items())+'}\n'
 return {ROOT/'frontend/nextjs-app/app/lib/display-copy.ts':web,ROOT/'mobile/flutter-app/lib/core/config/display_copy.dart':dart}
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--check',action='store_true');args=parser.parse_args()
 for path,value in outputs().items():
  if args.check:
   if not path.is_file() or path.read_text(encoding='utf-8')!=value:raise SystemExit('Display copy is out of sync: '+str(path))
  else:path.write_text(value,encoding='utf-8')
