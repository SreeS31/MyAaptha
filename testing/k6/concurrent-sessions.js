// Synthetic staging accounts only; one account per simultaneous user.
import http from 'k6/http';
import { check, sleep } from 'k6';
import execution from 'k6/execution';
import { SharedArray } from 'k6/data';
import { Rate, Counter, Trend } from 'k6/metrics';
const users = new SharedArray('session accounts', () => JSON.parse(open(__ENV.ACCOUNTS_FILE || '/tests/accounts.json')));
const vus = Number(__ENV.VUS || 5000);
const origins = (__ENV.ORIGINS || 'http://host.docker.internal:18089,http://host.docker.internal:18090').split(',');
function seconds(value, fallback) {
  if (!value) return fallback;
  const match = /^(\d+)([smh])$/.exec(value);
  if (!match) throw new Error('Use whole-second, minute or hour durations');
  return Number(match[1]) * ({s:1,m:60,h:3600}[match[2]]);
}
const rampSeconds = Number(__ENV.RAMP_SECONDS || seconds(__ENV.RAMP, 600));
const holdSeconds = Number(__ENV.HOLD_SECONDS || seconds(__ENV.DURATION, 1800));
const writes = __ENV.SYNTHETIC_WRITES === '1';
const overruns = new Rate('session_cycle_overruns');
const started = new Counter('distinct_users_started');
const holdUsers = new Counter('distinct_users_in_hold');
const holdRequests = new Counter('hold_requests');
const wall = new Trend('request_wall_ms', true);
const statuses = new Counter('response_statuses');
export const options = {
  discardResponseBodies: true,
  scenarios: { sessions: { executor: 'ramping-vus', startVUs: 0,
    stages: [{ duration: `${rampSeconds}s`, target: vus },
      { duration: `${holdSeconds}s`, target: vus },
      { duration: __ENV.RAMP_DOWN || '30s', target: 0 }], gracefulRampDown: '15s' } },
  thresholds: {
    http_req_failed: ['rate<0.01'], request_wall_ms: ['p(95)<1500'],
    checks: ['rate>0.99'], session_cycle_overruns: ['rate<0.01'],
    distinct_users_started: [`count==${vus}`], distinct_users_in_hold: [`count==${vus}`],
    // Guard against a closed-loop test quietly reducing traffic when the server slows.
    hold_requests: [`count>=${Math.floor(vus * holdSeconds * 0.50)}`],
    'http_req_failed{phase:hold}': ['rate<0.01'],
    'request_wall_ms{phase:hold}': ['p(95)<1500'],
    'request_wall_ms{name:incoming calls}': ['p(95)<1500'],
    'request_wall_ms{name:inbox}': ['p(95)<1500'],
    'request_wall_ms{name:circle directory}': ['p(95)<1500']
  }
};
export function setup() {
  // Validate once, not 5,000 times during VU initialization.
  if (!Number.isInteger(vus) || vus < 1 || users.length < vus || new Set(users.map(u => u.id)).size !== users.length)
    throw new Error('Provide at least VUS distinct synthetic accounts; account reuse is prohibited.');
  if (users.some(u => !u.token || !u.refreshToken || !u.otherId || !u.circleId))
    throw new Error('Each fixture needs id, token, refreshToken, otherId and circleId.');
}
let account, nextRefresh = 0, cycle = 0, held = false;
export default function () {
  const start = Date.now();
  if (!account) { account = { ...users[execution.vu.idInTest - 1] }; started.add(1); }
  const elapsed = (start - execution.scenario.startTime) / 1000;
  const phase = elapsed >= rampSeconds && elapsed < rampSeconds + holdSeconds ? 'hold' : 'ramp';
  if (phase === 'hold' && !held) { held = true; holdUsers.add(1); }
  const origin = origins[(execution.vu.idInTest - 1) % origins.length];
  const clientHeaders = __ENV.SYNTHETIC_CLIENT_IPS === '1'
    ? { 'X-Forwarded-For': `198.18.${Math.floor((execution.vu.idInTest - 1) / 250)}.${(execution.vu.idInTest - 1) % 250 + 1}` } : {};
  function request(path, name, body, contentType, keepBody = false) {
    const before = Date.now();
    const headers = { ...clientHeaders, Authorization: `Bearer ${account.token}` };
    if (contentType) headers['Content-Type'] = contentType;
    const tags = { name, phase };
    const params = { headers, tags, timeout: '10s', responseType: keepBody ? 'text' : 'none' };
    const response = body === undefined ? http.get(origin + path, params) : http.post(origin + path, body, params);
    wall.add(Date.now() - before, tags);
    statuses.add(1, { ...tags, status: String(response.status) });
    if (phase === 'hold') holdRequests.add(1);
    check(response, { 'authenticated request succeeds': r => r.status === 200 }, tags);
    return response;
  }
  if (start >= nextRefresh) {
    const response = request('/api/auth/refresh', 'session refresh', JSON.stringify({ refreshToken: account.refreshToken }), 'application/json', true);
    if (response.status !== 200) { overruns.add(Date.now() - start > 5000); sleep(5); return; }
    const session = response.json();
    account.token = session.accessToken; account.refreshToken = session.refreshToken;
    nextRefresh = Date.now() + Math.min(300000, Math.max(1000, Number(session.expiresIn) * 800));
  }
  request('/api/network/calls/incoming', 'incoming calls');
  if (cycle % 3 === 0) {
    request('/api/network/presence/heartbeat', 'heartbeat', '');
    request('/api/notifications/unread-count', 'notification count');
    request('/api/network/messages/conversations', 'inbox');
    request('/api/network/circles/unread-counts', 'circle unread');
  }
  if (execution.vu.idInTest % 5 === 0) {
    request(`/api/network/messages/with/${account.otherId}?limit=50`, 'direct history');
    request(`/api/network/circles/${account.circleId}/posts?limit=50`, 'circle history');
  }
  if (cycle % 12 === 0) {
    request('/api/network/circles', 'circle directory');
    if (writes && execution.vu.idInTest % 10 === 0) {
      const boundary = `capacity-${execution.vu.idInTest}`;
      const body = `--${boundary}\r\nContent-Disposition: form-data; name="message"\r\n\r\nSynthetic capacity message ${cycle}\r\n--${boundary}--\r\n`;
      request(`/api/network/messages/with/${account.otherId}`, 'send message', body, `multipart/form-data; boundary=${boundary}`);
    }
  }
  const duration = Date.now() - start;
  overruns.add(duration > 5000);
  cycle++;
  sleep(Math.max(0, 5000 - duration) / 1000);
}
