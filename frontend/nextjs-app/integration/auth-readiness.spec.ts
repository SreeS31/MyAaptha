import {expect,test} from './fixtures';

test('sign-in stays disabled until client handlers are ready',async({page})=>{
  let release!:()=>void;
  const gate=new Promise<void>(resolve=>{release=resolve;});
  await page.route('**/_next/static/**/*.js',async route=>{await gate;await route.continue();});
  try{
    await page.goto('/auth',{waitUntil:'commit'});
    await expect(page.getByLabel('Username or mobile number',{exact:true})).toBeDisabled();
    await expect(page.getByRole('button',{name:'Continue',exact:true})).toBeDisabled();
    release();
    await expect(page.getByLabel('Username or mobile number',{exact:true})).toBeEnabled({timeout:30000});
    await expect(page.getByRole('button',{name:'Continue',exact:true})).toBeEnabled();
  }finally{release();await page.unroute('**/_next/static/**/*.js');}
});
