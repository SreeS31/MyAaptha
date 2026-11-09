"""Prepare reviewable Cloud Shell commands. Never log in or contact Google Cloud."""
import argparse
import json
from pathlib import Path
import re
import shlex


def plan(project, zone='asia-south1-a'):
    if not re.fullmatch(r'[a-z][a-z0-9-]{4,28}[a-z0-9]', project):
        raise ValueError('Supply a valid Google project ID (6–30 characters).')
    if re.search(r'(^|-)prod(uction)?(-|$)', project):
        raise ValueError('Use an owner-designated beta project, not a production-named project.')
    if re.search(r'example|replace|your-project', project):
        raise ValueError('Supply your actual activated beta project ID, not a placeholder.')
    if zone not in {'asia-south1-a', 'asia-south1-b', 'asia-south1-c'}:
        raise ValueError('This reviewed beta profile is restricted to Mumbai zones.')
    region = 'asia-south1'
    tag = 'myaaptha-beta'

    def command(*args):
        return ['gcloud', *args, '--project=' + project]

    commands = [
        command('projects', 'describe', project),
        command('services', 'enable', 'compute.googleapis.com', 'iap.googleapis.com', 'oslogin.googleapis.com'),
        command('compute', 'networks', 'create', tag, '--subnet-mode=custom'),
        command('compute', 'networks', 'subnets', 'create', tag, '--network=' + tag,
                '--region=' + region, '--range=10.42.0.0/24'),
        command('compute', 'addresses', 'create', tag, '--region=' + region),
        command('compute', 'firewall-rules', 'create', tag + '-web', '--network=' + tag,
                '--direction=INGRESS', '--allow=tcp:80,tcp:443', '--source-ranges=0.0.0.0/0', '--target-tags=' + tag),
        command('compute', 'firewall-rules', 'create', tag + '-ssh', '--network=' + tag,
                '--direction=INGRESS', '--allow=tcp:22', '--source-ranges=35.235.240.0/20', '--target-tags=' + tag),
        command('compute', 'firewall-rules', 'create', tag + '-calls', '--network=' + tag,
                '--direction=INGRESS', '--allow=tcp:3478,tcp:5349,udp:3478,udp:49160-49200',
                '--source-ranges=0.0.0.0/0', '--target-tags=' + tag),
        command('compute', 'instances', 'create', tag, '--zone=' + zone, '--machine-type=e2-standard-4',
                '--subnet=' + tag, '--address=' + tag, '--tags=' + tag,
                '--image-family=ubuntu-2404-lts-amd64', '--image-project=ubuntu-os-cloud',
                '--boot-disk-size=100GB', '--boot-disk-type=pd-balanced', '--no-boot-disk-auto-delete',
                '--no-service-account', '--no-scopes', '--shielded-secure-boot', '--shielded-vtpm',
                '--shielded-integrity-monitoring', '--metadata=enable-oslogin=TRUE,block-project-ssh-keys=TRUE',
                '--labels=application=myaaptha,environment=beta',
                '--max-run-duration=7d', '--instance-termination-action=STOP'),
    ]
    return dict(schemaVersion=1, projectId=project, zone=zone, region=region,
                proposedDomain='beta.myaaptha.com', proposedTurnDomain='beta-turn.myaaptha.com',
                machineType='e2-standard-4', memoryGiB=16, bootDiskGiB=100,
                stopAfterDays=7, diskAutoDelete=False, cloudContacted=False,
                deployed=False, releaseApproved=False, commands=commands,
                accessCommand=command('compute', 'ssh', tag, '--zone=' + zone, '--tunnel-through-iap'),
                pauseCommand=command('compute', 'instances', 'stop', tag, '--zone=' + zone),
                addressCommand=command('compute', 'addresses', 'describe', tag,
                                       '--region=' + region, '--format=value(address)'),
                checkCommands=[command('projects', 'describe', project,
                                       '--format=value(projectId,projectNumber,lifecycleState)'),
                               command('billing', 'projects', 'describe', project,
                                       '--format=value(billingEnabled)')],
                outstanding=['activated trial and authenticated project access', 'budget and credit checks',
                             'DNS delegation and issued TLS', 'scanned immutable application images',
                             'private TLS database/cache/object-store configuration and protected secrets',
                             'real provider credentials and physical mobile acceptance'])


def render(data, destination):
    destination.mkdir(parents=True, exist_ok=True)
    header = '#!/usr/bin/env bash\nset -euo pipefail\n'
    provision = header + '# Creates resources; run only in the activated, reviewed beta project.\n'
    provision += '# First run only. Existing resources cause failure; inspect partial progress before retry.\n'
    provision += '# Review trial credit and budget alerts first. This is not a spending cap.\n'
    provision += 'if [[ "${MYAAPTHA_BETA_TRIAL_VERIFIED:-}" != yes ]]; then\n'
    provision += '  echo "Verify active free-trial status and sufficient credit in this project first; then set MYAAPTHA_BETA_TRIAL_VERIFIED=yes." >&2\n'
    provision += '  exit 1\nfi\n'
    provision += '\n'.join(shlex.join(c) for c in data['commands']) + '\n'
    for name, content in {
        'provision.sh': provision,
        'access.sh': header + shlex.join(data['accessCommand']) + '\n',
        'pause.sh': header + '# Stops compute only; retained disk/IP can still consume credit.\n' + shlex.join(data['pauseCommand']) + '\n',
        'address.sh': header + shlex.join(data['addressCommand']) + '\n',
        'check-project.sh': header + '# Read-only. Billing enabled does not prove free-trial eligibility or remaining credit.\n' +
                            '\n'.join(shlex.join(c) for c in data['checkCommands']) + '\n',
        'deployment-plan.json': json.dumps(data, indent=2) + '\n',
    }.items():
        (destination / name).write_text(content, encoding='utf-8', newline='\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project', required=True)
    parser.add_argument('--zone', default='asia-south1-a')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    try:
        data = plan(args.project, args.zone)
        render(data, args.output)
    except ValueError as error:
        parser.exit(1, str(error) + '\n')
    print(json.dumps(dict(projectId=data['projectId'], output=str(args.output), cloudContacted=False, deployed=False)))


if __name__ == '__main__':
    main()
