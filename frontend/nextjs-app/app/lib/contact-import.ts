export type AddressContactInput = { displayName:string; phones:string[]; emails:string[]; organization:string; groups?:string[] };
export type ReviewedContact = AddressContactInput & { selected:boolean; circleNames:string[] };
const circleKey=(value:string)=>value.trim().replace(/\s+/g,' ').toLowerCase();
export function importCircleSuggestions(contacts:ReviewedContact[],existing:string[]=[]){
  const groups=new Map<string,{name:string;existing:boolean;phones:Set<string>}>();
  for(const contact of contacts.filter(c=>c.selected))for(const raw of contact.circleNames){
    const key=circleKey(raw);if(!key)continue;
    const saved=existing.find(name=>circleKey(name)===key);
    const group=groups.get(key)||{name:saved||raw.trim(),existing:!!saved,phones:new Set<string>()};
    group.phones.add(contact.phones[0]);groups.set(key,group);
  }
  return Array.from(groups.values()).map(({phones,...group})=>({...group,count:phones.size,eligible:group.existing||phones.size>5})).sort((a,b)=>Number(b.existing)-Number(a.existing)||b.count-a.count||a.name.localeCompare(b.name));
}
export function reviewedCircleAssignments(contacts:ReviewedContact[],existing:string[]=[]){
  const allowed=new Map(importCircleSuggestions(contacts,existing).filter(g=>g.eligible).map(g=>[circleKey(g.name),g.name]));
  return contacts.filter(c=>c.selected).map(c=>({...c,circleNames:unique(c.circleNames.map(name=>allowed.get(circleKey(name))||'')).slice(0,20)}));
}
export function prepareContactReview(input:AddressContactInput[],existing:string[]=[]){
  const canonical=(value:string)=>existing.find(name=>circleKey(name)===circleKey(value))||value.trim().replace(/\s+/g,' ').slice(0,100);
  const contacts:ReviewedContact[]=[];
  for(const row of input){
    const phones=unique(row.phones.flatMap(p=>p.split(/ ::: |[;,]/)).map(p=>p.trim().replace(/^tel:/i,'').replace(/[ ()\-.]/g,'')).filter(p=>/^\+?\d{7,15}$/.test(p))).slice(0,20);
    if(!phones.length)continue;
    const words=circleKey(row.displayName).split(new RegExp('[^\\p{L}\\p{N}]+','u'));
    const matches=[...existing,'INCOIS','Inter','Padmashali'].filter(name=>{const parts=circleKey(name).split(new RegExp('[^\\p{L}\\p{N}]+','u')).filter(Boolean);return parts.length>0&&parts.every(part=>words.includes(part));});
    const names=unique([...(row.groups||[]).filter(g=>!/^\*?\s*(my contacts|all contacts)$/i.test(g)),row.organization,...matches].filter(Boolean).map(canonical)).slice(0,20);
    contacts.push({...row,displayName:row.displayName.slice(0,200),organization:row.organization.slice(0,300),phones,emails:unique(row.emails.filter(e=>/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(e.trim()))).slice(0,20),groups:(row.groups||[]).map(g=>g.slice(0,100)).slice(0,20),selected:true,circleNames:names});
  }
  const suggestions=importCircleSuggestions(contacts,existing);
  const allowed=new Set(suggestions.filter(g=>g.eligible).map(g=>circleKey(g.name)));
  return {contacts:contacts.map(c=>({...c,circleNames:c.circleNames.filter(name=>allowed.has(circleKey(name)))})),skipped:input.length-contacts.length,suggestions:suggestions.filter(g=>g.eligible)};
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
