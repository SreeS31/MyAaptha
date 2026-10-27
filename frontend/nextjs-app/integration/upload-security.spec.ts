import {expect,test} from './fixtures';
import {randomUUID} from 'node:crypto';
import {readFileSync} from 'node:fs';
test('documents and media upload to circle chat after server scanning',async({page,playwright})=>{
 test.setTimeout(180000);
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
 const username=`uploads-${randomUUID().slice(0,8)}`,password=`Secure-${randomUUID()}`;
 expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1775${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
 const auth=await api.post('/api/auth/login',{data:{identifier:username,password}});expect(auth.status()).toBe(200);const headers={Authorization:`Bearer ${(await auth.json()).accessToken}`};
 const created=await api.post('/api/network/circles',{headers,data:{name:'Upload review',description:'Attachment verification'}});expect(created.status()).toBe(200);const id=(await created.json()).id;
 for(const [name,mimeType,buffer] of [
  ['notes.txt','application/octet-stream',Buffer.from('Ordinary text attachment')],
  ['report.pdf','application/octet-stream',Buffer.from('%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\n%%EOF')],
  ['audio.mp3','audio/mpeg',Buffer.from([73,68,51,4,0,0,0,0,0,0])],
  ['video.mp4','video/mp4',Buffer.from([0,0,0,24,102,116,121,112,105,115,111,109,0,0,0,0,105,115,111,109,109,112,52,50])],
 ] as const){const result=await api.post(`/api/network/circles/${id}/posts`,{headers,multipart:{file:{name,mimeType,buffer}}});expect(result.status(),await result.text()).toBe(200);}
 expect((await api.get('/api/admin/security',{headers})).status()).toBe(403);
 await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
 await page.goto('/circles');await page.getByRole('button',{name:'Open Upload review',exact:true}).click();
 const input=page.locator('input[type=file]').first();await expect(input).toHaveAttribute('accept',/\.docx/);await expect(input).toHaveAttribute('accept',/\.pdf/);
 await input.setInputFiles({name:'document.docx',mimeType:'application/vnd.openxmlformats-officedocument.wordprocessingml.document',buffer:readFileSync('../../.tools/upload-fixtures/document.docx')});
 await page.getByRole('button',{name:'Send message',exact:true}).click();await expect(page.getByLabel('Attachment availability')).toHaveValue('0');await page.getByLabel('Attachment availability').selectOption('days');await page.getByLabel('Days available').fill('7');const sent=page.waitForResponse(r=>r.request().method()==='POST'&&r.url().includes(`/circles/${id}/posts`));await page.getByRole('button',{name:'Continue upload',exact:true}).click();expect((await sent).status()).toBe(200);await expect(page.getByRole('link',{name:/document.docx/}).first()).toBeVisible({timeout:30000});
 await page.screenshot({path:`../../.tools/preview/secure-uploads-${test.info().project.name}.png`});
 await api.dispose();
});
