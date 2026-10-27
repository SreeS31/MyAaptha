"""Isolated two-replica check with synthetic PostgreSQL data and real Redis.
Requires Java 21, Docker and a packaged backend jar. Creates only labelled temporary
containers; never accepts an external database. Removes containers and test tokens.
"""
import argparse, base64, concurrent.futures, json, os, secrets, socket, subprocess, time, urllib.request, urllib.error
from smoke_tls import tls_services
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent

def run(args, tls_env, db):
    output=ROOT/'.tools/scaling';output.mkdir(parents=True,exist_ok=True)
    processes=[];logs=[];accounts=output/'accounts.json'
    for artifact in ('result.json', 'k6-summary.json', 'k6.log', 'command-error.log', 'warmup-summary.json', 'warmup.log'):
        (output/artifact).unlink(missing_ok=True)
    env=tls_env.copy();env.update(DEBUG='false',TRACE='false',TRUSTED_PROXY_REGEX='127[.]0[.]0[.]1',JWT_SECRET=secrets.token_hex(32),MYAAPTHA_CORS_ALLOWED_ORIGINS='https://app.myaaptha.test',MYAAPTHA_PUBLIC_API_BASE_URL='https://app.myaaptha.test',MYAAPTHA_WEB_ORIGIN='https://app.myaaptha.test',MYAAPTHA_S3_BUCKET='myaaptha-validation',MYAAPTHA_S3_REGION='ap-south-1',SPRING_FLYWAY_ENABLED='false',MYAAPTHA_AUTH_RATE_LIMIT='1000',MYAAPTHA_FIELD_ENCRYPTION_KEYS='primary='+base64.b64encode(secrets.token_bytes(32)).decode(),ADMIN_MFA_ENCRYPTION_KEY=base64.b64encode(secrets.token_bytes(32)).decode())
    def command(values,**kwargs):return subprocess.run(values,check=True,text=True,capture_output=True,**kwargs)
    def sql(value):return command(['docker','exec','-i',db,'psql','-v','ON_ERROR_STOP=1','-U','myaaptha','-d','myaaptha','-At'],input=value).stdout
    def request(port,path,token=None,body=None,expected=200):
        headers={'Content-Type':'application/json'}
        if token:headers['Authorization']='Bearer '+token
        req=urllib.request.Request(f'http://127.0.0.1:{port}'+path,headers=headers,data=json.dumps(body).encode() if body is not None else None)
        try:response=urllib.request.urlopen(req,timeout=15)
        except urllib.error.HTTPError as ex:response=ex
        with response:
            data=response.read()
            if response.status!=expected:raise AssertionError(f'{path}: expected {expected}, got {response.status}')
            return json.loads(data) if data else None
    try:
        for port in (18089,18090):
            with socket.socket() as probe:probe.bind(('127.0.0.1',port))
        result=command(['java','-Dloader.main=com.myaaptha.release.DatabaseMigration','-cp',str(args.jar.resolve()),'org.springframework.boot.loader.launch.PropertiesLauncher'],env=env)
        (output/'migration.log').write_text(result.stdout+result.stderr,encoding='utf-8')
        for port in (18089,18090):
            log=(output/f'api-{port}.log').open('w',encoding='utf-8');logs.append(log)
            process=subprocess.Popen(['java','-Xmx384m','-jar',str(args.jar.resolve()),'--spring.profiles.active=prod','--server.address=127.0.0.1',f'--server.port={port}'],env=env,stdout=log,stderr=subprocess.STDOUT);processes.append(process)
            for attempt in range(120):
                if process.poll() is not None:raise RuntimeError('API startup failed; see logs')
                try:request(port,'/actuator/health/readiness');break
                except (OSError,AssertionError):time.sleep(1)
            else:raise TimeoutError('API readiness')
        members=[]
        for i in range(args.sessions + 1):
            name='load-'+secrets.token_hex(6);pw=secrets.token_hex(16)
            member=request(18089,'/api/users',body={'username':name,'phoneNumber':'+1999'+str(i).zfill(10),'password':pw})
            session=request(18089,'/api/auth/login',body={'identifier':name,'password':pw})
            members.append({'id':member['id'],'token':session['accessToken'],'refresh':session['refreshToken']})
        for i,member in enumerate(members):member['otherId']=members[(i+1)%len(members)]['id']
        # Many unrelated users and messages ensure queries cannot rely on tiny tables.
        records=args.records
        sql(f"INSERT INTO users(username,password_hash) SELECT 'synthetic-'||n,'disabled-test-account' FROM generate_series(1,{records}) n;")
        ids=sql("SELECT MIN(id),MAX(id) FROM users WHERE username LIKE 'synthetic-%'").strip().split('|');first,last=map(int,ids)
        sql(f"INSERT INTO direct_messages(sender_user_id,recipient_user_id,message) SELECT {first}+(n%{records}),{first}+((n+1)%{records}),'Synthetic history' FROM generate_series(1,{records}) n;")
        sql(f"INSERT INTO circles(name,description,owner_user_id) SELECT 'synthetic-circle-'||n,'Synthetic only',{first} FROM generate_series(1,1000) n; INSERT INTO circle_members(circle_id,user_id) SELECT id,{first} FROM circles WHERE name LIKE 'synthetic-circle-%'; INSERT INTO circle_posts(circle_id,author_user_id,message) SELECT c.id,{first},'Synthetic circle history' FROM circles c CROSS JOIN generate_series(1,100) n WHERE c.name LIKE 'synthetic-circle-%';")
        for member in members:
            sql(f"INSERT INTO direct_messages(sender_user_id,recipient_user_id,message) SELECT {member['otherId']},{member['id']},'Active history '||n FROM generate_series(1,2000) n;")
        active=members[0];other=members[1]
        circle_id=int(sql(f"INSERT INTO circles(name,description,owner_user_id) VALUES ('active-circle','Synthetic only',{active['id']}) RETURNING id").splitlines()[0])
        for member in members:
            member['circleId']=circle_id
            sql(f"INSERT INTO circle_members(circle_id,user_id) VALUES ({circle_id},{member['id']});")
        sql(f"INSERT INTO circle_posts(circle_id,author_user_id,message) SELECT {circle_id},{other['id']},'Active circle history' FROM generate_series(1,500) n;")
        sql('ANALYZE;')
        # Refresh after data generation so long setup or a suspended laptop cannot expire the test sessions.
        for member in members:
            session=request(18089,'/api/auth/refresh',body={'refreshToken':member.pop('refresh')});member['token']=session['accessToken'];member['refreshToken']=session['refreshToken']
        sample=members[0]
        newest=request(18089,f"/api/network/messages/with/{sample['otherId']}",sample['token']);older=request(18090,f"/api/network/messages/with/{sample['otherId']}?beforeId={newest[0]['id']}",sample['token'])
        assert len(newest)==50 and len(older)==50 and older[-1]['id']<newest[0]['id']
        request(18090,'/api/network/messages/conversations',sample['token']);request(18090,'/api/network/circles/unread-counts',sample['token'])
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
            pages=list(executor.map(lambda port:request(port,f'/api/network/circles/{circle_id}/posts',sample['token']),(18089,18090)))
            assert all(len(page)==50 for page in pages)
        # A separate budget proves both JVMs use one atomic limit.
        limited=members[-1]
        for n in range(300):request(18089+n%2,'/api/network/presence/heartbeat',limited['token'],body={})
        request(18089,'/api/network/presence/heartbeat',limited['token'],body={},expected=429)
        request(18090,'/api/network/presence/heartbeat',limited['token'],body={},expected=429)
        request(18090,'/api/network/presence/heartbeat',members[1]['token'],body={})
        accounts.write_text(json.dumps(members[:-1]),encoding='utf-8')
        print(f'PASS: two production replicas, shared 300-request limit, user isolation, cursor pages; {records:,} synthetic users and {records+2000*len(members):,} messages.',flush=True)
        (output/'result.json').write_text(json.dumps({'synthetic_users':records,'direct_messages':records+2000*len(members),'replicas':2,'redis_shared_limit':'passed','pagination':'passed','distinct_sessions':args.sessions,'workload':args.workload,'load_status':'pending' if args.load else 'not_run'},indent=2),encoding='utf-8')
        # Docker Desktop reaches host services via host.docker.internal. Java binds
        # loopback only; Linux users can run k6 on the host with ORIGINS overrides.
        if args.load:
            if args.warmup != '0s':
                warmup=command(['docker','run','--rm','--add-host','host.docker.internal:host-gateway','-v',str(output)+':/tests','-v',str(ROOT/'testing/k6')+':/scripts:ro','-e','RATE=10','-e',f'DURATION={args.warmup}','grafana/k6:latest','run','--no-thresholds','--summary-export=/tests/warmup-summary.json','/scripts/scaling.js'])
                (output/'warmup.log').write_text(warmup.stdout+warmup.stderr,encoding='utf-8')
                print('Warm-up completed (conditioning only, not acceptance evidence).',flush=True)
            result=command(['docker','run','--rm','--add-host','host.docker.internal:host-gateway','-v',str(output)+':/tests','-v',str(ROOT/'testing/k6')+':/scripts:ro','-e',f'RATE={args.rate}','-e',f'DURATION={args.duration}','-e',f'VUS={args.sessions}','-e',f'RAMP={args.ramp}','grafana/k6:latest','run','--summary-export=/tests/k6-summary.json',f'/scripts/{"concurrent-sessions" if args.workload == "sessions" else "scaling"}.js'])
            (output/'k6.log').write_text(result.stdout+result.stderr,encoding='utf-8');print(result.stdout,flush=True)
        (output/'result.json').write_text(json.dumps({'synthetic_users':records,'direct_messages':records+2000*len(members),'replicas':2,'redis_shared_limit':'passed','pagination':'passed','load_run':args.load,'load_status':'passed' if args.load else 'not_run','distinct_sessions':args.sessions,'workload':args.workload,'warmup':args.warmup,'rate':args.rate,'duration':args.duration},indent=2),encoding='utf-8')
    except subprocess.CalledProcessError as ex:
        if (output/'result.json').exists():
            report=json.loads((output/'result.json').read_text(encoding='utf-8'));report['load_status']='failed'
            (output/'result.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
        # Command arguments may contain temporary secrets; log only captured output.
        (output/'command-error.log').write_text((ex.stdout or '')+(ex.stderr or ''),encoding='utf-8');raise RuntimeError('Validation command failed; see .tools/scaling/command-error.log') from None
    finally:
        accounts.unlink(missing_ok=True)
        for process in processes:
            process.terminate()
            try:process.wait(timeout=35)
            except subprocess.TimeoutExpired:process.kill();process.wait()
        for log in logs:log.close()

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('jar',type=Path);parser.add_argument('--records',type=int,default=100000);parser.add_argument('--load',action='store_true');parser.add_argument('--rate',type=int,default=20);parser.add_argument('--duration',default='30s');parser.add_argument('--warmup',default='0s',help='Optional conditioning at 10 requests/second; measured load retains all thresholds');parser.add_argument('--sessions',type=int,default=19);parser.add_argument('--workload',choices=['reads','sessions'],default='reads');parser.add_argument('--ramp',default='30s');args=parser.parse_args()
    if not 2<=args.records<=3000000:parser.error('records must be between 2 and 3000000')
    if not 2<=args.sessions<=100:parser.error('local harness supports 2..100 active sessions; provision larger workloads on staging')
    if args.rate < 1:parser.error('rate must be positive')
    with tls_services() as (tls_env, db):
        run(args, tls_env, db)
