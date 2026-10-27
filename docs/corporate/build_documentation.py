"""Rebuild the source-derived corporate documentation; Python standard library only."""
from pathlib import Path
import re, json, html, collections, xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).parent
DATE = '20 October 2026'
JAVA = ROOT / 'backend/spring-boot-app/src/main/java'
MIG = ROOT / 'backend/spring-boot-app/src/main/resources/db/migration/common'
OUT.mkdir(exist_ok=True)
(OUT/'diagrams').mkdir(exist_ok=True)

def source(p): return p.relative_to(ROOT).as_posix()
controllers = sorted(JAVA.rglob('*Controller.java'))
endpoints=[]
for p in controllers:
    s=p.read_text(encoding='utf-8'); s=re.sub(r'/\*.*?\*/|//[^\n]*','',s,flags=re.S)
    cls=re.search(r'\bclass\s+\w+',s)
    if not cls: continue
    prefix=re.search(r'@RequestMapping\s*\(([^)]*)\)',s[:cls.start()])
    bases=re.findall(r'"([^"\n]*)"',prefix.group(1)) if prefix else ['']
    for m in re.finditer(r'@(Get|Post|Put|Patch|Delete|Request)Mapping\b(?:\s*\(([^)]*)\))?',s[cls.end():]):
        verb=m.group(1).upper(); args=m.group(2) or ''
        paths=re.findall(r'"([^"\n]*)"',args) or ['']
        if verb=='REQUEST':
            verbs=re.findall(r'RequestMethod\.(\w+)',args) or ['ANY']
        else: verbs=[verb]
        for b in bases:
            for q in paths:
                for v in verbs: endpoints.append({'method':v,'path':b+q,'controller':p.stem,'source':source(p)})

routes=sorted('/'+str(p.parent.relative_to(ROOT/'frontend/nextjs-app/app')).replace('\\','/') for p in (ROOT/'frontend/nextjs-app/app').rglob('page.tsx'))
routes=[r.rstrip('/') or '/' for r in routes]
migrations=sorted(MIG.glob('V*.sql'),key=lambda p:int(re.match(r'V(\d+)',p.name).group(1)))
tables={}; links=[]
def split_sql(s):
    result=[]; depth=0; start=0; quoted=False
    for i,c in enumerate(s):
        if c=="'": quoted=not quoted
        if quoted: continue
        if c=='(': depth+=1
        elif c==')': depth-=1
        elif c==',' and depth==0: result.append(s[start:i].strip());start=i+1
    return result+[s[start:].strip()]
for p in migrations:
    sql=re.sub(r'--[^\n]*','',p.read_text(encoding='utf-8'))
    for m in re.finditer(r'CREATE TABLE\s+(?:IF NOT EXISTS\s+)?(\w+)\s*\(',sql,re.I):
        name=m.group(1); i=m.end(); depth=1; j=i
        while j<len(sql) and depth:
            if sql[j]=='(': depth+=1
            if sql[j]==')': depth-=1
            j+=1
        definition=sql[i:j-1]; columns={}
        for part in split_sql(definition):
            col=re.match(r'(\w+)\s+(.+)',part,re.S)
            if col and col.group(1).upper() not in {'PRIMARY','FOREIGN','CONSTRAINT','UNIQUE','CHECK'}:
                columns[col.group(1)]={'definition':col.group(2).strip(),'migration':p.name}
            fk=re.search(r'(\w+)\s+[^,]*?REFERENCES\s+(\w+)\s*\((\w+)\)',part,re.I)
            if fk: links.append((name,fk.group(1),fk.group(2),fk.group(3)))
            fk2=re.search(r'FOREIGN KEY\s*\((\w+)\)\s*REFERENCES\s+(\w+)\s*\((\w+)\)',part,re.I)
            if fk2: links.append((name,fk2.group(1),fk2.group(2),fk2.group(3)))
        tables[name]={'created':p.name,'columns':columns,'constraints':[x for x in split_sql(definition) if re.match(r'(PRIMARY|FOREIGN|CONSTRAINT|UNIQUE|CHECK)\b',x,re.I)]}
    for statement in sql.split(';'):
        a=re.search(r'ALTER TABLE\s+(?:IF EXISTS\s+)?(\w+)\s+(.+)',statement,re.I|re.S)
        if not a or a.group(1) not in tables: continue
        t=tables[a.group(1)]
        for operation in split_sql(a.group(2)):
            add=re.match(r'ADD\s+(?:COLUMN\s+)?(?:IF NOT EXISTS\s+)?(\w+)\s+(.+)',operation,re.I|re.S)
            if add and add.group(1).upper() not in {'CONSTRAINT','PRIMARY','FOREIGN','UNIQUE','CHECK'}:
                t['columns'][add.group(1)]={'definition':add.group(2).strip(),'migration':p.name}
                fk=re.search(r'REFERENCES\s+(\w+)\s*\((\w+)\)',add.group(2),re.I)
                if fk: links.append((a.group(1),add.group(1),fk.group(1),fk.group(2)))
            drop=re.match(r'DROP\s+COLUMN\s+(?:IF EXISTS\s+)?(\w+)',operation,re.I)
            if drop:t['columns'].pop(drop.group(1),None)
            if re.match(r'(ALTER|ADD CONSTRAINT|RENAME)',operation,re.I): t['constraints'].append(p.name+': '+operation.strip())

inventory={'snapshot':'2026-10-18','controllers':len(controllers),'endpoints':endpoints,'routes':routes,'migrations':[p.name for p in migrations],'tables':tables,'foreign_keys':sorted(set(links))}
(OUT/'source-inventory.json').write_text(json.dumps(inventory,indent=2),encoding='utf-8')

chapters=[]
def chapter(title,body):chapters.append((title,body.strip()))
def diagram(key,title,nodes,mermaid):
    # Portable companion to Mermaid: readable vertical process/context boxes.
    h=110+len(nodes)*100
    parts=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 900 {h}" role="img" aria-label="{html.escape(title)}"><rect width="900" height="{h}" fill="#f4f7fb"/><text x="40" y="44" font-family="Arial" font-size="23" font-weight="bold" fill="#122843">{html.escape(title)}</text>']
    for i,(label,detail) in enumerate(nodes):
        y=75+i*100
        if i:parts.append(f'<path d="M450 {y-26}v22m-5-7 5 7 5-7" stroke="#71839b" fill="none" stroke-width="2"/>')
        parts.append(f'<rect x="80" y="{y}" width="740" height="72" rx="12" fill="white" stroke="#2a7182" stroke-width="2"/><text x="105" y="{y+28}" font-family="Arial" font-size="18" font-weight="bold" fill="#122843">{html.escape(label)}</text><text x="105" y="{y+52}" font-family="Arial" font-size="14" fill="#52657c">{html.escape(detail)}</text>')
    parts.append('</svg>'); svg=''.join(parts);ET.fromstring(svg)
    (OUT/'diagrams'/f'{key}.svg').write_text(svg,encoding='utf-8')
    (OUT/'diagrams'/f'{key}.mmd').write_text(mermaid.strip()+'\n',encoding='utf-8')
    return f'![{title}](diagrams/{key}.svg)\n\n```mermaid\n{mermaid.strip()}\n```'

chapter('01 Executive overview and document control',f'''
**MyAaptha | Corporate project handbook**  
Version 1.4 · Source snapshot {DATE} · Internal engineering and business handover

MyAaptha combines relationship networks, private personal records, community communication and assisted organization in a shared account workspace. Browser and Flutter clients use the same Spring Boot API and PostgreSQL persistence. A separate Python service supplies deterministic ranking, duplicate detection and reviewable graph suggestions; selected backend features can also use configured external AI providers.

This package is intended for product owners, engineers, QA, security reviewers and operations teams. It describes the active implementation, identifies dependencies and provides editable diagrams and repeatable inventories. It does not certify a production deployment or legal compliance.

| Control | Value |
|---|---|
| Authoring basis | Active source, common Flyway migrations, recent feature and validation records |
| Application | MyAaptha; repository directory CircleNet |
| Status | Engineering baseline; organization approval and document owner to be assigned |
| Source counts | {len(controllers)} Java controller files; {len(endpoints)} extracted HTTP mappings; {len(routes)} web pages; {len(tables)} migration-declared tables |
| Distribution | Internal; contains structural information, no real customer records or credentials |
| Maintenance | Regenerate inventories after schema/route changes; review narrative at each release |

**Evidence hierarchy:** executable source and migration files take precedence over historical manuals. Dated test reports are historical evidence, not a fresh test run. Planned infrastructure and performance targets are explicitly distinguished from observed behavior. Example names and records are fictitious.

**Active scope:** `backend/spring-boot-app`, `frontend/nextjs-app`, `mobile/flutter-app`, `ai/agent-service`, `infrastructure`. Older top-level MySQL starter implementations are reference material. The previous user/admin manuals contain aspirational items; do not infer social sign-in, offline mode, biometrics, unlimited circles or branch ACL from those manuals alone.
''')

arch=diagram('architecture','Platform architecture',[
('Experience layer','Responsive Next.js browser and native Flutter application'),('Access boundary','TLS ingress in production; browser cookies or native bearer tokens'),('Application layer','Spring Boot domain services, authorization, validation and transactions'),('Persistence and media','PostgreSQL + local/S3 media; Redis where configured; scanning'),('Assistance and delivery','Python helper service; optional AI, contacts and notification providers')],'''flowchart TB
    W[Next.js browser] -->|Cookie session| API[Spring Boot API]
    M[Flutter app] -->|Bearer JWT| API
    API --> PG[(PostgreSQL)]
    API --> MEDIA[Local storage / private S3]
    API --> SCAN[ClamAV scanner]
    API --> AI[Python agent service]
    API -. configured .-> LLM[External AI provider]
    API -. configured .-> CONTACTS[Google / Microsoft contacts]
    API -. configured .-> DELIVERY[Notification delivery]
    API -. profile dependent .-> REDIS[(Redis)]''')
chapter('02 Architecture and technical boundaries',f'''
{arch}

| Component | Responsibility | Source |
|---|---|---|
| Next.js 15 / React 19 | Routes, accessible information controls, responsive cards, cookie-session client | `frontend/nextjs-app` |
| Flutter | Native screens, typed HTTP integration, lifecycle refresh, device capabilities | `mobile/flutter-app` |
| Java 21 / Spring Boot 3.5 | Authentication, domain rules, owner checks, persistence, media and integrations | `backend/spring-boot-app` |
| PostgreSQL / Flyway | Relational persistence and versioned schema evolution | backend resources `db/migration/common` |
| Python / FastAPI | Candidate ranking, duplicate detection, insights, enrichment, contact organization | `ai/agent-service/src/ai_service` |
| Deployment tooling | Local lifecycle, container builds, Compose/Kubernetes templates, release gates | `infrastructure` |

The backend is a modular application, not a separately deployed microservice per business domain. Controllers expose contracts; services apply business rules; repositories/JDBC persist state. The Python helper is a separate process. Internal AI helper endpoints must be restricted at the network boundary: its route definitions do not establish the browser's account authorization model.

**Trust boundaries:** client to API; API to database; API to object storage/scanner; API to external providers; operator to secrets and deployment tooling. Authorize access before fetching protected resources. Profile image GET routes are explicitly public in the security configuration; this exception must not be generalized to chat attachments or private documents.
''')

chapter('03 Product capabilities and synchronization', '''
| Capability | User value | Contract / source | Delivery qualification |
|---|---|---|---|
| Profile | Personal, address, education, employment and social details | `/api/profile` | Saved overview; section editing; latest-record merge |
| Relationship tree | Organize family and other relationship links | `/api/network`, people APIs | Owner-scoped data and relationship anchors |
| Address book | Import and review contacts | `/api/address-book` | Provider OAuth requires credentials; device permissions apply |
| Timeline | View milestones newest first; add or edit an event | `/api/timeline/events` | Shared saved-event API; client composition of derived milestones |
| Circles and messages | Group and direct conversation | network and chat APIs | Membership checks; read, edit and deletion rules |
| Diary / social | Record and share memories under visibility controls | `/api/social` | Distinct from timeline overrides |
| Finance | Review transactions and monthly summaries | `/api/finance` | UTC month handling across clients |
| Health | Store reports and request optional analysis | `/api/health` | Manual entry is independent; external analysis requires deployment enablement and per-report consent |
| Trust center | Follow role models; designate trusted people; emergency access | `/api/trust` | Two independent approvals and time limits |
| Settings | Discovery, notifications, workspace and account preferences | `/api/settings` | Storage limits come from server policy |
| AI workspace | Ask for assistance and review proposals | `/api/ai` | Consent/preferences and approval boundaries |
| Administration | Security, storage levels, moderation and global catalogs | admin/security and domain controllers | Server role and service checks |

**Synchronization contract:** PostgreSQL is authoritative for persisted account data. Web uses its browser-session transport; Flutter uses bearer tokens and refresh. Refresh on relevant lifecycle transitions and after successful mutations. Equivalent behavior does not require identical layouts. The source-derived endpoint appendix identifies both transports' shared resources.

There is no evidence here of continuous real-time replication or complete offline conflict resolution. Polling/fetch, focus/resume and explicit refresh can leave a short stale-view interval. Profile sections merge against the latest fetched record to preserve other sections; concurrent writes within the same section are not guaranteed conflict-free. A full feature parity certification requires a release-by-release screen/contract matrix.

Native profile photo/gallery controls now use the shared profile API; the web timeline's parent-details interaction remains a client-specific behavior. Mobile-width browser screenshots test responsive web, not a native installed device. Native HTTP regression evidence validates the API client; APK compilation does not prove store readiness or every device behavior.
''')

role=diagram('roles','Role-based access and journeys',[
('Visitor','Read public health/security policy; register or sign in'),('Authenticated member','Manage own profile, network, records, settings and conversations'),('Circle administrator','Apply group administration within membership and posting policy'),('Platform administrator','Access protected global catalogs, security and upload-level controls'),('Operator','Operate infrastructure through deployment identity; not an application role')],'''flowchart LR
    Visitor --> Login[Authenticate]
    Login --> Member[Authenticated member]
    Member --> Own[Own records and authorized conversations]
    Member --> CircleAdmin{Circle admin membership?}
    CircleAdmin -->|Yes| Group[Group administration]
    Member --> PlatformAdmin{API admin authority?}
    PlatformAdmin -->|Yes| Global[Global catalogs and security controls]
    Operator[Infrastructure operator] --> Deploy[Deployment and recovery]''')
chapter('04 Roles, authorization and user journeys',f'''
{role}

Application admin authority, circle admin membership and an infrastructure operator's permissions are different scopes. Do not assume an organizational tenant role hierarchy from the earlier generic admin manual. Consult `platform/config/SecurityConfig.java` and each service for actual checks.

| Actor | Main flow | Guard / exception |
|---|---|---|
| New member | Register → authenticate → complete profile → add relationships → configure discovery | Validation, credential policy and session checks |
| Returning member | Sign in → dashboard → chosen personal workspace → save → refresh | Expired session refresh or sign in again |
| Circle member | Open permitted circle → fetch conversation → post if allowed | Admins-only posting can deny ordinary members |
| Circle admin | Review group → manage permitted settings → moderate eligible message | Delete-for-all remains time/read constrained |
| Star Member | Receive emergency request → approve/reject independently | One approval does not grant access |
| Platform admin | Authenticate → pass configured security checks → inspect admin workspace | Generic mutation routes may require admin; ownership still applies |
| Operations engineer | Read release gates → configure environment → validate → deploy → monitor | Deployment identity, backup and approval are external controls |

**Authorization sequence:** reject invalid/expired authentication; verify route-level role; verify resource ownership or membership; validate action eligibility; execute within the required transaction; return only permitted fields. Hiding a button is presentation, not authorization.
''')

auth=diagram('authentication','Authentication and session lifecycle',[
('Sign in','Validate identifier/password and any required OTP'),('Establish session','Web receives configured cookie session; native receives token response'),('Use protected API','Server validates identity, route access and resource scope'),('Refresh','Renew through the corresponding session transport'),('Revoke or expire','Stop using the session; reauthenticate when refresh is invalid')],'''sequenceDiagram
    actor U as User
    participant C as Web / Flutter
    participant A as Spring API
    participant D as Session persistence
    U->>C: Sign in
    C->>A: Login credentials
    A->>D: Validate account and establish session
    A-->>C: Cookie session or token response
    C->>A: Protected request
    A->>D: Validate session and resource access
    A-->>C: Permitted response
    C->>A: Refresh on expiry
    A-->>C: Renewed session or authentication failure
    C->>A: Logout / revoke
    A->>D: Invalidate session''')
chapter('05 Authentication, privacy and security',f'''
{auth}

The API uses BCrypt password hashing and JWT-based stateless request authentication with persisted session/refresh controls. Native `/api/auth` and browser `/api/web-auth` have different transport semantics; do not move browser tokens into persistent JavaScript storage as a documentation shortcut. The login DTO accepts `identifier`, compatibility `email`, `password` and optional six-digit `otpCode`.

Spring's standard CSRF feature is disabled for the JWT application; the browser-cookie boundary uses its own origin/header checks. Review that filter and production origin configuration together. Security headers include CSP restrictions, referrer controls and HSTS. CORS and TLS need deployment-specific configuration.

Public registration, sign-in/refresh/logout/revoke, policy, callback and health routes are deliberate exceptions. Profile media and notification unsubscribe have specific public route exceptions. Most APIs require authentication; global administration routes require admin authority; personalized services additionally enforce owner/membership restrictions.

**Data classification:** credentials and session secrets are restricted; contact, health, finance and private messages are confidential; public profile media is publicly retrievable by its route policy; operational metrics and schema metadata are internal. Never include actual account exports, tokens, provider secrets or signed URLs in this handbook.

**Review checklist for a release:** cross-account denial, group membership changes, token revocation, cookie-origin rejection, protected attachment access, upload scanning failures, abuse-report authorization, sensitive-field minimization and audit retention. These are verification obligations, not a claim of universal certification.
''')

timeline=diagram('timeline','Timeline composition and event editing',[
('Load sources','Fetch profile, relationship milestones and saved timeline events'),('Compose','Match stable event keys; saved values override matching derived milestones'),('Order and display','Latest date first; wave/compact view; type tag and edit control'),('Add or edit','Validate date, supported type, title, detail and account event limit'),('Persist and refresh','PUT by event key; other account data remains independently stored')],'''flowchart TD
    Profile[Profile milestones] --> Merge[Compose by stable event key]
    Relations[Relationship milestones] --> Merge
    Saved[Saved timeline events] --> Merge
    Merge --> Sort[Newest date first]
    Sort --> View[Wave / compact presentation]
    View --> Edit[Add or edit event]
    Edit --> Valid{Valid payload and owner?}
    Valid -->|Yes| Put[PUT event by key]
    Valid -->|No| Error[Show validation error]
    Put --> Saved''')
chapter('06 Profile, settings and timeline workflows',f'''
**Profile:** display saved values by default. An Edit action opens the corresponding section form; Save updates that section against a newly fetched profile; Cancel returns to the saved overview. Invalid image URLs fall back to initials. Photo upload validates its own smaller limit; general storage limits must not be substituted for the photo policy.

**Settings:** fetch account preferences and upload policy; compute storage percentage from used bytes and allowance; show usage in a circular indicator with capacity and per-file limit below. Clamp the displayed ring to a valid range while reporting actual usage accurately. Administrators can assign configured upload levels; clients must not hardcode entitlements.

{timeline}

| Rule | Implemented behavior |
|---|---|
| Types | Birth, Family, Remembrance, Education, Marriage, Employment, Other |
| Colors | Blue birth/family; red remembrance; purple education; pink marriage; amber employment |
| Stable keys | `profile-birth`, `profile-education`, relation-based birth/death/marriage keys |
| Saved event scope | Composite `(user_id, event_key)` identity |
| Key validation | Letters, numbers, underscore and hyphen; 1–100 characters |
| Date | Valid ISO date; storage is VARCHAR(10), validated by LocalDate |
| Content | Nonblank title ≤200; detail ≤2,000 characters |
| New event ceiling | 500 saved events per user; existing event updates remain possible |
| Delete | Owner-scoped DELETE removes a saved event or override; source milestones remain intact |

An education year is displayed using a December 31 date convention; this is not evidence of the actual graduation day. Editing a derived milestone creates/updates a timeline override and does not alter the source profile or relationship. Source records can therefore intentionally differ from a customized timeline label.
''')

contacts=diagram('contact-import','Reviewed contact import', [('Choose source','File, device or configured OAuth provider'),('Authorize and normalize','Obtain consent; parse supported records'),('Review candidates','Inspect duplicates, relationship and circle suggestions'),('Confirm selection','Persist only reviewed/confirmed records'),('Connect','Assign circles or relationships and refresh the workspace')],'''flowchart TD
    Source[Choose contact source] --> Consent{Permission / provider configured?}
    Consent -->|No| Stop[Explain unmet requirement]
    Consent -->|Yes| Parse[Parse and normalize]
    Parse --> Review[Review duplicates and suggestions]
    Review --> Confirm{Confirm selection?}
    Confirm -->|No| Cancel[No import write]
    Confirm -->|Yes| Persist[Persist selected records]
    Persist --> Connect[Assign circles / link relationships]''')
chapter('07 Relationships, contacts and circle workflows',contacts+'\n\n'+'''
**Member workflow:** add a managed person or import a contact → review identity and contact fields → choose relationship and anchor → save → inspect the tree → correct ambiguous links. A managed person record is not automatically a registered login account. Keep `users`, personal people records and relationship edges conceptually distinct.

**Contact import:** choose a supported file/device/provider → obtain permission or OAuth consent → parse and normalize → inspect duplicates and suggestions → confirm selected entries → persist → optionally assign suggested circles. AI organization produces reviewable suggestions; it is not permission to silently merge identities. Google/Microsoft OAuth credentials, redirect URLs and outbound connectivity are configuration prerequisites.

**Relationship example:** Asha adds Ravi as a parent, anchored to herself, then adds Meera as a sibling under the correct shared parent context. A connection label depends on direction and anchor; reversing an edge can change its meaning. Review dates independently before deriving birth or remembrance milestones.

**Circle workflow:** create or select a permitted group → configure membership/admins/posting policy → fetch conversation → post if permitted → inspect read/message information → moderate according to server rules. Membership is the security boundary; a UI link does not grant access.

**Data quality controls:** avoid treating the same email/phone as conclusive identity without human review; preserve original import context; inspect duplicate candidates; confirm anchors; keep private contact details out of people-discovery cards. Role-model discovery showing generated-looking usernames may reflect existing test/generated account records; labels alone do not prove an account is a real person or endorsed role model.
''')

chat=diagram('messaging','Message send, read and deletion workflow',[
('Authorize conversation','Direct participant or current circle member; posting policy applies'),('Send and fetch','Persist message, return authorized history and attachment references'),('Read information','Use server read state; group reads reflect conversation fetching'),('Private deletion','Delete for me persists only for this account across devices'),('Global deletion','Direct sender / circle admin; strictly under 24h and not all recipients read')],'''flowchart TD
    Open[Open conversation] --> Access{Authorized participant?}
    Access -->|No| Deny[Reject]
    Access -->|Yes| Send[Send / fetch message]
    Send --> Choice{Deletion choice}
    Choice -->|For me| Hide[Persist participant-specific hide]
    Choice -->|For all| Eligible{Authorized and age under 24h and unread recipients?}
    Eligible -->|Yes| Redact[Server transaction deletes / redacts]
    Eligible -->|No| Reject[Keep message; explain denial]
    Hide --> Refresh[Refresh history without restoring hidden content]''')
upload=diagram('upload','Authorized upload lifecycle', [('Authenticate and validate','Verify account, feature type, quota and feature-specific limit'),('Scan','Apply configured malware scanning policy; reject failures'),('Store','External local path or configured S3 object and metadata'),('Access','Apply feature access rules; profile avatar route is a public exception'),('Retain and clean','Follow retention policy; reconcile metadata and objects')],'''flowchart TD
    Request[Upload request] --> Policy{Identity / type / size / quota valid?}
    Policy -->|No| Reject[Reject upload]
    Policy -->|Yes| Scan[Configured malware scan]
    Scan --> Safe{Scan accepted?}
    Safe -->|No| Reject
    Safe -->|Yes| Store[Store bytes and metadata]
    Store --> Read[Feature-specific access checks]
    Store --> Retain[Retention cleanup]''')
chapter('08 Messaging, media and notifications',f'''
{chat}

Delete-for-me is private and persisted across devices. In direct conversations only the sender can delete for all. In circles only current circle admins can delete for all, including another member's post; ordinary members cannot globally delete their own group post. Eligibility expires when all recipients have read or 24 hours elapse. Hidden read receipts do not erase stored direct read state. Group reads currently reflect conversation fetch, not per-message viewport acknowledgement.

Hidden markers allow cursor history merging to avoid restoring privately deleted content. Search, saved messages, unread counts and conversation previews exclude private deletion. Attachment access and forwarding reject hidden direct-message sources. Locking/transactions enforce eligibility against concurrent reads and edits.

{upload}

**Upload lifecycle:** authenticate → check feature-specific size, quota and allowed type → validate content → scan under configured policy → store outside the application package or in configured object storage → record metadata → authorize later access → retention cleanup removes eligible media. General multipart configuration allows 25 MB per file; profile policy is smaller (5 MB). Request/container/gateway limits are separate controls and must be checked together. Scanner and storage failures must not be presented as successful persistence.

**Notification lifecycle:** an application event produces a recipient notification; preferences and delivery configuration govern channels; the dispatcher attempts configured delivery and records result/retry handling. The default dispatcher interval is five seconds. A stored in-app notification does not prove external SMS/email/push delivery. Device registration, unsubscribe links and provider configuration require separate validation.
''')

emergency=diagram('emergency','Emergency access decision workflow',[
('Start request','Requester identifies owner and reason; request expires after 24h'),('Collect decisions','Two independent designated Star Members approve'),('Authorize access','Verify identity, approvals, eligible documents and active time window'),('Limited access','Approved access lasts one hour; audit document/list access'),('Expire or reject','Stop access when expired or authorization fails')],'''flowchart TD
    Request[Emergency request] --> Pending[Pending independent decisions]
    Pending --> Count{Two independent approvals?}
    Count -->|No| Wait[No document access]
    Count -->|Yes| Access[One-hour approved access]
    Access --> Audit[Audit list and document opens]
    Pending --> Expiry[24-hour request expiry]
    Access --> End[Access expiry / authorization denial]''')
approval=diagram('ai-approval','Human-reviewed AI action workflow', [('Select permitted context','Respect user preferences and consent'),('Receive proposal','Suggestion and explanation remain reviewable'),('Decide','Approve or reject through the decision contract'),('Validate execution','Server verifies decision, actor and permitted action scope'),('Refresh and inspect','Inspect persisted result; retain appropriate action history')],'''flowchart TD
    Context[Permitted context and consent] --> Proposal[AI proposal]
    Proposal --> Decision{User decision}
    Decision -->|Reject| Stop[No approved execution]
    Decision -->|Approve| Guard{Server validates actor and scope?}
    Guard -->|No| Block[Reject execution]
    Guard -->|Yes| Execute[Execute permitted action]
    Execute --> Inspect[Refresh result and action history]''')
chapter('09 Trust, health, finance and AI workflows',f'''
{emergency}

Two distinct designated Star Members must approve emergency access. Unrelated users and a single approval must remain denied. List views, decisions and document opens produce emergency audit events. Multi-channel owner alerting is an operational requirement requiring configured providers; do not infer it from the presence of the emergency API.

**Health use case:** member uploads a report → API validates access and file policy → store report → member supplies per-report processing consent and requests analysis only if enabled/configured → show interpretation with provenance and limitations → member reviews and can remove the report through authorized controls. Analysis is assistance, not a clinical diagnosis or an established regulatory approval.

**Manual health entry:** web/native support multiple named measurements and units, optional reference ranges, collection date, notes and an optional owned diary link. API validation rejects missing values, future dates, non-finite values and inverted reference bounds. Stored limits are shared: report/lab 200, metric 120, unit 40 and notes 1,000 characters. Failed client saves preserve drafts; busy controls prevent concurrent clicks. Unknown network outcomes do not have a server idempotency guarantee. Optional external analysis defaults off and uses a separate consent path. See [current health-entry contract](../launch-board/HEALTH-MANUAL-ENTRY-2026-10-18.md).

**Finance use case:** import or enter supported transaction data → inspect parsed values → persist account-owned transactions → calculate monthly summaries in the shared UTC convention → correct incorrect classification → refresh browser/native summaries. Example: a fictitious expense of 1,250 on 2026-10-01 belongs to the October UTC reporting period; currency and parsing assumptions must be explicit in import validation.

**AI use case:** fetch preferences/consent → submit permitted context → receive explanation or proposed action → inspect proposed change → approve or reject through the appropriate approval API → execute only after the server validates decision, actor and action scope → inspect resulting data. Not every response requires execution; suggestion endpoints do not imply autonomous writes.

The Python helper's ranker uses normalized fields and similarity; duplicate detection compares phone/email and similar names; family insights and enrichment require explicit consent in their request contracts. Contact organization uses rules/aliases. These deterministic endpoints do not establish a trained proprietary model. External LLM-backed help/health functionality is a separate configured backend integration. Approvals, execution and history have dedicated Java controllers.

{approval}
''')

chapter('10 Use-case catalog and acceptance scenarios','''
| ID | Actor / trigger | Main result | Alternate or denial path | Acceptance evidence to capture |
|---|---|---|---|---|
| UC-01 | Visitor registers | Account eligible for sign-in | Invalid/duplicate data rejected | Registration validation and credential policy |
| UC-02 | Member edits education | Saved overview reflects section change | Cancel preserves saved values | Other profile sections remain unchanged |
| UC-03 | Member adds timeline event | Event visible in latest-first order | Invalid date/type/title rejected | Reload and native fetch show saved value |
| UC-04 | Member overrides birth milestone | Timeline label/date overridden | Source profile stays independently stored | Matching stable key and source comparison |
| UC-05 | Member imports contacts | Reviewed entries persisted | Missing consent/provider error/duplicate warning | Confirmed selection, no silent merge |
| UC-06 | Member links a relative | Tree and milestone context update | Invalid anchor or inaccessible person denied | Direction and owner isolation |
| UC-07 | Circle member sends message | Authorized group sees message | Admin-only posting denies ordinary member | Membership and posting-policy tests |
| UC-08 | Member deletes for me | Sender's history hides entry | Other participant retains entry | Cross-device reload, search and attachment access |
| UC-09 | Sender/admin deletes for all | Eligible message disappears/redacts | Read/time/role constraint denies | Boundary at 24h, race with read acknowledgement |
| UC-10 | Member uploads report | Stored authorized metadata/media | Quota/type/scanner failure denied | No unscanned successful upload |
| UC-11 | Stars approve emergency | Limited access after two approvals | One approval/unrelated actor/expiry denied | Audit trail and time-window checks |
| UC-12 | Member approves AI proposal | Validated approved change executes | Rejection or changed scope blocks | Decision/actor binding and resulting state |
| UC-13 | Admin changes upload level | API returns updated entitlement | Non-admin denied | Server and both-client policy refresh |
| UC-14 | Operator restores backup | Isolated restored environment validated | Failed checks prevent cutover | Actual measured RPO/RTO and integrity report |

**Example end-to-end scenario:** Asha signs in, saves education, adds a graduation event, imports reviewed contacts, opens a family circle and posts a reunion message. Her Flutter client refreshes the saved event and the same account preferences. Ravi, using another account, must not fetch Asha's private event list or health report by changing an identifier. Record API responses, account isolation, refresh behavior and UI screenshots separately.

**Boundary scenarios:** expired refresh token; two edits to different profile sections; same-section concurrent edits; invalid leap date; 501st new timeline row; edited existing row at the limit; removed circle member requesting old attachments; all recipients read immediately before deletion; failed malware scan; exhausted storage; provider outage; emergency expiry; missing external AI consent.
''')

chapter('11 Data architecture and relationship model','''
The physical system uses PostgreSQL migrations. `users` represent login identities; personal/managed people records and relationship edges represent the member's network; circles and membership tables represent communication scope. Other domains attach account-owned settings, sessions, media, records, notifications, AI decisions and trust events.

**Physical versus logical relationships:** the ER files below are extracted from explicit migration `REFERENCES` clauses. Ownership columns without a declared FK are business relationships and must not be shown as database-enforced constraints. Optional references may be zero-or-one; the overview deliberately uses conservative optional cardinality. Uniqueness and nullability details are in the migration inventory.

The schema appendix is a source-derived DDL reference, not a live `pg_catalog` export. It tracks CREATE TABLE, ADD/DROP COLUMN and retains ALTER/constraint statements for review. Complex conditional SQL, renamed structures or altered definitions must be reconciled against PostgreSQL metadata before treating it as a certified deployed schema. Runtime database access was not required to prepare this package.

**Retention and integrity:** follow documented media retention and privacy workflows; do not assume row deletion removes every external object. Timeline ownership FK has ON DELETE CASCADE. Session, audit and emergency records have independent purposes and retention requirements. Validate backups jointly with object storage and migration version.
''')

chapter('12 API contracts and integration examples','''
The source-derived appendix enumerates method/path/controller for active Java mappings. It is a route catalog, not a complete OpenAPI contract: body validation, query parameters, media types and error envelopes remain defined in controller DTOs/services. AI helper routes are separately cataloged. Check `SecurityConfig.java` in declaration order before assigning a permission label to a path.

**Native sign-in example (fictitious credentials):**

```http
POST /api/auth/login
Content-Type: application/json

{"identifier":"asha@example.invalid","password":"<user-supplied-password>"}
```

Use the response's access token only through the authorized bearer transport. Browser login uses its cookie-session route and required origin/header policy. Do not assume the two login responses are interchangeable.

**Create/update a timeline event:**

```http
PUT /api/timeline/events/custom-graduation-2026
Authorization: Bearer <access-token>
Content-Type: application/json

{"eventKey":"custom-graduation-2026","date":"2026-06-15","kind":"Education","title":"Graduation","detail":"Completed a postgraduate course"}
```

The path key determines the saved event identity. GET `/api/timeline/events` returns the signed-in user's saved events ordered by date descending and key; it does not return the entire client-composed set of source milestones. Unsupported kind, invalid date or length violations return a bad request. The controller updates an existing owned key or inserts a new row. DELETE `/api/timeline/events/{key}` returns 204 and removes only the signed-in account's saved row or override; removing an override restores its source-derived display without changing profile/relationship records.

**Error handling:** 400 denotes validated bad input in the timeline contract; 401 authentication failures; 403 authorization denial where enforced; other controllers may return different statuses for missing or invalid resources. Clients should handle expiry, validation and transient integration failure separately. Do not assume an undocumented universal error envelope or blanket retry/idempotency guarantee for all POSTs.

**Contract evolution:** prefer additive changes, keep compatibility fields deliberately, validate strict JSON behavior and release clients together when contracts change. Test both cookie and bearer paths, cross-account denial and reload persistence. Timeline PUT is a stable-key update; arbitrary create/send operations may create duplicates if retried without an idempotency contract.
''')

deploy=diagram('deployment','Production readiness and release flow',[
('Prepare','Select cloud/domain, identities, secrets, providers and storage'),('Build and verify','Run required tests/scans; produce tagged images, digests and SBOM'),('Validate environment','Database migrations, health checks, backups and provider settings'),('Controlled rollout','Compose baseline or Kubernetes configuration; monitor and gate'),('Operate and recover','Alerts, immutable rollback, isolated restore drills and review')],'''flowchart LR
    Source[Reviewed source] --> Checks[Tests and security scans]
    Checks --> Artifacts[Tagged images + digests + SBOM]
    Artifacts --> Gate{Environment / release gates passed?}
    Gate -->|No| Remediate[Resolve blockers]
    Gate -->|Yes| Deploy[Controlled deployment]
    Deploy --> Monitor[Health and metrics]
    Monitor --> Incident{Unhealthy?}
    Incident -->|Yes| Rollback[Rollback / isolated restore]
    Incident -->|No| Review[Operational review]''')
chapter('13 Deployment, configuration and operations',f'''
{deploy}

**Local preview:** run `powershell -ExecutionPolicy Bypass -File infrastructure/start-local.ps1`; `-SkipBuild` uses existing built artifacts. Stop through `infrastructure/stop-local.ps1`; the local PostgreSQL volume is retained. Canonical web preview uses port 3000; API and helper settings come from the local startup configuration. Do not start a competing Next.js dev build over a standalone preview's `.next` output.

**Production baseline:** Compose templates support a single-host TLS/Caddy deployment; Kubernetes templates provide replicas, probes, resources and autoscaling scaffolding. Managed PostgreSQL, Redis, object storage, secret manager and ingress are deployment dependencies, not proof that resources have been provisioned. Do not claim production readiness from local startup.

| Configuration group | Required review |
|---|---|
| Database | URL, credentials, profile, migration locations, connection limits, backup/PITR |
| Authentication | Random managed JWT/session secrets, lifetimes, origin/cookie policy, admin security |
| Storage | Local/S3 provider, external path/bucket, IAM, quota, scanner, cleanup schedule |
| Contacts | OAuth credentials and exact redirect URLs for enabled providers |
| AI | Helper URL, provider credentials/model policy, consent and data egress |
| Notifications | Channel/provider credentials, webhook settings, device setup and retries |
| Infrastructure | Domain/TLS, registry digest, replicas, resources, observability and rollback |
| Mobile release | Signing identity, store metadata, permission declarations and device validation |

Never promote local fallback credentials or secrets into production. Example configuration belongs in templates with placeholders; operational credentials belong in the approved secret mechanism.

The existing operations runbook states **targets**, including 99.9% monthly availability, RPO 15 minutes and RTO four hours. These are not measured guarantees. Baseline alert proposals include sustained 5xx rate, latency, database pool pressure and notification failures. Instrument the deployed system and agree organization-specific objectives before treating them as service commitments.

**Recovery workflow:** identify incident → preserve audit/log evidence → isolate affected component → revoke/rotate compromised access if needed → restore PostgreSQL into an isolated environment → validate migration version, constraints and representative domain access → reconcile media → measure recovery time and data loss → approve cutover → document follow-up. An image rollback alone cannot undo every schema/data change.
''')

chapter('14 Quality assurance, evidence and release acceptance','''
| Layer | Required checks | Existing evidence basis |
|---|---|---|
| API | Domain tests, authorization, input validation, persistence and migration compatibility | Recent sync/timeline/backend reports |
| Web | Production build, unit/e2e/integration, keyboard and responsive checks | October 8 app-design record |
| Flutter | Analyzer, unit/widget tests, HTTP contract integration and debug build | October 8 native client record |
| Providers | OAuth callback, delivery, AI consent and outage behavior | Requires configured deployment |
| Security | Dependency/image scans, secrets, isolation, malware handling | Release tools and security docs |
| Operations | Health/readiness, realistic capacity, backup restoration, rollback | Requires deployed environment and measured drill |

Recent recorded evidence includes a passing web production build and 12 production E2E checks, Flutter analysis with no issues, 34 passing mobile tests with one opt-in live test skipped in the ordinary suite, and a separately passing native HTTP live check. These are **October 8 historical results**, not tests rerun during documentation generation. The browser route review covered 28 routes at desktop/mobile sizes; native device behavior is a separate obligation.

Earlier API and synchronization reports contain different test counts from different dates/scopes. Do not add them together as a current suite size. Consult linked evidence and rerun the release's required checks from its exact commit before sign-off.

**Release acceptance:** identify release artifact and migration set; validate both session transports; verify cross-account isolation; cover file/quota limits; verify derived and saved timeline composition; validate message deletion races; test configured providers; record accessibility and device checks; confirm secrets, backup restoration and rollout/rollback gates. Open issues require an accountable owner and a recorded acceptance or remediation decision.
''')

chapter('15 Known limitations, decisions and maintenance','''
| Item | Impact / decision |
|---|---|
| Historical aspirational manuals | New handbook is the implementation-grounded entry point; retain old records with context |
| Configuration-dependent providers | Do not advertise delivered notifications, OAuth import or external AI without configuration tests |
| Timeline saved overrides | Owner-scoped saved-row deletion/reset; source profile/relationships remain independent; education date convention |
| Same-section concurrent profile edits | Latest merge protects other sections; no universal conflict resolution guarantee |
| Client differences | Shared API does not establish complete feature-identical web/native experiences |
| Public profile image route | Treat avatar imagery according to actual public route policy |
| Physical DDL inventory | Review raw migrations and deployed catalog for complex ALTER/conditional statements |
| Capacity/SLA | Existing targets and historic local measurements do not establish production guarantees |
| Cloud/store handoff | Infrastructure provisioning, secrets, restore drills and mobile signing remain external release gates |

**Change process:** update source and tests → add migration if required → regenerate this package → review route/data diffs → update diagrams and user scenarios → validate portable rendering and links → assign document version/approval → publish through the organization's approved channel.

**Glossary:** account = authenticated user identity; managed person = network record that may not have a login; relationship = directed/anchored connection; circle = communication/membership group; Star Member = designated trust actor; override = saved timeline value taking precedence over a matching derived key; upload level = configured storage entitlement; evidence = a dated recorded verification outcome; target = desired service behavior requiring measurement.
''')

api=['# API route inventory','',f'Source snapshot: {DATE}. {len(endpoints)} extracted mappings from {len(controllers)} Java controller files. No runtime/OpenAPI contract claim.','', '| Method | Route | Controller |','|---|---|---|']
for e in endpoints:api.append(f"| {e['method']} | `{e['path']}` | [{e['controller']}](../../{e['source']}) |")
ai_text=(ROOT/'ai/agent-service/src/ai_service/main.py').read_text(encoding='utf-8')
api+=['','## Python helper routes','','Configured router prefix; source default uses `/api/v1`. These are internal helper contracts, not personalized Spring API routes.','']
for verb,path in re.findall(r'@router\.(get|post|put|delete)\("([^"]+)"',ai_text):api.append(f'- `{verb.upper()} /api/v1{path}`')
(OUT/'api-catalog.md').write_text('\n'.join(api)+'\n',encoding='utf-8')

schema=['# Database DDL reference','',f'Snapshot {DATE}. Source-derived declaration inventory; consult migrations for final deployed types/defaults/constraints. Common migrations only; development seed data excluded. ALTER history is retained to avoid presenting original declarations as certified current catalog metadata.','']
for name,t in sorted(tables.items()):
    schema += [f'## {name}','',f"Created by [{t['created']}](../../{source(MIG/t['created'])}).",'','| Column | Declaration (with later additions) | Source |','|---|---|---|']
    for col,d in t['columns'].items():schema.append(f"| `{col}` | `{d['definition'].replace('|','&#124;')}` | {d['migration']} |")
    if t['constraints']:schema+=['','Constraints and later ALTER history:','']+[f'- `{x.strip().replace(chr(10)," ")}`' for x in t['constraints']]
    schema+=['']
(OUT/'data-dictionary.md').write_text('\n'.join(schema),encoding='utf-8')

er=['erDiagram']
for name,t in sorted(tables.items()):
    er.append(f'    {name} {{')
    for col,d in list(t['columns'].items())[:10]:
        typ=re.match(r'\w+',d['definition']).group(0).lower()
        er.append(f'        {typ} {col}')
    er.append('    }')
for child,col,parent,key in sorted(set(links)):
    if parent in tables:er.append(f'    {parent} |o--o{{ {child} : "{col}"')
(OUT/'diagrams/physical-er.mmd').write_text('\n'.join(er)+'\n',encoding='utf-8')
er_md=['# Physical relationship diagrams','','These diagrams include explicit migration references only. Each entity shows at most ten columns; the data dictionary holds the wider declaration inventory. Optional cardinality is conservative; inspect NOT NULL and uniqueness for exact multiplicity.','', '```mermaid','\n'.join(er),'```']
families={'identity-network':['user','person','people','relationship','circle','permission','auth','session'], 'communication-media':['message','chat','post','media','notification','call'], 'personal-trust-ai':['timeline','profile','setting','finance','health','trust','emergency','ai_']}
for family,tokens in families.items():
    names={n for n in tables if any(tok in n for tok in tokens)}
    relevant=[x for x in sorted(set(links)) if x[0] in names or x[2] in names]
    for child,col,parent,key in relevant:names.update([child,parent])
    lines=['erDiagram']
    for child,col,parent,key in relevant:
        if parent in tables:lines.append(f'    {parent} |o--o{{ {child} : "{col}"')
    for n in sorted(names):lines.extend([f'    {n} {{','        string id_or_composite_key','    }'])
    (OUT/'diagrams'/f'er-{family}.mmd').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    er_md+=['',f'## {family}', '', '```mermaid','\n'.join(lines),'```']
(OUT/'er-diagrams.md').write_text('\n'.join(er_md)+'\n',encoding='utf-8')

# Explicit-edge map: standalone SVG with named FK relationships, readable without Mermaid.
edge_list=[x for x in sorted(set(links)) if x[2] in tables]
h=100+len(edge_list)*58
parts=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1100 {h}"><rect width="1100" height="{h}" fill="#f4f7fb"/><text x="30" y="40" font-family="Arial" font-size="22" fill="#122843">Physical foreign-key relationship map</text>']
for i,(child,col,parent,key) in enumerate(edge_list):
    y=75+i*58
    for x,label in [(30,parent),(690,child)]:parts.append(f'<rect x="{x}" y="{y}" width="375" height="40" rx="7" fill="white" stroke="#2a7182"/><text x="{x+12}" y="{y+25}" font-family="Arial" font-size="15" fill="#122843">{label}</text>')
    parts.append(f'<path d="M405 {y+20}H690m-8-5 8 5-8 5" stroke="#2a7182" fill="none"/><text x="420" y="{y+14}" font-family="Arial" font-size="11" fill="#52657c">{html.escape(col)} → {key}</text>')
parts.append('</svg>');(OUT/'diagrams/physical-er.svg').write_text(''.join(parts),encoding='utf-8')
er_pages=[]
for start in range(0,len(edge_list),12):
    group=edge_list[start:start+12];height=100+len(group)*58
    bits=[f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1100 {height}"><rect width="1100" height="{height}" fill="#f4f7fb"/><text x="30" y="40" font-family="Arial" font-size="22" fill="#122843">Foreign-key relationships {start+1}–{start+len(group)}</text>']
    for i,(child,col,parent,key) in enumerate(group):
        y=75+i*58
        for x,label in [(30,parent),(690,child)]:bits.append(f'<rect x="{x}" y="{y}" width="375" height="40" rx="7" fill="white" stroke="#2a7182"/><text x="{x+12}" y="{y+25}" font-family="Arial" font-size="15" fill="#122843">{label}</text>')
        bits.append(f'<path d="M405 {y+20}H690m-8-5 8 5-8 5" stroke="#2a7182" fill="none"/><text x="420" y="{y+14}" font-family="Arial" font-size="11" fill="#52657c">{html.escape(col)} → {key}</text>')
    bits.append('</svg>');name=f'physical-er-page-{start//12+1}.svg';er_pages.append(name)
    (OUT/'diagrams'/name).write_text(''.join(bits),encoding='utf-8')

counts=collections.Counter(e['controller'].replace('Controller','') for e in endpoints)
top=counts.most_common(12);maxv=max(counts.values()); chart=['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1050 610"><rect width="1050" height="610" fill="#f4f7fb"/><text x="30" y="38" font-family="Arial" font-size="22" fill="#122843">API surface by controller — largest 12</text>']
for i,(name,n) in enumerate(top):
    y=70+i*42;chart.append(f'<text x="25" y="{y+20}" font-family="Arial" font-size="14">{name}</text><rect x="235" y="{y}" width="{n/maxv*700}" height="27" rx="5" fill="#2a7182"/><text x="{245+n/maxv*700}" y="{y+20}" font-family="Arial" font-size="14">{n}</text>')
chart.append('<text x="30" y="595" font-family="Arial" font-size="12">Source counts, 2026-10-20; size is route surface, not usage, performance or business value.</text></svg>')
(OUT/'diagrams/api-surface.svg').write_text(''.join(chart),encoding='utf-8')

chapter('16 Source inventory, graphs and references',f'''
![Source-derived API surface graph](diagrams/api-surface.svg)

The graph counts extracted method/path mappings, including transport and administration endpoints. It measures source surface only; it does not measure demand, throughput, quality or delivery completeness.

## Web route inventory

{chr(10).join('- `'+r+'`' for r in routes)}

## Appendices

- [API catalog](api-catalog.md): Java method/path/source links and Python helper routes.
- [Data dictionary](data-dictionary.md): table declarations, added columns and ALTER history.
- [ER diagrams](er-diagrams.md): whole-system and domain-specific Mermaid relationships.
- [Machine-readable inventory](source-inventory.json): repeatable route/schema metadata.
- [Physical FK map](diagrams/physical-er.svg): standalone vector reference.

## Authoritative and supporting references

- [Project README](../../README.md)
- [Recent application design and validation](../app-design-2026-10-08.md)
- [Synchronization audit](../synchronization-2026-10-06.md)
- [Timeline API and clients](../timeline-events-2026-10-08.md)
- [Profile and storage behavior](../profile-storage-2026-10-07.md)
- [Contact import](../contact-import.md)
- [Message deletion policy](../message-deletion-2026-09-30.md)
- [Trust test strategy](../trust-center-testing.md)
- [Deployment handoff](../MYAAPTHA-DEPLOYMENT-HANDOFF.md)
- [Operations runbook and targets](../operations-runbook.md)
- [Security configuration](../../backend/spring-boot-app/src/main/java/com/myaaptha/config/SecurityConfig.java)
''')

chapter('17 Current engineering changes and acceptance boundaries','''
This edition refreshes source-derived API/schema references to 20 October 2026 and supersedes the 10 October handbook narrative where behavior changed. Earlier dated verification is preserved as historical evidence.

| Area | Current implementation and evidence |
|---|---|
| Moderation | Admin-only status-filtered cursor queue on web/native/API; old reports remain reachable. Reporter-visible notes and cancellation behavior are explicit. V69 indexes the queue. [Workflow and role boundaries](../launch-board/MODERATION-QUEUE-2026-10-18.md). |
| Contacts | Shared native granted/limited permission boundary, review before import and no read/upload after denied permission or leaving the pending dialog. Local plugin/API checks pass; physical device acceptance remains open. [Permission matrix](../launch-board/CONTACT-PERMISSIONS-2026-10-18.md). OAuth now handles terminal failures, empty results, cancellation and consent revocation consistently across clients; [completion contract and staging limits](../launch-board/CONTACT-OAUTH-COMPLETION-2026-10-18.md). |
| OAuth storage | Pending authorizations and review results now use the configured shared state provider, encrypted Redis payloads, hashed keys, ten-minute TTL and atomic owner/provider-validated consumption. Memory remains development only; real provider/staging acceptance remains open. [Storage and rollout workflow](../launch-board/OAUTH-SHARED-STORAGE-2026-10-19.md). |
| Health | Multi-measurement manual entry, matching bounds, preserved failed drafts and disabled-by-default consent-gated analysis. [Contract](../launch-board/HEALTH-MANUAL-ENTRY-2026-10-18.md). |
| Release identity | Version 2 hashes the full standalone web bundle and API/debug APK, with a verification command. Local identities never establish production promotion approval. [Artifact scope](../launch-board/LOCAL-BUILD-IDENTITIES.md). |
| Operational authorization | Administrator-only Actuator metadata and an optional narrowly scoped metrics credential. Packaged production-profile TLS checks verified isolated PostgreSQL/Redis readiness withdrawal, retained liveness/metrics and recovery. Real collectors, alerts and live rollback remain pending; see [operational guide](../launch-board/OPERATIONAL-METRICS-2026-10-20.md). |
| Android release | Release builds require a protected owner signing identity and reject debug signing. A manual candidate workflow pins the certificate and records signature/packaging review results; synthetic-key local verification does not establish store acceptance. [Signing implementation](../launch-board/ANDROID-RELEASE-SIGNING-2026-10-20.md). |
| Recovery | Unique complete dump publication, mandatory checksum verification and nonempty-target rejection. Actual local two-row PostgreSQL drill passed; managed PITR/media/RPO/RTO remain open. [Recovery scope](../launch-board/RECOVERY-GUARDS-2026-10-18.md). |
| AI evaluation | Ten synthetic review cases and offline comparison; actual stronger-model quality acceptance remains pending and retries default off. [Rubric and workflow](../launch-board/HELP-MODEL-EVALUATION.md). |

The [viewable launch board](../launch-board/index.html) and [dated module status](../launch-board/STATUS-2026-10-20.md) distinguish fully closed local tasks from partial engineering and external acceptance. Current scope includes explicitly identified engineering additions; changed scope is disclosed rather than presented as closure of provider, staging or approval work. Saved browser edits remain separate from the latest source evidence.

The [18 October development report](../launch-board/DEVELOPMENT-2026-10-18.md) records separate backend, native, browser, build and operational checks. Do not sum different test scopes into one suite size. Physical Android/iOS acceptance, selected staging deployment, real delivery/OAuth, independent security review, policy approval, capacity and production promotion remain open. The latest recorded 5,000-user capacity run failed. No paid stronger-model call or production deployment was performed for this update. The [20 October acceptance audit](../launch-board/PENDING-ACCEPTANCE-2026-10-20.md) records the exact requirement, proposed team and next action for every open gate. Offline rollback preparation and Android signing evidence are in the [20 October report](../launch-board/DEVELOPMENT-2026-10-20.md). The [19 October continuation](../launch-board/DEVELOPMENT-2026-10-19.md) records the shared OAuth storage migration and its verification boundaries.
''')

md=['# MyAaptha Corporate Project Handbook','',f'Version 1.4 · {DATE} · Internal engineering baseline','', '## Contents','']+[f'- {t}' for t,b in chapters]
for title,body in chapters:md+=['', '# '+title,'',body]
(OUT/'PROJECT-HANDBOOK.md').write_text('\n'.join(md)+'\n',encoding='utf-8')

def inline(s):
    s=html.escape(s)
    s=re.sub(r'`([^`]+)`',r'<code>\1</code>',s)
    s=re.sub(r'\*\*([^*]+)\*\*',r'<strong>\1</strong>',s)
    s=re.sub(r'\[([^\]]+)\]\(([^)]+)\)',r'<a href="\2">\1</a>',s)
    return s
def render(md):
    lines=md.splitlines();out=[];i=0
    while i<len(lines):
        s=lines[i]
        if s.startswith('```'):
            lang=s[3:];i+=1;block=[]
            while i<len(lines) and not lines[i].startswith('```'):block.append(lines[i]);i+=1
            if lang!='mermaid':out.append('<pre>'+html.escape('\n'.join(block))+'</pre>')
            else:out.append('<details class="diagram-source"><summary>Editable Mermaid diagram source</summary><pre>'+html.escape('\n'.join(block))+'</pre></details>')
        elif s.startswith('!['):
            m=re.match(r'!\[([^]]*)\]\(([^)]+)\)',s)
            if m:out.append('<figure><img src="'+m.group(2)+'" alt="'+html.escape(m.group(1))+'"/><figcaption>'+html.escape(m.group(1))+'</figcaption></figure>')
        elif s.startswith('|'):
            rows=[]
            while i<len(lines) and lines[i].startswith('|'):rows.append(lines[i].strip('|').split('|'));i+=1
            i-=1;out.append('<div class="table-wrap"><table>')
            for ri,row in enumerate(rows):
                if ri==1 and all(re.match(r'^\s*:?-+:?\s*$',c) for c in row):continue
                tag='th' if ri==0 else 'td';out.append('<tr>'+''.join(f'<{tag}>{inline(c.strip())}</{tag}>' for c in row)+'</tr>')
            out.append('</table></div>')
        elif s.startswith('#'):
            n=len(s)-len(s.lstrip('#'));out.append(f'<h{min(n,4)}>'+inline(s[n:].strip())+f'</h{min(n,4)}>')
        elif s.startswith('- '):
            out.append('<ul>')
            while i<len(lines) and lines[i].startswith('- '):out.append('<li>'+inline(lines[i][2:])+'</li>');i+=1
            out.append('</ul>');i-=1
        elif s.strip():out.append('<p>'+inline(s)+'</p>')
        i+=1
    return '\n'.join(out)

css='''body{margin:0;background:#eef2f7;color:#20334b;font:15px/1.65 Arial,sans-serif}nav{position:fixed;width:235px;inset:0 auto 0 0;padding:28px 18px;background:#102840;color:#fff;overflow:auto}nav strong{font-size:25px}nav a{display:block;color:#dbe8f4;text-decoration:none;font-size:12px;margin:13px 0}main{margin-left:285px;max-width:1120px;padding:36px 40px}header{padding:48px;background:linear-gradient(130deg,#102840,#216d80);color:white;border-radius:18px;margin-bottom:30px}header h1{font-size:40px;line-height:1.15;margin:18px 0}header p{color:#e2edf7}section{background:white;padding:36px;border-radius:14px;margin-bottom:26px;box-shadow:0 6px 24px #10284008}h2{font-size:25px;color:#12364f;border-bottom:2px solid #dce7ef;padding-bottom:14px}h3{font-size:19px;color:#216d80}p{margin:12px 0}a{color:#176f8a}code{font:12px Consolas,monospace;background:#f1f5f8;padding:2px 4px;overflow-wrap:anywhere}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:#f1f5f8;padding:18px;border-radius:9px;font:12px/1.5 Consolas,monospace}table{width:100%;border-collapse:collapse;font-size:12px;table-layout:auto}th{background:#e9f1f6;color:#12364f;text-align:left}td,th{padding:10px 12px;border:1px solid #dbe4ed;vertical-align:top;overflow-wrap:anywhere}figure{margin:22px 0}figure img{display:block;width:100%;height:auto;max-height:900px;object-fit:contain}figcaption{font-size:12px;color:#61748b;margin-top:7px}details{font-size:12px;color:#52657c}summary{cursor:pointer}section:target{outline:2px solid #2a7182}.table-wrap{overflow:auto}@media(max-width:850px){nav{position:static;width:auto;height:auto}nav a{display:inline-block;margin:6px}main{margin:0;padding:16px}section{padding:22px}header{padding:28px}}@media print{@page{size:A4;margin:16mm}body{background:white;font-size:10px}nav{display:none}main{margin:0;max-width:none;padding:0}header{border-radius:0;min-height:210mm;box-sizing:border-box;padding:40px;break-after:page;-webkit-print-color-adjust:exact;print-color-adjust:exact}header h1{font-size:38px}section{padding:0;border-radius:0;box-shadow:none;break-before:page}h2{font-size:22px}h3{font-size:15px}table{font-size:8px}td,th{padding:6px}tr,figure,pre{break-inside:avoid}figure img{max-height:180mm}details{display:none}a{color:#176f8a;text-decoration:none}th{-webkit-print-color-adjust:exact;print-color-adjust:exact}.table-wrap{overflow:visible}}'''
css+='body{overflow-wrap:anywhere}'
nav='<nav><strong>MyAaptha</strong><p>Corporate handbook<br/>Version 1.4 · 2026-10-20</p>'+''.join(f'<a href="#chapter-{i}">{html.escape(t)}</a>' for i,(t,b) in enumerate(chapters,1))+'<a href="#api">API catalog</a><a href="#schema">Data dictionary</a><a href="#er">ER reference</a></nav>'
body='<main><header><p>MYAAPTHA • INTERNAL DOCUMENTATION</p><h1>Corporate Project<br/>Handbook</h1><p>Architecture · Data · APIs · Workflows · Roles · Operations</p><p>Source snapshot '+DATE+'</p><p>Implementation-grounded engineering and business handover</p></header>'
for i,(title,b) in enumerate(chapters,1):body+=f'<section id="chapter-{i}"><h2>{html.escape(title)}</h2>'+render(b)+'</section>'
body+='<section id="api"><h2>Appendix A — API catalog</h2>'+render('\n'.join(api))+'</section>'
body+='<section id="schema"><h2>Appendix B — Database DDL reference</h2>'+render('\n'.join(schema))+'</section>'
body+='<section id="er"><h2>Appendix C — Physical relationship map</h2><p>Explicit foreign-key references; see editable Mermaid files for domain diagrams. Ownership without an FK remains a service rule.</p></section>'
for i,name in enumerate(er_pages,1):body+=f'<section><h2>Foreign-key map — sheet {i}</h2><figure><img src="diagrams/{name}" alt="Physical foreign-key relationships sheet {i}"/></figure></section>'
body+='</main>'
(OUT/'PROJECT-HANDBOOK.html').write_text('<!doctype html><html lang="en"><head><meta charset="utf-8"/><meta name="viewport" content="width=device-width, initial-scale=1"/><title>MyAaptha Corporate Project Handbook</title><style>'+css+'</style></head><body>'+nav+body+'</body></html>',encoding='utf-8')
(OUT/'README.md').write_text('''# MyAaptha corporate documentation

Start with [the corporate handbook](PROJECT-HANDBOOK.md), or open [the offline HTML edition](PROJECT-HANDBOOK.html). The printable PDF includes the handbook and source appendices. SVG diagrams work offline; Mermaid files are editable and can be rendered by compatible editors.

- [API catalog](api-catalog.md)
- [Database DDL reference](data-dictionary.md)
- [ER diagrams](er-diagrams.md)
- [Source inventory](source-inventory.json)

Rebuild source and HTML with `python docs/corporate/build_documentation.py`. Render the PDF using `node docs/corporate/render_documentation.cjs` after installing the project's existing Playwright dependencies and Chromium. No application state is modified. Review narrative and complex DDL before release; generated inventories are static-source references rather than live catalog certification.
''',encoding='utf-8')
print(json.dumps({'controllers':len(controllers),'http_mappings':len(endpoints),'web_pages':len(routes),'tables':len(tables),'explicit_fk_edges':len(set(links)),'chapters':len(chapters),'output':str(OUT)}))
