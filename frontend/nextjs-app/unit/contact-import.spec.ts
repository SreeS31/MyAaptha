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

test('review keeps phone, email and named contacts; only empty rows are skipped',()=>{
 const base={emails:[],organization:'',groups:[]};
 const review=prepareContactReview([{...base,displayName:'',phones:['bad','123']},{...base,displayName:'Sree INCOIS',phones:['bad','+91 (98765) 43210'],emails:['bad','sree@example.test']},{...base,displayName:'Person',phones:[],emails:['person@example.test'],groups:['Inter']}],['incois']);
 expect(review.skipped).toBe(1);expect(review.contacts.every(c=>c.selected)).toBe(true);
 expect(review.contacts[0].phones).toEqual(['+919876543210']);expect(review.contacts[0].emails).toEqual(['sree@example.test']);expect(review.contacts[0].circleNames).toEqual(['incois']);expect(review.contacts[1].circleNames).toEqual(['Inter']);
});

test('small explicit circles remain eligible and deselection excludes their contacts',()=>{
 const review=prepareContactReview([{displayName:'Asha',phones:[],emails:['asha@example.test'],organization:'Work',groups:['Friends']},{displayName:'Bala',phones:[],emails:['bala@example.test'],organization:'Work',groups:[]}],['friends']);
 expect(review.suggestions.map(c=>[c.name,c.count])).toEqual([['friends',1],['Work',2]]);
 const selected=review.contacts.map((c,i)=>({...c,selected:i===0}));
 expect(importCircleSuggestions(selected,['friends']).every(c=>c.eligible)).toBe(true);
 expect(reviewedCircleAssignments(selected,['friends'])).toHaveLength(1);
});

import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
const fixtures=JSON.parse(readFileSync(resolve(__dirname,'../../../shared/contact-import-review-fixtures.json'),'utf8'));
for(const fixture of fixtures)test(`shared contact review: ${fixture.name}`,()=>{
 const result=prepareContactReview(fixture.contacts,fixture.existing);
 expect(result.contacts).toHaveLength(fixture.expectedContacts);
 expect(Object.fromEntries(result.suggestions.map(c=>[c.name,c.count]))).toEqual(fixture.expectedCircles);
 expect(result.contacts.find(c=>c.displayName==='Unlabeled person')?.circleNames??[]).toEqual([]);
});
