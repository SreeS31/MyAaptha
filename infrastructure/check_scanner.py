"""Check the same ClamAV signature freshness enforced by the API before preview startup."""
import argparse
from datetime import datetime, timedelta, timezone
import socket
import time

def signature_is_fresh(version, now=None, max_age_hours=48):
    now=now or datetime.now(timezone.utc)
    parts=version.split('/')
    if len(parts)<3:
        raise ValueError('Scanner returned no signature date.')
    stamp=datetime.strptime(' '.join(parts[2].split()),'%a %b %d %H:%M:%S %Y').replace(tzinfo=timezone.utc)
    return now-timedelta(hours=max_age_hours)<=stamp<=now+timedelta(hours=1)

def command(host,port,name):
    with socket.create_connection((host,port),timeout=3) as connection:
        connection.settimeout(3)
        connection.sendall(('z'+name+'\0').encode('ascii'))
        response=bytearray()
        while len(response)<4096:
            chunk=connection.recv(1)
            if chunk in (b'',b'\0',b'\n'):return response.decode('ascii').strip()
            response.extend(chunk)
        raise ValueError('Unexpected scanner response length.')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host',default='127.0.0.1')
    parser.add_argument('--port',type=int,default=53310)
    parser.add_argument('--wait',type=int,default=60)
    parser.add_argument('--reload-if-stale',action='store_true')
    args=parser.parse_args()
    if not 0<=args.wait<=120:parser.error('Wait must be between 0 and 120 seconds.')
    deadline=time.monotonic()+args.wait
    reloaded=False
    while True:
        try:
            version=command(args.host,args.port,'VERSION')
            if signature_is_fresh(version):
                print('Scanner ready: signatures satisfy the API 48-hour freshness policy.',flush=True)
                return 0
            if args.reload_if_stale and not reloaded:
                # Reload only published databases already on disk. This never accepts an old
                # database, creates a fake signature date, or bypasses the server scanner.
                print('Scanner signatures are stale; reloading downloaded databases.',flush=True)
                command(args.host,args.port,'RELOAD');reloaded=True
            failure='Scanner signatures remain stale. Update the ClamAV databases and retry.'
        except (OSError,ValueError) as error:
            failure=f'Scanner readiness check failed: {error}'
        if time.monotonic()>=deadline:
            print(failure,flush=True)
            return 1
        time.sleep(2)

if __name__=='__main__':raise SystemExit(main())
