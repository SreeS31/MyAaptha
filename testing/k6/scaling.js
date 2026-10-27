import http from 'k6/http';
import {check} from 'k6';
import execution from 'k6/execution';
import {SharedArray} from 'k6/data';
import {Counter} from 'k6/metrics';
const responseStatuses = new Counter('response_statuses');
const users=new SharedArray('synthetic accounts',()=>JSON.parse(open(__ENV.ACCOUNTS_FILE||'/tests/accounts.json')));
const origins=(__ENV.ORIGINS||'http://host.docker.internal:18089,http://host.docker.internal:18090').split(',');
export const options={
  scenarios:{reads:{executor:'constant-arrival-rate',rate:Number(__ENV.RATE||20),timeUnit:'1s',duration:__ENV.DURATION||'30s',preAllocatedVUs:100,maxVUs:100}},
  thresholds:{http_req_failed:['rate<0.01'],http_req_duration:['p(95)<1500'],checks:['rate>0.99'],dropped_iterations:['count==0']}
};
export default function(){
  const n=execution.scenario.iterationInTest,user=users[n%users.length];
  const paths=[`/api/network/messages/with/${user.otherId}?limit=50`,'/api/network/messages/conversations','/api/network/circles/unread-counts',`/api/network/circles/${user.circleId}/posts?limit=50`];
  const path=paths[n%paths.length];
  const origin=origins[Math.floor(n/paths.length)%origins.length];
  const response=http.get(origin+path,{headers:{Authorization:`Bearer ${user.token}`},tags:{endpoint:String(n%paths.length)},timeout:'10s'});
  responseStatuses.add(1,{status:String(response.status),endpoint:String(n%paths.length)});
  check(response,{'authenticated read succeeds':r=>r.status===200});
  if(n%paths.length===0&&response.status===200)check(response,{'history page bounded':r=>r.json().length<=50});
}
