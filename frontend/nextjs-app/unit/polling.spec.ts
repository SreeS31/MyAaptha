import {expect,test} from '@playwright/test';
import {startPolling} from '../app/lib/polling';

test('focus and reconnect refresh once, avoid overlap, and stop after disposal',async()=>{
  const browser=new EventTarget();
  const documentEvents=Object.assign(new EventTarget(),{visibilityState:'visible'});
  Object.assign(globalThis,{window:browser,document:documentEvents});
  let calls=0,finish:()=>void=()=>{};
  const stop=startPolling(()=>{calls++;return new Promise<void>(resolve=>{finish=resolve;});},60000);
  try{
    expect(calls).toBe(1);
    browser.dispatchEvent(new Event('focus'));browser.dispatchEvent(new Event('online'));
    expect(calls).toBe(1);
    finish();await Promise.resolve();await Promise.resolve();
    documentEvents.visibilityState='hidden';browser.dispatchEvent(new Event('focus'));
    expect(calls).toBe(1);
    documentEvents.visibilityState='visible';documentEvents.dispatchEvent(new Event('visibilitychange'));
    expect(calls).toBe(2);
    finish();await Promise.resolve();await Promise.resolve();
    browser.dispatchEvent(new Event('online'));expect(calls).toBe(3);
    stop();finish();await Promise.resolve();
    browser.dispatchEvent(new Event('focus'));expect(calls).toBe(3);
  }finally{
    stop();finish();
    delete (globalThis as Record<string,unknown>).window;
    delete (globalThis as Record<string,unknown>).document;
  }
});
