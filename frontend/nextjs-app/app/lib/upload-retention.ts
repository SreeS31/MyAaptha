import type {UploadLevel} from './api';
export const UPLOAD_EXPIRY_OPTIONS=[
 {days:1,label:'1 day'},{days:7,label:'7 days'},{days:30,label:'30 days'},
 {days:60,label:'60 days'},{days:90,label:'90 days'},{days:180,label:'180 days'},
 {days:365,label:'1 year (365 days)'},{days:730,label:'2 years (730 days)'},
 {days:1095,label:'3 years (1,095 days)'},{days:1825,label:'5 years (1,825 days)'},
 {days:3650,label:'10 years (3,650 days)'},{days:0,label:'Never'},
] as const;
export function chooseUploadRetention(_level:UploadLevel,available?:number[]):Promise<number>{
 return new Promise((resolve,reject)=>{
  const dialog=document.createElement('dialog');dialog.setAttribute('aria-labelledby','upload-lifetime-title');
  Object.assign(dialog.style,{border:'1px solid #dbe3ed',borderRadius:'18px',padding:'24px',width:'min(420px, calc(100vw - 32px))',color:'#203047',boxShadow:'0 20px 80px #20304733'});
  const title=document.createElement('h2');title.id='upload-lifetime-title';title.textContent='Keep this attachment';title.style.marginTop='0';
  const detail=document.createElement('p');detail.textContent='Choose when this file expires. Never keeps it until you delete it. Expiring files stop downloading at the deadline and are queued for deletion. Downloaded copies are not affected.';
  const label=document.createElement('label');label.textContent='Delete after ';const select=document.createElement('select');select.setAttribute('aria-label','Attachment availability');
  for(const option of UPLOAD_EXPIRY_OPTIONS)if(!available||available.includes(option.days))select.add(new Option(option.label,String(option.days)));
  select.value='0';label.append(select);
  const actions=document.createElement('div');Object.assign(actions.style,{display:'flex',gap:'12px',justifyContent:'flex-end',marginTop:'20px'});
  const cancel=document.createElement('button');cancel.textContent='Cancel';const save=document.createElement('button');save.textContent='Continue upload';actions.append(cancel,save);
  let finished=false;
  const close=()=>{dialog.close();dialog.remove();};
  const abort=()=>{if(finished)return;finished=true;close();reject(new Error('Upload cancelled.'));};
  cancel.onclick=abort;dialog.oncancel=e=>{e.preventDefault();abort();};
  save.onclick=()=>{if(finished||!select.value)return;finished=true;const days=Number(select.value);close();resolve(days);};
  dialog.append(title,detail,label,actions);document.body.append(dialog);dialog.showModal();select.focus();
 });
}
