import {expect,test} from '@playwright/test';
import {prepareContactReview,reviewedCircleAssignments,importCircleSuggestions,importContactBatches,parseContactCsv,parseContactVcard} from '../app/lib/contact-import';

test('Google and Outlook CSV preserve all numbers, emails, organizations and groups',()=>{
  const contacts=parseContactCsv('\uFEFFName,Phone 1 - Value,Phone 2 - Value,E-mail 1 - Value,E-mail 2 - Value,Organization 1 - Name,Group Membership\r\n"Doe, Jane",1234567,7654321,jane@example.test,jane2@example.test,Example,"Family ::: College"');
  expect(contacts).toEqual([{displayName:'Doe, Jane',phones:['1234567','7654321'],emails:['jane@example.test','jane2@example.test'],organization:'Example',groups:['Family','College']}]);
  expect(parseContactCsv('First Name,Last Name,Home Phone,Business Phone,E-mail Address\nJane,Doe,1234567,7654321,jane@example.test')[0].displayName).toBe('Jane Doe');
});
test('vCard supports folding, nameless phone contacts, UTF-8 and groups',()=>{
  const contacts=parseContactVcard('BEGIN:VCARD\r\nVERSION:3.0\r\nFN:Very long\r\n  contact name\r\nTEL;TYPE=CELL:tel:+12345678\r\nEMAIL:a@example.test\r\nCATEGORIES:Family,College\r\nEND:VCARD\r\nBEGIN:VCARD\r\nTEL:7654321\r\nEND:VCARD\r\nBEGIN:VCARD\r\nFN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:Jos=C3=A9\r\nEND:VCARD');
  expect(contacts).toHaveLength(3);expect(contacts[0].displayName).toBe('Very long contact name');expect(contacts[0].phones).toEqual(['+12345678']);expect(contacts[0].groups).toEqual(['Family','College']);expect(contacts[1].displayName).toBe('7654321');expect(contacts[2].displayName).toBe('José');
  expect(()=>parseContactCsv('Name,Phone\n"Unclosed,1234567')).toThrow(/unclosed/);
});
test('whole address books over 2000 are batched with progress and no truncation',async()=>{
  const contacts=Array.from({length:2507},(_,i)=>({displayName:`Contact ${i}`,phones:[],emails:[],organization:''}));const batches:number[]=[];let completed=0;
  const result=await importContactBatches(contacts,async batch=>{batches.push(batch.length);return{added:batch.length,updated:0,unchanged:0};},done=>{completed=done;});
  expect(result.added).toBe(2507);expect(completed).toBe(2507);expect(batches).toHaveLength(26);expect(batches.at(-1)).toBe(7);expect(Math.max(...batches)).toBe(100);
});
test('cancellation and failed batches stop further requests',async()=>{
  const contacts=Array.from({length:201},(_,i)=>({displayName:`Contact ${i}`,phones:[],emails:[],organization:''}));let calls=0;
  const result=await importContactBatches(contacts,async batch=>{calls++;return{added:batch.length,updated:0,unchanged:0};},()=>{},()=>calls===1);
  expect(result.processed).toBe(100);expect(result.cancelled).toBe(true);expect(calls).toBe(1);
  await expect(importContactBatches(contacts,async()=>{throw new Error('Unavailable');},()=>{})).rejects.toThrow('Unavailable');
});

test('review skips unusable phone rows, selects eligible rows and reuses explicit labels',()=>{
 const base={emails:[],organization:'',groups:[]};
 const review=prepareContactReview([{...base,displayName:'Skip',phones:['bad','123']},{...base,displayName:'Sree INCOIS',phones:['bad','+91 (98765) 43210'],emails:['bad','sree@example.test']},{...base,displayName:'Person',phones:['7654321'],groups:['Inter']}],['incois']);
 expect(review.skipped).toBe(1);expect(review.contacts.every(c=>c.selected)).toBe(true);
 expect(review.contacts[0].phones).toEqual(['+919876543210']);expect(review.contacts[0].emails).toEqual(['sree@example.test']);expect(review.contacts[0].circleNames).toEqual(['incois']);expect(review.contacts[1].circleNames).toEqual([]);
});

test('new circle suggestions require six distinct usable contacts; existing names are reused',()=>{
 const rows=Array.from({length:6},(_,i)=>({displayName:`Person ${i}`,phones:[`+91987654321${i}`],emails:[],organization:'',groups:['Work','Friends','Tiny']}));
 rows[5].groups=['Work','Friends'];
 const review=prepareContactReview(rows,['friends']);
 expect(review.suggestions).toEqual([{name:'friends',existing:true,count:6,eligible:true},{name:'Work',existing:false,count:6,eligible:true}]);
 expect(review.contacts[0].circleNames).toEqual(['Work','friends']);
 const selected=review.contacts.map((c,i)=>({...c,selected:i<5}));
 expect(importCircleSuggestions(selected,['friends']).find(g=>g.name==='Work')?.eligible).toBe(false);
 expect(reviewedCircleAssignments(selected,['friends']).every(c=>c.circleNames.join()==='friends')).toBe(true);
 expect(prepareContactReview([...rows.slice(0,5),rows[0]]).suggestions).toEqual([]);
});
