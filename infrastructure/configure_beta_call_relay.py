"""Configure the existing beta VM's Coturn service; never print signing material."""
import datetime
import ipaddress
import os
from pathlib import Path
import re
import secrets
import shutil
import subprocess
import tempfile
import urllib.request

PROJECT='project-5c36c021-87c7-4cfc-833'
HOST='35-244-31-192.sslip.io'

def configuration(secret,public,private):
    if not re.fullmatch(r'[A-Za-z0-9_-]{32,128}',secret): raise ValueError('Invalid protected relay secret')
    public_ip,private_ip=ipaddress.IPv4Address(public),ipaddress.IPv4Address(private)
    if not public_ip.is_global or not private_ip.is_private or private_ip.is_loopback or private_ip.is_link_local: raise ValueError('Unexpected relay interface mapping')
    return f'''# MYAAPTHA_MANAGED_CALL_RELAY
listening-port=3478
tls-listening-port=5349
min-port=49160
max-port=49239
listening-ip={private}
relay-ip={private}
external-ip={public}/{private}
realm={HOST}
server-name={HOST}
fingerprint
use-auth-secret
static-auth-secret={secret}
cert=/etc/coturn/myaaptha-certs/fullchain.pem
pkey=/etc/coturn/myaaptha-certs/privkey.pem
no-tlsv1
no-tlsv1_1
no-dtls
no-cli
no-multicast-peers
no-tcp-relay
stale-nonce=600
max-allocate-lifetime=600
user-quota=64
total-quota=256
max-bps=512000
log-file=syslog
no-stdout-log
denied-peer-ip=0.0.0.0-0.255.255.255
denied-peer-ip=10.0.0.0-10.255.255.255
denied-peer-ip=127.0.0.0-127.255.255.255
denied-peer-ip=169.254.0.0-169.254.255.255
denied-peer-ip=172.16.0.0-172.31.255.255
denied-peer-ip=192.168.0.0-192.168.255.255
denied-peer-ip=224.0.0.0-255.255.255.255
denied-peer-ip=::1
denied-peer-ip=fc00::-fdff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
denied-peer-ip=fe80::-febf:ffff:ffff:ffff:ffff:ffff:ffff:ffff
denied-peer-ip=ff00::-ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff
'''

def metadata(key):
    request=urllib.request.Request('http://169.254.169.254/computeMetadata/v1/'+key,headers={'Metadata-Flavor':'Google'})
    with urllib.request.urlopen(request,timeout=3) as response:
        if response.headers.get('Metadata-Flavor')!='Google':raise RuntimeError('Invalid metadata response')
        return response.read().decode().strip()

def install():
    import grp
    if os.name!='posix' or os.geteuid()!=0:raise RuntimeError('Run as root on the existing beta VM')
    if metadata('project/project-id')!=PROJECT or metadata('instance/name')!='myaaptha-beta':raise RuntimeError('Refusing to configure another VM')
    root=Path('/opt/myaaptha-beta/runtime');env=root/'.env';target=Path('/etc/turnserver.conf')
    if env.is_symlink() or not env.is_file() or root.resolve()!=root:raise RuntimeError('Expected protected beta runtime')
    existed=Path('/usr/bin/turnserver').is_file()
    if existed and target.exists() and '# MYAAPTHA_MANAGED_CALL_RELAY' not in target.read_text():raise RuntimeError('Review the existing unmanaged relay before changing it')
    before=env.read_text();settings=dict(line.split('=',1) for line in before.splitlines() if '=' in line and not line.startswith('#'))
    secret=settings.get('MYAAPTHA_TURN_SHARED_SECRET','').strip("'") or secrets.token_urlsafe(48)
    public=metadata('instance/network-interfaces/0/access-configs/0/external-ip');private=metadata('instance/network-interfaces/0/ip')
    if public!='35.244.31.192':raise RuntimeError('Unexpected beta public IP')
    candidate=configuration(secret,public,private)
    certificate=Path('/etc/letsencrypt/live')/HOST
    if not (certificate/'fullchain.pem').is_file() or not (certificate/'privkey.pem').is_file():raise RuntimeError('Expected the existing issued beta TLS certificate')
    backup=root/'release-backups';os.umask(0o077)
    if backup.is_symlink():raise RuntimeError('Refusing symlinked backup directory')
    backup.mkdir(mode=0o700,exist_ok=True)
    stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    (backup/('call-relay-before-'+stamp+'.env')).write_text(before)
    previous=target.read_text() if target.exists() else None
    def run(args,**kwargs):return subprocess.run(args,check=True,**kwargs)
    def write(path,value,mode=0o600):
        if path.is_symlink():raise RuntimeError('Refusing to replace a symlink')
        with tempfile.NamedTemporaryFile(mode='w',dir=path.parent,delete=False) as output:output.write(value);name=Path(output.name)
        name.chmod(mode);os.replace(name,path)
    try:
        if not existed:
            run(['systemctl','mask','coturn.service'])
            run(['apt-get','update'],stdout=subprocess.DEVNULL)
            run(['apt-get','install','--no-install-recommends','-y','coturn'],env={**os.environ,'DEBIAN_FRONTEND':'noninteractive'},stdout=subprocess.DEVNULL)
        group=grp.getgrnam('turnserver').gr_gid;base=Path('/etc/coturn');certs=base/'myaaptha-certs'
        if base.is_symlink():raise RuntimeError('Refusing a symlinked relay directory')
        base.mkdir(exist_ok=True,mode=0o750);os.chown(base,0,group);base.chmod(0o750)
        if certs.is_symlink():raise RuntimeError('Refusing a symlinked relay certificate directory')
        certs.mkdir(parents=True,exist_ok=True,mode=0o750);os.chown(certs,0,group);certs.chmod(0o750)
        for name in ['fullchain.pem','privkey.pem']:
            output=certs/name
            if output.is_symlink():raise RuntimeError('Refusing a symlinked relay certificate')
            shutil.copyfile(certificate/name,output);os.chown(output,0,group);output.chmod(0o640)
        write(target,candidate,0o640);os.chown(target,0,group)
        hook=Path('/etc/letsencrypt/renewal-hooks/deploy/myaaptha-call-relay')
        hook.parent.mkdir(parents=True,exist_ok=True)
        write(hook,f'''#!/bin/sh
set -eu
[ "${{RENEWED_LINEAGE:-}}" = "/etc/letsencrypt/live/{HOST}" ] || exit 0
install -m 0640 -o root -g turnserver "$RENEWED_LINEAGE/fullchain.pem" /etc/coturn/myaaptha-certs/fullchain.pem
install -m 0640 -o root -g turnserver "$RENEWED_LINEAGE/privkey.pem" /etc/coturn/myaaptha-certs/privkey.pem
systemctl try-restart coturn.service
''',0o700)
        limits=Path('/etc/systemd/system/coturn.service.d/myaaptha.conf');limits.parent.mkdir(parents=True,exist_ok=True)
        write(limits,'[Service]\nMemoryMax=256M\nCPUQuota=200%\nNoNewPrivileges=true\n',0o644)
        run(['systemctl','daemon-reload']);run(['systemctl','unmask','coturn.service']);run(['systemctl','enable','coturn.service']);run(['systemctl','restart','coturn.service']);run(['systemctl','is-active','--quiet','coturn.service'])
        values={'MYAAPTHA_TURN_URLS':f'turn:{public}:3478?transport=udp,turn:{public}:3478?transport=tcp,turns:{HOST}:5349?transport=tcp','MYAAPTHA_TURN_SHARED_SECRET':secret}
        lines=before.splitlines()
        for key,value in values.items():
            matches=[i for i,line in enumerate(lines) if line.startswith(key+'=')]
            if len(matches)>1:raise RuntimeError('Duplicate relay environment setting')
            entry=key+"='"+value+"'"
            if matches:lines[matches[0]]=entry
            else:lines.append(entry)
        write(env,'\n'.join(lines)+'\n')
    except Exception:
        write(env,before)
        if previous is not None:write(target,previous,0o640)
        if not existed:subprocess.run(['systemctl','disable','--now','coturn.service'],check=False)
        elif previous is not None:subprocess.run(['systemctl','restart','coturn.service'],check=False)
        raise RuntimeError('Relay configuration failed; previous backend environment restored. Inspect service state without displaying protected files.') from None
    print('Coturn service active; protected signing key and issued TLS certificate installed. Backend wiring and live relay acceptance still required.')

if __name__=='__main__':install()
