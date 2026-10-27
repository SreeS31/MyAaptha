import {test,expect} from './fixtures';
import {randomUUID} from 'node:crypto';
test('shared memory keeps its image in a circle',async({page,playwright})=>{
 const api=await playwright.request.newContext({baseURL:'http://127.0.0.1:8080'});
 const username=`memory-${randomUUID().slice(0,8)}`,password=`Secure-${randomUUID()}`;
 expect((await api.post('/api/users',{data:{username,password,phoneNumber:`+1776${String(Math.floor(Math.random()*1e10)).padStart(10,'0')}`}})).status()).toBe(200);
 const login=await api.post('/api/auth/login',{data:{identifier:username,password}});const headers={Authorization:`Bearer ${(await login.json()).accessToken}`};
 const circle=await api.post('/api/network/circles',{headers,data:{name:'Memory image check',description:'Test'}});const circleId=(await circle.json()).id;
 const image=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aK1cAAAAASUVORK5CYII=','base64');
 const post=await api.post('/api/social/posts',{headers,multipart:{caption:'A remembered moment',audience:'PUBLIC',file:{name:'memory.png',mimeType:'image/png',buffer:image}}});expect(post.status(),await post.text()).toBe(200);const postId=(await post.json()).id;
 const share=await api.post(`/api/social/posts/${postId}/share`,{headers,data:{destinationType:'CIRCLE',targetId:circleId,message:'Our memory'}});expect(share.status(),await share.text()).toBe(200);
 const messages=await api.get(`/api/network/circles/${circleId}/posts`,{headers});const shared=(await messages.json())[0];expect(shared.attachmentType).toBe('image/png');expect(shared.attachmentName).toBe('memory.png');
 const attachment=await api.get(shared.attachmentUrl,{headers});expect(attachment.status()).toBe(200);expect(await attachment.body()).toEqual(image);
 await page.goto('/auth');await page.getByLabel('Username or mobile number',{exact:true}).fill(username);await page.getByLabel('Password',{exact:true}).fill(password);await page.getByRole('button',{name:'Continue',exact:true}).click();await expect(page).toHaveURL(/dashboard/);
 await page.goto('/circles');await page.getByRole('button',{name:'Open Memory image check',exact:true}).click();await expect(page.getByRole('img',{name:'memory.png',exact:true})).toBeVisible();
 await api.dispose();
});
