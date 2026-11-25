// Chat text stays in the browser. Only reviewed names are passed to the tree API.
export function whatsappMemberNames(text:string,kind:'members'|'chat'):string[]{
 if(text.length>5_000_000)throw new Error('Use a text file smaller than 5 MB.');
 const names=new Map<string,string>();
 for(const raw of text.split(/\r?\n/)){
  const line=raw.replace(/[\u200e\u200f\u202a-\u202e\u2066-\u2069]/g,'').trim();
  let name=line;
  if(kind==='chat'){
   // Android: 25/11/2026, 10:30 - Name: ...; iOS: [25/11/2026, 10:30:00] Name: ...
   const match=line.match(/^(?:\[\d{1,4}[/.\-]\d{1,2}[/.\-]\d{1,4},?\s+\d{1,2}:\d{2}(?::\d{2})?(?:\s*[APap][Mm])?\]\s*|\d{1,4}[/.\-]\d{1,2}[/.\-]\d{1,4},?\s+\d{1,2}:\d{2}(?::\d{2})?(?:\s*[APap][Mm])?\s+-\s+)([^:\n]{1,200}):(?:\s|$)/);
   if(!match)continue;
   name=match[1];
  }
  name=name.trim();
  if(!name||name.length>200)continue;
  const key=name.normalize('NFKC').toLocaleLowerCase();
  if(!names.has(key))names.set(key,name);
 }
 return Array.from(names.values());
}

export function whatsappGroupName(filename:string){
 return filename.replace(/\.txt$/i,'').replace(/^WhatsApp Chat (?:with|-)\s*/i,'').slice(0,200).trim();
}
