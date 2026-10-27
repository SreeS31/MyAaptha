import {ApiError} from './api';

export async function waitForContactOAuth<T>(read:()=>Promise<T>, signal:AbortSignal, attempts=150):Promise<T> {
  if (!Number.isInteger(attempts) || attempts < 1) throw new Error('Invalid polling limit');
  for(let attempt=0;attempt<attempts;attempt++) {
    if(signal.aborted) throw new Error('Contact connection cancelled.');
    await new Promise<void>(resolve=>setTimeout(resolve,2000));
    if(signal.aborted) throw new Error('Contact connection cancelled.');
    try {
      const result=await read();
      if(signal.aborted) throw new Error('Contact connection cancelled.');
      return result;
    } catch(reason) {
      if(!(reason instanceof ApiError) || reason.status!==404) throw reason;
    }
  }
  throw new Error('Contact authorization timed out. Please try again. Nothing was saved.');
}
