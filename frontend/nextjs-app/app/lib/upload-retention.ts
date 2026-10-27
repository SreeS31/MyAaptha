import type {UploadLevel} from './api';
// A native modal keeps keyboard focus inside the choice and supports Escape.
export function chooseUploadRetention(level:UploadLevel):Promise<number>{
 return new Promise((resolve,reject)=>{
  const dialog=document.createElement('dialog');dialog.setAttribute('aria-labelledby','upload-lifetime-title');
  Object.assign(dialog.style,{border:'1px solid #dbe3ed',borderRadius:'18px',padding:'24px',width:'min(420px, calc(100vw - 32px))',color:'#203047',boxShadow:'0 20px 80px #20304733'});
  const title=document.createElement('h2');title.id='upload-lifetime-title';title.textContent='Keep this attachment';title.style.marginTop='0';
  const detail=document.createElement('p');detail.textContent='Choose when the server copy expires. Downloaded copies are not affected.';
  const label=document.createElement('label');label.textContent='Availability ';const select=document.createElement('select');select.setAttribute('aria-label','Attachment availability');
  if(level.allowNever)select.add(new Option('Never expire','0'));
  select.add(new Option('Choose days','days'));label.append(select);
  const days=document.createElement('input');days.type='number';days.min='1';days.max=String(level.maxRetentionDays);days.value=String(Math.min(30,level.maxRetentionDays));days.setAttribute('aria-label','Days available');days.hidden=level.allowNever;
  select.onchange=()=>{days.hidden=select.value!=='days';};
  const actions=document.createElement('div');Object.assign(actions.style,{display:'flex',gap:'12px',justifyContent:'flex-end',marginTop:'20px'});
  const cancel=document.createElement('button');cancel.textContent='Cancel';const save=document.createElement('button');save.textContent='Continue upload';save.style.background='#e2f2ed';actions.append(cancel,save);
  let finished=false;const close=()=>{dialog.close();dialog.remove();};
  const abort=()=>{if(finished)return;finished=true;close();reject(new Error('Upload cancelled.'));};
  cancel.onclick=abort;dialog.oncancel=e=>{e.preventDefault();abort();};
  save.onclick=()=>{const value=select.value==='0'?0:Number(days.value);if(select.value!=='0'&&(!days.reportValidity()||!Number.isInteger(value)))return;finished=true;close();resolve(value);};
  dialog.append(title,detail,label,days,actions);document.body.append(dialog);dialog.showModal();select.focus();
 });
}
