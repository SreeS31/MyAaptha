"""Read-only reconciliation of owner decisions, budget assumptions and launch dependencies."""
import argparse
from decimal import Decimal, ROUND_HALF_UP, InvalidOperation
import hashlib
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def number(value):
    try:result=Decimal(str(value))
    except InvalidOperation:raise ValueError('Invalid budget quantity') from None
    if not result.is_finite() or result<0:raise ValueError('Budget quantities must be finite and non-negative')
    return result

def estimate(profile,active_gb=None,recovery_gb=None):
    p=profile['proposed'];c=profile['confirmed']
    fx=number(p['usdInrPlanningRate']);tax=number(p['taxAllowance'])
    if fx<=0 or tax>1:raise ValueError('Invalid planning exchange rate or tax allowance')
    active=number(p['activeMediaGb'] if active_gb is None else active_gb)
    recovery=number(p['recoveryAndVersionsGb'] if recovery_gb is None else recovery_gb)
    costs={'compute':number(p['computeMonthlyUsd']),
           'activeStorage':active*number(p['storageUsdPerGb']),
           'recoveryAndVersions':recovery*number(p['storageUsdPerGb']),
           'snapshots':number(p['snapshotGb'])*number(p['snapshotUsdPerGb']),
           'outboundEmail':number(p['monthlyEmails'])/1000*number(p['emailUsdPerThousand']),
           'dns':number(p['dnsMonthlyUsd'])}
    usd=sum(costs.values());inr=(usd*fx*(1+tax)).quantize(Decimal('.01'),rounding=ROUND_HALF_UP)
    budget=number(c['hostingMonthlyInr'])
    return {'usd':float(usd),'inr':float(inr),'withinBudget':inr<=budget,
            'headroomInr':float(budget-inr),'activeStorageGb':float(active),'recoveryAndVersionsGb':float(recovery),
            'usdItems':{k:float(v) for k,v in costs.items()},'capacityAccepted':False,
            'exclusions':['storage requests and internet egress','SMS','store fees and Mac runner','independent reviews','extra staging host','managed database/cache charges','AI (separate budget)']}

def inspect(profile_path,root=ROOT):
    profile=json.loads(profile_path.read_text(encoding='utf-8'))
    source=(root/profile['sourceFile']).resolve()
    if not source.is_relative_to(root.resolve()):raise ValueError('Owner input source must remain within the project')
    current=source.is_file() and hashlib.sha256(source.read_bytes()).hexdigest()==profile['sourceSha256']
    requirements={
        'applicationKeys': ['postgres_password','redis_password','jwt_secret','field_encryption_keys','admin_mfa_encryption_key'],
        'turnRelay': ['integrations/myaaptha.calls.turn-secret'],
        'aiProvider': ['integrations/myaaptha.help-ai.api-key','integrations/myaaptha.health-ai.api-key'],
        'googleContacts': ['integrations/myaaptha.contact-oauth.google-client-id','integrations/myaaptha.contact-oauth.google-client-secret'],
        'microsoftContacts': ['integrations/myaaptha.contact-oauth.microsoft-client-id','integrations/myaaptha.contact-oauth.microsoft-client-secret'],
    }
    secrets=root/'infrastructure/production/secrets'
    # Presence only; do not read, serialize or log provider credentials.
    def present(name):
        path=secrets/name
        try:return not path.is_symlink() and not (hasattr(path,'is_junction') and path.is_junction()) and path.is_file() and path.stat().st_size>0
        except OSError:return False
    checks={key:{'allFilesPresent':all(present(n) for n in names),'requiredReferences':names,'liveValidated':False} for key,names in requirements.items()}
    return {'schemaVersion':1,'ownerInputSnapshotCurrent':current,'confirmed':profile['confirmed'],
            'recommendations':profile['proposed'],'initialBudgetScenario':estimate(profile),
            'full1000UserQuotaScenario':estimate(profile,1000,1000),
            'protectedConfigurationPresence':checks,'externalServicesContacted':False,
            'productionActivated':False,'releaseApproved':False,
            'remainingExternalDependencies':['delegated cloud and Porkbun DNS access','actual provider projects and credentials','real alert destination and test recipients','physical Android/iOS devices and Apple/Mac signing access','retention interpretation and approved policies','independent security and health-quality reviewers']}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('profile',type=Path)
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args()
    try:result=inspect(args.profile)
    except (OSError,ValueError,KeyError,TypeError) as error:
        parser.exit(1,'Cannot reconcile owner profile; verify its schema and protected paths.\n')
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'ownerInputSnapshotCurrent':result['ownerInputSnapshotCurrent'],'estimatedInitialHostingInr':result['initialBudgetScenario']['inr'],'releaseApproved':False,'report':str(args.output)}))

if __name__=='__main__':main()
