/** One request at a time; paused in hidden tabs; jitter avoids synchronized bursts. */
export function startPolling(task:()=>Promise<void>,interval:number):()=>void{
  let stopped=false,running=false,timer:ReturnType<typeof setTimeout>|undefined,failures=0;
  const tick=async()=>{
    if(stopped||running)return;
    if(timer!==undefined)clearTimeout(timer);
    running=true;
    if(document.visibilityState==='visible'){
      try{await task();failures=0;}catch{failures=Math.min(failures+1,4);}
    }
    running=false;
    if(!stopped)timer=setTimeout(tick,interval*Math.pow(2,failures)*(0.9+Math.random()*0.2));
  };
  const resume=()=>{if(document.visibilityState==='visible')void tick();};
  window.addEventListener('focus',resume);
  window.addEventListener('online',resume);
  document.addEventListener('visibilitychange',resume);
  void tick();
  return()=>{stopped=true;if(timer!==undefined)clearTimeout(timer);window.removeEventListener('focus',resume);window.removeEventListener('online',resume);document.removeEventListener('visibilitychange',resume);};
}
