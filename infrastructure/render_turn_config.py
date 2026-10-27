"""Render a protected Coturn configuration locally, without contacting any relay."""
import argparse
import ipaddress
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parent/'production'

def render(template,secret,public_ip,private_ip):
    public=ipaddress.IPv4Address(public_ip);private=ipaddress.IPv4Address(private_ip)
    if not public.is_global or not private.is_private or private.is_loopback or private.is_link_local:
        raise ValueError('Use the assigned public IPv4 and private interface IPv4')
    if not re.fullmatch(r'[A-Za-z0-9_-]{32,128}',secret):raise ValueError('Invalid protected relay signing secret')
    result=template.replace('REPLACE_WITH_PROTECTED_SHARED_SECRET',secret).replace('REPLACE_PUBLIC_IPV4',str(public)).replace('REPLACE_PRIVATE_IPV4',str(private))
    if 'REPLACE_' in result:raise ValueError('Unresolved relay configuration placeholder')
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--public-ip',required=True)
    parser.add_argument('--private-ip',required=True)
    args=parser.parse_args()
    try:
        secret=(ROOT/'secrets/integrations/myaaptha.calls.turn-secret').read_text(encoding='utf-8').strip()
        text=render((ROOT/'turnserver.conf.example').read_text(encoding='utf-8'),secret,args.public_ip,args.private_ip)
        with (ROOT/'secrets/turnserver.conf').open('x',encoding='utf-8') as f:f.write(text)
    except (OSError,ValueError):parser.exit(1,'Relay configuration not written. Check IP assignments, protected secret access and whether a configuration already exists.\n')
    print('Protected relay configuration written; shared secret not printed. Live relay acceptance is still required.')

if __name__=='__main__':main()
