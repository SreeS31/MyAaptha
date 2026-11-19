export type AddressContactInput = { displayName:string; phones:string[]; emails:string[]; organization:string; groups?:string[] };
export type ReviewedContact = AddressContactInput & { selected:boolean; circleNames:string[] };
const circleKey=(value:string)=>value.trim().replace(/\s+/g,' ').toLowerCase();
const contactIdentity=(contact:AddressContactInput)=>JSON.stringify([circleKey(contact.displayName),[...contact.phones].sort(),contact.emails.map(circleKey).sort()]);
const meaningfulLabel=(name:string)=>!!name.trim()&&!/^\*?\s*(my contacts|all contacts|imported contacts)$/i.test(name);
export function importCircleSuggestions(contacts:ReviewedContact[],existing:string[]=[]){
  const savedNames=new Map(existing.map(name=>[circleKey(name),name]));
  const groups=new Map<string,{name:string;existing:boolean;contacts:Set<string>}>();
  for(const contact of contacts.filter(c=>c.selected))for(const raw of contact.circleNames){
    const key=circleKey(raw);if(!key)continue;
    const saved=savedNames.get(key);
    const group=groups.get(key)||{name:saved||raw.trim(),existing:!!saved,contacts:new Set<string>()};
    group.contacts.add(contactIdentity(contact));groups.set(key,group);
  }
  return Array.from(groups.values()).map(({contacts,...group})=>({...group,count:contacts.size,eligible:true})).sort((a,b)=>Number(b.existing)-Number(a.existing)||b.count-a.count||a.name.localeCompare(b.name));
}
export function reviewedCircleAssignments(contacts:ReviewedContact[],existing:string[]=[]){
  const allowed=new Map(importCircleSuggestions(contacts,existing).map(g=>[circleKey(g.name),g.name]));
  return contacts.filter(c=>c.selected).map(c=>({...c,circleNames:unique(c.circleNames.map(name=>allowed.get(circleKey(name))||'')).slice(0,20)}));
}
export function prepareContactReview(input:AddressContactInput[],existing:string[]=[]){
  const savedNames=new Map(existing.map(name=>[circleKey(name),name]));
  const canonical=(value:string)=>savedNames.get(circleKey(value))||value.trim().replace(/\s+/g,' ').slice(0,100);
  const normalized=input.map(row=>({...row,displayName:row.displayName.trim().slice(0,200),organization:row.organization.trim().slice(0,300),
    phones:unique(row.phones.flatMap(p=>p.split(/ ::: |[;,]/)).map(p=>p.trim().replace(/^tel:/i,'').replace(/[ ()\-.]/g,'')).filter(p=>/^\+?\d{7,15}$/.test(p))).slice(0,20),
    emails:unique(row.emails.map(e=>e.trim()).filter(e=>/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e))).slice(0,20)}));
  const usable=normalized.filter(row=>row.phones.length||row.emails.length||(row.displayName&&!/^unnamed contact$/i.test(row.displayName)));
  const explicit=unique([...existing,...usable.flatMap(row=>[...(row.groups||[]),row.organization])].filter(meaningfulLabel).map(canonical));
  const tags=new Map<string,{name:string;contacts:Set<string>}>();
  for(const row of usable){
    const name=row.displayName;
    const candidates=[...Array.from(name.matchAll(new RegExp('#([\\p{L}\\p{N}_-]{2,40})','gu')),m=>m[1]),...Array.from(name.matchAll(/\(([^()]{2,40})\)/g),m=>m[1]),...(name.includes(' - ')?[name.split(' - ').at(-1)!]:[])];
    if(/[a-z]/.test(name))candidates.push(...Array.from(name.matchAll(/\b[A-Z][A-Z0-9]{2,}\b/g),m=>m[0]));
    for(const raw of candidates.filter(v=>new RegExp('[\\p{L}]','u').test(v)&&meaningfulLabel(v))){const label=canonical(raw),key=circleKey(label);const tag=tags.get(key)||{name:label,contacts:new Set<string>()};tag.contacts.add(contactIdentity(row));tags.set(key,tag);}
  }
  const candidates=unique([...explicit,...Array.from(tags.values()).filter(t=>t.contacts.size>=2).map(t=>t.name)]);
  const candidateIndex=new Map<string,{name:string;parts:string[]}[]>();
  for(const name of candidates){const parts=circleKey(name).split(new RegExp('[^\\p{L}\\p{N}]+','u')).filter(Boolean);if(parts.length)candidateIndex.set(parts[0],[...(candidateIndex.get(parts[0])||[]),{name,parts}]);}
  const contacts:ReviewedContact[]=usable.map(row=>{
    const words=circleKey(row.displayName).split(new RegExp('[^\\p{L}\\p{N}]+','u')).filter(Boolean);
    const wordSet=new Set(words);
    const matches=Array.from(wordSet).flatMap(word=>candidateIndex.get(word)||[]).filter(candidate=>candidate.parts.every(part=>wordSet.has(part))).map(candidate=>candidate.name);
    const circleNames=unique([...(row.groups||[]),row.organization,...matches].filter(meaningfulLabel).map(canonical)).slice(0,20);
    return {...row,displayName:row.displayName||row.phones[0]||row.emails[0],groups:(row.groups||[]).filter(meaningfulLabel).map(g=>g.slice(0,100)).slice(0,20),selected:true,circleNames};
  });
  return {contacts,skipped:input.length-contacts.length,suggestions:importCircleSuggestions(contacts,existing)};
}
const unique=(values:string[])=>Array.from(new Set(values.map(v=>v.trim()).filter(Boolean)));

export function parseContactCsv(text:string):AddressContactInput[] {
  const rows:string[][]=[];let row:string[]=[],cell='',quoted=false;
  text=text.replace(/^\uFEFF/,'');
  for(let i=0;i<text.length;i++){
    const c=text[i];
    if(c==='"'){if(quoted&&text[i+1]==='"'){cell+='"';i++;}else quoted=!quoted;}
    else if(c===','&&!quoted){row.push(cell);cell='';}
    else if((c==='\n'||c==='\r')&&!quoted){if(c==='\r'&&text[i+1]==='\n')i++;row.push(cell);if(row.some(v=>v.trim()))rows.push(row);row=[];cell='';}
    else cell+=c;
  }
  if(quoted)throw new Error('The CSV has an unclosed quoted field. Export it again and retry.');
  row.push(cell);if(row.some(v=>v.trim()))rows.push(row);
  if(rows.length<2)return [];
  const headers=rows[0].map(v=>v.trim().toLowerCase());
  const pick=(cells:string[],names:string[])=>cells[headers.findIndex(h=>names.includes(h))]?.trim()||'';
  return rows.slice(1).map(cells=>{
    const phones=unique(cells.filter((v,i)=>/phone|mobile|tel/.test(headers[i]||'')&&!/type|label/.test(headers[i]||'')));
    const emails=unique(cells.filter((v,i)=>/e-?mail/.test(headers[i]||'')&&!/type|label/.test(headers[i]||'')));
    const full=pick(cells,['name','full name','display name']);
    const joined=[pick(cells,['first name','given name']),pick(cells,['middle name','additional name']),pick(cells,['last name','family name'])].filter(Boolean).join(' ');
    return {displayName:full||joined||phones[0]||emails[0]||'',phones,emails,organization:pick(cells,['organization name','organization 1 - name','company','organization']),groups:unique(pick(cells,['labels','categories','group membership']).split(/ ::: |[;,]/))};
  }).filter(c=>c.displayName||c.phones.length||c.emails.length);
}

function vcardValue(value:string,header:string):string {
  if(/ENCODING=QUOTED-PRINTABLE/i.test(header)){
    const bytes:number[]=[];for(let i=0;i<value.length;i++){if(value[i]==='='&&/^[0-9a-f]{2}$/i.test(value.slice(i+1,i+3))){bytes.push(parseInt(value.slice(i+1,i+3),16));i+=2;}else bytes.push(...Array.from(new TextEncoder().encode(value[i])));}
    value=new TextDecoder('utf-8').decode(new Uint8Array(bytes));
  }
  return value.replace(/\\[nN]/g,' ').replace(/\\([,;\\])/g,'$1').trim();
}
export function parseContactVcard(text:string):AddressContactInput[]{
  text=text.replace(/=\r?\n/g,'').replace(/\r?\n[ \t]/g,'');
  const result:AddressContactInput[]=[];
  for(const block of text.split(/END:VCARD/i)){
    if(!/BEGIN:VCARD/i.test(block))continue;
    let name='',structured='',organization='';const phones:string[]=[],emails:string[]=[],groups:string[]=[];
    for(const line of block.split(/\r?\n/)){
      const colon=line.indexOf(':');if(colon<0)continue;
      const header=line.slice(0,colon),key=header.split(';')[0].split('.').pop()?.toUpperCase();const value=vcardValue(line.slice(colon+1),header);
      if(key==='FN')name=value;
      if(key==='N'){const p=value.split(';');structured=[p[3],p[1],p[2],p[0],p[4]].filter(Boolean).join(' ');}
      if(key==='TEL')phones.push(value.replace(/^tel:/i,''));
      if(key==='EMAIL')emails.push(value.replace(/^mailto:/i,''));
      if(key==='ORG')organization=value.replace(/;/g,' ');
      if(key==='CATEGORIES')groups.push(...value.split(','));
    }
    const displayName=name||structured||phones[0]||emails[0]||'Unnamed contact';
    result.push({displayName,phones:unique(phones),emails:unique(emails),organization,groups:unique(groups)});
  }
  return result;
}

export async function importContactBatches<T extends {added:number;updated:number;unchanged:number}>(
  contacts:AddressContactInput[],save:(batch:AddressContactInput[])=>Promise<T>,progress:(done:number,total:number)=>void,
  cancelled:()=>boolean=()=>false,
){
  const summary={added:0,updated:0,unchanged:0,processed:0,cancelled:false};
  for(let offset=0;offset<contacts.length;offset+=100){
    if(cancelled()){summary.cancelled=true;break;}
    const batch=contacts.slice(offset,offset+100);const result=await save(batch);
    summary.added+=result.added;summary.updated+=result.updated;summary.unchanged+=result.unchanged;
    summary.processed+=batch.length;progress(summary.processed,contacts.length);
  }
  return summary;
}
