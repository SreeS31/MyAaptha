import {test as base,expect,APIRequestContext,APIResponse} from '@playwright/test';

// Synthetic accounts share one preview IP. Respect normal server protection
// instead of disabling rate limits for the integration suite.
async function retryRateLimit(action:()=>Promise<APIResponse>):Promise<APIResponse>{
  let response=await action();
  for(let attempt=0;response.status()===429&&attempt<2;attempt++){
    const requested=Number(response.headers()['retry-after']||60);
    const seconds=Number.isFinite(requested)&&requested>0?Math.min(requested,60):60;
    await response.dispose();
    await new Promise(resolve=>setTimeout(resolve,seconds*1000));
    response=await action();
  }
  return response;
}

export const test=base.extend<{respectRateLimits:void}>({
  respectRateLimits:[async({page,playwright,request},use)=>{
    const restorers:Array<()=>void>=[],wrapped=new Set<APIRequestContext>();
    function wrap(context:APIRequestContext){
      if(wrapped.has(context))return;
      wrapped.add(context);
      for(const method of ['get','post','put','patch','delete'] as const){
        const original=context[method];
        context[method]=(url,options)=>retryRateLimit(()=>original.call(context,url,options));
        restorers.push(()=>{context[method]=original;});
      }
    }
    const originalNewContext=playwright.request.newContext.bind(playwright.request);
    playwright.request.newContext=async options=>{const context=await originalNewContext(options);wrap(context);return context;};
    wrap(request);wrap(page.request);
    // GET has no matching login handler and creates no session. Its rate-limit
    // headers let a test reserve enough auth capacity for its browser sign-in.
    const budget=await request.get('http://127.0.0.1:8080/api/auth/login');
    const remaining=Number(budget.headers()['x-ratelimit-remaining']);
    await budget.dispose();
    if(Number.isFinite(remaining)&&remaining<10)await new Promise(resolve=>setTimeout(resolve,60000));
    try{await use();}finally{
      playwright.request.newContext=originalNewContext;
      for(const restore of restorers)restore();
    }
  },{auto:true}],
});
export {expect};
