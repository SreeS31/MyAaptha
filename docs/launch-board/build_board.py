"""Build an offline launch board from a curated, evidence-linked scope. No app writes."""
from pathlib import Path
import json, collections, sys, xml.etree.ElementTree as ET
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT/'infrastructure'))
from launch_dependencies import write_report
OUT=Path(__file__).parent
DATE='2026-11-06'
modules=[]
SYNC='docs/synchronization-2026-10-06.md'
DESIGN='docs/app-design-2026-10-08.md'
HAND='docs/MYAAPTHA-DEPLOYMENT-HANDOFF.md'
def module(id,name,summary,owner,doc,done,pending,phase='before'):
    tasks=[]
    for i,(title,kind,hint) in enumerate(done,1):
        matches=sorted(ROOT.glob(hint))
        if not matches:raise ValueError(f'Missing source for {id}: {hint}')
        tasks.append(dict(id=f'{id}.{i}',title=title,kind=kind,phase='done',owner=owner,depends=[],stages=dict(coding='done',testing='done',integration='done'),evidence=[dict(path=p.relative_to(ROOT).as_posix(),label=p.name) for p in matches[:2]]+[dict(path=doc,label='Recorded local verification')],note='Implemented in source; completion uses dated local verification evidence, not a fresh release test.',evidenceDate='See linked dated report'))
    for title,kind,note,dep in pending:
        tasks.append(dict(id=f'{id}.{len(tasks)+1}',title=title,kind=kind,phase=phase,owner=owner,depends=dep,stages=dict(coding='na',testing='pending',integration='pending'),evidence=[dict(path=doc if kind=='VERIFY' else HAND,label='Scope / acceptance requirement')],note=note,evidenceDate='No completion evidence recorded'))
    modules.append(dict(id=id,name=name,summary=summary,owner=owner,tasks=tasks))

module('M01','Identity & account security','Registration, sessions, browser cookies and native token access.','Backend / Security',SYNC,[
 ('Authentication and identity API','API','backend/spring-boot-app/src/main/java/**/AuthController.java'),
 ('Browser cookie session transport','WEB','backend/spring-boot-app/src/main/java/**/WebSessionController.java'),
 ('Refresh concurrency and revocation coverage','SECURITY','backend/spring-boot-app/src/test/**/AuthConcurrencyTest.java')],[
 ('Validate real verification / recovery delivery','EXTERNAL','Use a real provider and validate phone/account ownership; current code alone is not delivered verification.',[]),
 ('Release account-security regression','VERIFY','Rerun login, refresh, logout, OTP and cross-account denial against the selected staging build.',['M15.4'])])
module('M02','Profile & account settings','Saved profile overview, section editing, storage indicator and preferences.','Web / Flutter', 'docs/profile-storage-2026-10-07.md',[
 ('Profile persistence and owner-scoped access','API','backend/spring-boot-app/src/main/java/**/ProfileController.java'),
 ('Account settings and preferences','API','backend/spring-boot-app/src/main/java/**/AppSettingsController.java'),
 ('Profile and storage visual refresh','UX','docs/profile-storage-2026-10-07.md')],[
 ('Confirm native profile-photo parity scope','VERIFY','Web/native photo controls differ; agree launch scope and validate on physical devices.',['M16.3'])])
module('M03','Relationships & people','Managed people, anchors, network tree and discovery privacy.','Backend / Web / Flutter',SYNC,[
 ('Network and relationship operations','API','backend/spring-boot-app/src/main/java/**/NetworkController.java'),
 ('Managed person profiles','API','backend/spring-boot-app/src/main/java/**/PersonProfileController.java'),
 ('Discovery privacy enforcement','SECURITY','backend/spring-boot-app/src/test/**/DiscoveryPrivacyTest.java'),
 ('Tree and dashboard separation','UX','docs/dashboard-tree-separation-2026-10-01.md')],[
 ('Review generated / synthetic discovery accounts','VERIFY','Review role-model/discovery data quality; do not delete records automatically. Screenshots showed memory-* labels; legitimacy is unverified.',[])])
module('M04','Contacts & import review','Reviewed imports, duplicate suggestions and circle classification.','Integrations', 'docs/contact-import.md',[
 ('Address-book import API','API','backend/spring-boot-app/src/main/java/**/AddressBookController.java'),
 ('OAuth import flow and test coverage','API','backend/spring-boot-app/src/test/**/ContactOAuthImportTest.java'),
 ('Review and circle suggestion workflows','UX','docs/import-circle-suggestions-2026-10-03.md')],[
 ('Activate Google / Microsoft OAuth in staging','EXTERNAL','Register exact callbacks, approved scopes and secrets; verify real import before enabling providers.',['M15.4']),
 ('Validate device contacts permissions','VERIFY','Exercise Android/iOS permission refusal, consent and selected-record persistence.',['M16.3'])])
module('M05','Life timeline','Wave/compact views, newest first, event editing and shared persistence.','Web / Flutter',DESIGN,[
 ('Saved event API and ownership tests','API','backend/spring-boot-app/src/test/**/TimelineControllerTest.java'),
 ('Event schema and stable keys','DATA','backend/spring-boot-app/src/main/resources/db/migration/common/V68__timeline_events.sql'),
 ('Wave/compact and native event alignment','UX','docs/timeline-events-2026-10-08.md')],[
 ('Decide whether event deletion is needed','PRODUCT','No timeline DELETE endpoint exists. Optional follow-up, not treated as an agreed launch requirement.',[])],phase='post')
module('M06','Circles & group management','Membership, group administration, posting policies and tree broadcasts.','Messaging', 'docs/tree-level-messaging-2026-10-01.md',[
 ('Circle and group operations','API','backend/spring-boot-app/src/main/java/**/CircleController.java'),
 ('Relationship broadcast behavior','API','backend/spring-boot-app/src/test/**/RelationshipBroadcastServiceTest.java'),
 ('New group and shared-client integration','INTEGRATION',SYNC)],[
 ('Staging membership and removed-member access regression','VERIFY','Validate group posting policy, removal and historic attachment denial on release build.',['M15.4'])])
module('M07','Messaging & chat workspace','Direct/group conversations, search, read state and constrained deletion.','Messaging','docs/message-deletion-2026-09-30.md',[
 ('Unified conversations','API','backend/spring-boot-app/src/main/java/**/UnifiedChatController.java'),
 ('Chat discovery and search','API','backend/spring-boot-app/src/test/**/ChatDiscoveryTest.java'),
 ('Message editing, reactions and reply coverage','API','backend/spring-boot-app/src/test/**/MessageFeaturesTest.java'),
 ('Delete-for-me and delete-for-all rules','SECURITY','backend/spring-boot-app/src/test/**/MessageDeletionTest.java')],[
 ('Validate real-device calling / network behavior','VERIFY','If calling is in launch scope, validate permissions, connectivity and media on actual devices; HTTP chat evidence does not certify calls.',['M16.3']),
 ('Release read/delete race and cross-client regression','VERIFY','Rerun 24-hour/read eligibility and private-deletion persistence against staging.',['M15.4'])])
module('M08','Diary, feed & stories','Private/circle content, stories and moderation entry points.','Social',SYNC,[
 ('Social-content and story API','API','backend/spring-boot-app/src/main/java/**/SocialController.java'),
 ('Content lifecycle integration coverage','API','backend/spring-boot-app/src/test/**/SocialControllerTest.java'),
 ('Diary refresh across clients','INTEGRATION',SYNC)],[
 ('Launch content/abuse operating policy','EXTERNAL','Assign review owner, response process and retention guidance before public content launch.',['M18.3'])])
module('M09','Health records','Private reports, storage and optional provider analysis.','Health / Privacy',SYNC,[
 ('Health report service and validation','API','backend/spring-boot-app/src/test/**/HealthServiceTest.java'),
 ('Account-scoped health endpoints','API','backend/spring-boot-app/src/main/java/**/HealthController.java'),
 ('Client resume refresh and shared account checks','INTEGRATION',SYNC)],[
 ('Enable health analysis only after provider/consent validation','EXTERNAL','Configure approved AI provider, processing consent and budget; otherwise keep optional analysis disabled.',['M18.3','M15.4'])])
module('M10','Finance workspace','Transactions, monthly reporting, bills, warranty receipts and scheduled renewal reminders.','Finance',SYNC,[
 ('Finance domain and transaction tests','API','backend/spring-boot-app/src/test/**/FinanceServiceTest.java'),
 ('Finance endpoints and ownership','API','backend/spring-boot-app/src/main/java/**/FinanceController.java'),
 ('UTC reporting and live-client refresh','INTEGRATION',SYNC)],[
 ('Release import and time-boundary acceptance','VERIFY','Use representative sanitized import files; verify currency/date parsing and UTC month boundaries.',['M15.4'])])
module('M11','Trust & emergency access','Trusted people, role models and two-person emergency approval.','Trust / Security','docs/trust-center-testing.md',[
 ('Trust and role-model API','API','backend/spring-boot-app/src/main/java/**/TrustController.java'),
 ('Two-approval and expiry authorization tests','SECURITY','backend/spring-boot-app/src/test/**/TrustControllerTest.java')],[
 ('Validate owner emergency alert delivery','EXTERNAL','Configure channels and record real emergency alerts; API approvals alone do not prove external notification.',['M13.3']),
 ('Approve sensitive-document emergency policy','EXTERNAL','Confirm eligible documents, retention, access windows and audit review owner.',['M18.3'])])
module('M12','AI assistance & controls','Ranking, suggestions, consent, approval execution and answer memory.','AI / Backend','docs/ai-answer-memory-2026-10-02.md',[
 ('Deterministic helper and capability tests','AI','ai/agent-service/tests/test_ai_capabilities.py'),
 ('Approval and execution authorization','SECURITY','backend/spring-boot-app/src/test/**/AiActionExecutionServiceTest.java'),
 ('Private/shared answer-memory controls','AI','backend/spring-boot-app/src/test/**/HelpAnswerMemoryTest.java'),
 ('Web/native help controls and recorded verification','INTEGRATION','docs/ai-answer-memory-2026-10-02.md')],[
 ('Set provider secrets, budget alerts and data policy','EXTERNAL','A successful historical paid request is not a production spend cap or enabled production provider.',['M18.3']),
 ('Evaluate stronger model before enabling retries','VERIFY','No paid stronger-model accuracy validation is recorded; keep retries off until accepted.',['M12.5'])],phase='after')
module('M13','Notifications & delivery','Inbox, preferences, leased dispatch and provider integration.','Integrations', 'docs/deployment-validation.md',[
 ('Notification API and preferences','API','backend/spring-boot-app/src/main/java/**/NotificationController.java'),
 ('Durable dispatch lease tests','API','backend/spring-boot-app/src/test/**/NotificationDeliveryLeaseTest.java')],[
 ('Configure and prove real email/SMS/push delivery','EXTERNAL','Verify provider, sender, webhook, device tokens and retry/deduplication on physical devices.',['M15.4','M16.3']),
 ('Validate security-alert delivery and on-call route','EXTERNAL','Configure real recipient/provider; historical tests sent no real security email.',['M13.3'])])
module('M14','Uploads, storage & security reports','Quota levels, file validation, malware scanner and admin incidents.','Platform / Security','docs/upload-security-2026-10-04.md',[
 ('Upload quota and level assignment','API','backend/spring-boot-app/src/test/**/UploadLevelIntegrationTest.java'),
 ('File rejection and scanner enforcement','SECURITY','backend/spring-boot-app/src/test/**/UploadSecurityIntegrationTest.java'),
 ('Admin security incidents and reports','API','backend/spring-boot-app/src/main/java/**/SecurityReportsController.java'),
 ('Web/native storage policy alignment','INTEGRATION',SYNC)],[
 ('Provision private storage and production scanner','EXTERNAL','Configure bucket/IAM/encryption, pinned scanner image and signature-update monitoring.',['M15.4']),
 ('Validate retention, object deletion and media recovery','VERIFY','Exercise real storage lifecycle and restore behavior without using customer data.',['M14.5','M15.6'])])
module('M15','Cloud, capacity & recovery','Deployment scaffolding exists; production activation is unverified.','DevOps',HAND,[
 ('Production configuration and placeholder guards','SECURITY','backend/spring-boot-app/src/test/**/ProductionConfigurationGuardTest.java'),
 ('Scaling protections and bounded resource tests','API','backend/spring-boot-app/src/test/**/ScalingProtectionTest.java'),
 ('Deployment templates and local validation','INFRA','docs/deployment-validation.md')],[
 ('Provision staging cloud, DNS, TLS, secrets and registry','EXTERNAL','Select provider/budget/region; provision managed DB/Redis/storage and deployment identity. No deployed staging approval is recorded.',[]),
 ('Repeat capacity acceptance on representative infrastructure','VERIFY','Latest recorded 5,000-user run FAILED: 47.97% errors, p95 18,015 ms; host/generator saturated. Resolve sizing/load-generator limits and rerun.',['M15.4']),
 ('Record production-like backup/PITR restore drill','VERIFY','A local synthetic restore passed historically; deployed DB + media recovery and measured RPO/RTO remain unverified.',['M15.4']),
 ('Activate monitoring, alert routes and rollback rehearsal','EXTERNAL','Templates/runbooks do not establish live alerts or successful rollout/rollback.',['M15.4']),
 ('Approve exact release artifact and production promotion','EXTERNAL','Record required CI/scans, immutable digests and human launch approval after acceptance.',['M15.5','M15.6','M15.7','M18.4'])])
module('M16','Web & native release','Responsive web, native regression evidence and debug APK.','QA / Mobile',DESIGN,[
 ('Web production build and 28-route responsive audit','WEB',DESIGN),
 ('Flutter analysis, regression and debug APK evidence','MOBILE',DESIGN)],[
 ('Physical Android/iOS acceptance and native parity review','VERIFY','Debug APK/source tests do not certify physical devices or iOS. Review permissions, calls and important flows.',[]),
 ('Android production signing and store submission','EXTERNAL','Supply final application ID, keystore, Play identity, privacy forms and signed release.',['M16.3','M18.3']),
 ('iOS archive, signing and App Store submission','EXTERNAL','Supply Apple team, bundle ID, certificates, profiles and store disclosures.',['M16.3','M18.3']),
 ('Rerun exact-release cookie/bearer and accessibility suite','VERIFY','October 8 evidence is historical; test the reviewed release build against staging.',['M15.4'])])
module('M17','Documentation & handover','Corporate architecture, workflows, API/schema inventory and diagrams.','Engineering', 'docs/corporate/PROJECT-HANDBOOK.md',[
 ('Corporate handbook and offline editions','DOCS','docs/corporate/PROJECT-HANDBOOK.pdf'),
 ('API and database catalogs','DOCS','docs/corporate/source-inventory.json'),
 ('Role flows and editable ER diagrams','DOCS','docs/corporate/er-diagrams.md')],[])
module('M18','Governance & public launch','Legal/support, external security review and release sign-off.','Product / Security / Owner',HAND,[
 ('Launch handoff and operational checklist prepared','DOCS',HAND),
 ('Privacy, security and operational review scope documented','DOCS','docs/operations-runbook.md')],[
 ('Approve privacy, terms, consent, support and moderation owners','EXTERNAL','Use real legal entity/contact details; validate contact/health processing, deletion and retention. No approval record supplied.',[]),
 ('Independent staging security review and remediation acceptance','EXTERNAL','Automated tests/scans are not an independent penetration test. Include account isolation, uploads and integrations.',['M15.4','M18.3'])])

updates_path=OUT/'development-updates.json'
updates=json.loads(updates_path.read_text(encoding='utf-8')) if updates_path.exists() else {}
for m in modules:
    for task in m['tasks']:
        if task['id'] in updates.get('tasks',{}):
            task.update(updates['tasks'][task['id']])

# Explicit engineering additions keep original launch-gate IDs unchanged.
for addition in updates.get('additionalTasks',[]):
    parent=next(m for m in modules if m['id']==addition['moduleId'])
    item={k:v for k,v in addition.items() if k!='moduleId'}
    assert not any(t['id']==item['id'] for m in modules for t in m['tasks']),item['id']
    for evidence in item['evidence']:assert (ROOT/evidence['path']).is_file(),evidence['path']
    parent['tasks'].append(item)

additional_evidence={
    'M09.4':[('docs/launch-board/HEALTH-ANALYSIS-CONSENT.md','Health processing consent and enablement')],
    'M08.4':[('docs/launch-board/CONTENT-OPERATIONS-DRAFT.md','Content operations workflow ? review draft')],
    'M15.8':[('docs/launch-board/LOCAL-BUILD-IDENTITIES.md','Local artifact identities and approval limits')],
    'M15.5':[('docs/capacity-5000-verification.md','Latest recorded capacity result — failed'),('docs/capacity-target.md','Capacity scope and acceptance target')],
    'M13.4':[('docs/upload-security-2026-10-04.md','Security alert delivery configuration')],
    'M15.6':[('docs/deployment-validation.md','Historical local synthetic restore evidence')],
    'M02.4':[('docs/launch-board/DEVELOPMENT-2026-10-17.md','Current development and verification'),('mobile/flutter-app/lib/features/shell/presentation/profile_media_card.dart','Native photo/gallery controls')],
    'M05.4':[('docs/launch-board/DEVELOPMENT-2026-10-17.md','Current development and verification'),('backend/spring-boot-app/src/test/java/com/myaaptha/domain/timeline/TimelineControllerTest.java','Deletion authorization and source-preservation tests')],
    'M03.5':[('docs/launch-board/DISCOVERY-REVIEW-2026-10-17.md','Read-only discovery and fixture review')],
}
for m in modules:
    for t in m['tasks']:
        if t['id'] in {'M01.4','M01.5','M06.4','M07.6','M09.1','M09.4','M10.4','M11.4','M13.3'}:
            t['evidence'].append(dict(path='docs/launch-board/DEVELOPMENT-CONTINUED-2026-10-17.md',label='Continued development and local verification'))
        for path,label in additional_evidence.get(t['id'],[]):
            assert (ROOT/path).exists(),path
            t['evidence'].append(dict(path=path,label=label))
def done(t):return any(v!='na' for v in t['stages'].values()) and all(v in ('done','na') for v in t['stages'].values())
tasks=[t for m in modules for t in m['tasks']]
acceptance=json.loads((OUT/'pending-acceptance.json').read_text(encoding='utf-8'))
pending_ids={t['id'] for t in tasks if not done(t)}
assert len(acceptance['items'])==len({item['id'] for item in acceptance['items']}), 'Duplicate acceptance task'
assert {item['id'] for item in acceptance['items']}==pending_ids, 'Acceptance audit must cover exactly the pending tasks'
by_id={t['id']:t for t in tasks}
for item in acceptance['items']:
    item.update(title=by_id[item['id']]['title'],owner=by_id[item['id']]['owner'],stages=by_id[item['id']]['stages'])
data=dict(project='MyAaptha',snapshot=DATE,baselineRevision=updates.get('revision','2026-10-17-baseline'),scope='Original 86-task launch checklist plus explicitly tracked engineering additions. New engineering work does not automatically close external release gates.',evidencePolicy='Done = source present plus linked dated local verification / documentation. Newly completed work records its verification date. Not a production certification or complete web/native parity claim.',modules=modules)
data['acceptanceAudit']=acceptance
write_report(data, OUT)
audit_rows=[f'# Remaining launch acceptance - {DATE}', '', 'Every currently pending source task is listed below. Local implementation and launch acceptance are separate; this report does not grant external approvals.', '']
for category in dict.fromkeys(item['category'] for item in acceptance['items']):
    group=[item for item in acceptance['items'] if item['category']==category]
    audit_rows += [f'## {category} ({len(group)})', '', '| Task / accountable team | Required to complete | Next action |', '|---|---|---|']
    for item in group:
        audit_rows.append(f"| {item['id']} {item['title']} ({item['owner']}) | {item['required']} | {item['nextAction']} |")
    audit_rows.append('')
(OUT/f'PENDING-ACCEPTANCE-{DATE}.md').write_text('\n'.join(audit_rows),encoding='utf-8')
data['recentWork']=[dict(id=t['id'],title=t['title'],note=t['note'],evidenceDate=t['evidenceDate'],evidence=t['evidence']) for t in tasks if t['id'] in updates.get('tasks',{}) or any(t['id']==a['id'] for a in updates.get('additionalTasks',[]))]
(OUT/'launch-data.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
stats={'modules':len(modules),'tasks':len(tasks),'completed':sum(done(t) for t in tasks),'pending':sum(not done(t) for t in tasks),'complete_modules':sum(all(done(t) for t in m['tasks']) for m in modules)}
rows=[f'# MyAaptha launch status - {DATE}','',f"**{stats['modules']} modules · {stats['tasks']} tracked subtasks · {stats['completed']} recorded complete · {stats['pending']} pending.**",'',data['scope'],'',data['evidencePolicy'],'','**Public launch is not yet approved.** Cloud/provider activation, capacity acceptance, security/privacy review, recovery and distribution gates remain open. The latest recorded 5,000-user run failed; it is not a production capacity estimate.','', '| Module | Total | Complete | Pending |','|---|---:|---:|---:|']
for m in modules:rows.append(f"| {m['id']} {m['name']} | {len(m['tasks'])} | {sum(done(t) for t in m['tasks'])} | {sum(not done(t) for t in m['tasks'])} |")
rows+=['','## Engineering progress versus launch acceptance','']
for key in ('coding','testing','integration'):
    applicable=[t for t in tasks if t['stages'][key]!='na']
    rows.append(f"- {key.capitalize()} checks: {sum(t['stages'][key]=='done' for t in applicable)} / {len(applicable)} complete.")
verified=[t['id'] for t in tasks if not done(t) and t['stages']['testing']=='done' and t['stages']['integration']=='verify']
rows+=['',f"{len(verified)} locally verified tasks still await launch acceptance: {', '.join(verified)}. Fixes within an already closed task do not increase the original launch-task completion total.",'','## Subtasks and evidence','']
for m in modules:
    rows+=['',f"### {m['id']} — {m['name']}",'',m['summary'],'']
    for t in m['tasks']:
        rows += [f"- [{'x' if done(t) else ' '}] **{t['id']} {t['title']}** — {'Recorded complete' if done(t) else 'Pending'}; {t['owner']}. {t['note']}", '  Evidence: '+', '.join(f"[{e['label']}](../../{e['path']})" for e in t['evidence'])+'.'+(' Dependencies: '+', '.join(t['depends']) if t['depends'] else '')]
(OUT/f'STATUS-{DATE}.md').write_text('\n'.join(rows)+'\n',encoding='utf-8')
template=(OUT/'board-template.html').read_text(encoding='utf-8')
(OUT/'index.html').write_text(template.replace('__BASELINE_DATA__',json.dumps(data).replace('</','<\\/')),encoding='utf-8')
print(json.dumps(stats))
