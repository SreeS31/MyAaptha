"""Render non-secret Kubernetes release files; never contact a cluster.

Usage: python infrastructure/render_release.py infrastructure/release.json
Requires PyYAML (python -m pip install -r infrastructure/requirements.txt).
"""
import argparse
import json
import re
from pathlib import Path
import yaml

ROOT = Path(__file__).resolve().parent

def validate(config):
    required = ('domain', 'redis_host', 'postgres_host', 'postgres_database', 'postgres_user', 'storage_bucket',
                'storage_region', 'ingress_class', 'ingress_namespace', 'backend_image', 'frontend_image', 'ai_image')
    for key in required:
        value = config.get(key)
        if not isinstance(value, str) or not value.strip():
            raise ValueError(f'Missing value: {key}')
        if re.search(r'example|replace|dummy|OWNER|VERSION|localhost|\.invalid', value, re.I):
            raise ValueError(f'Replace the placeholder in {key}')
        if key.endswith('_image'):
            if not re.fullmatch(r'[a-z0-9./_-]+@sha256:[a-f0-9]{64}', value):
                raise ValueError(f'{key} must be an immutable registry image digest')
        elif not re.fullmatch(r'[a-zA-Z0-9][a-zA-Z0-9._-]*', value):
            raise ValueError(f'Invalid characters in {key}')
    if '.' not in config['domain']:
        raise ValueError('domain must be a public DNS hostname')

    proxies=config.get('trusted_proxy_regex','')
    if not proxies or re.search(r'replace|example|dummy',proxies,re.I) or proxies in ('.*','.+'):
        raise ValueError('Set trusted_proxy_regex to the actual private ingress and frontend proxy addresses')
    try:re.compile(proxies)
    except re.error as error:raise ValueError('Invalid trusted_proxy_regex') from error
    defaults={'backend_max_replicas':10,'db_pool_size':20,'db_connection_budget':260,'db_reserved_connections':40}
    for key,default in defaults.items():
        if type(config.get(key,default)) is not int or config.get(key,default)<1:
            raise ValueError(f'{key} must be a positive integer')
    replicas=config.get('backend_max_replicas',10)
    if replicas<2:raise ValueError('At least two backend replicas are required')
    # Include one surge replica during rolling updates and a separate reserve.
    if (replicas+1)*config.get('db_pool_size',20)+config.get('db_reserved_connections',40)>config.get('db_connection_budget',260):
        raise ValueError('Backend pools plus rolling-update surge and reserve exceed database connection budget')

def render(config, destination):
    validate(config)
    destination.mkdir(parents=True, exist_ok=True)
    images = {'backend': config['backend_image'], 'frontend': config['frontend_image'], 'ai-agent': config['ai_image']}
    for source in (ROOT / 'kubernetes').glob('*.yaml'):
        objects = list(yaml.safe_load_all(source.read_text()))
        for obj in objects:
            kind = obj['kind']
            if kind in ('Deployment', 'Job'):
                for container in obj['spec']['template']['spec']['containers']:
                    container['image'] = images.get(container['name'], config['backend_image'])
            elif kind == 'ConfigMap':
                obj['data'].update(TRUSTED_PROXY_REGEX=config['trusted_proxy_regex'], DB_POOL_SIZE=str(config.get('db_pool_size',20)), REDIS_HOST=config['redis_host'], POSTGRES_HOST=config['postgres_host'], POSTGRES_DB=config['postgres_database'],
                    POSTGRES_USER=config['postgres_user'], MYAAPTHA_S3_BUCKET=config['storage_bucket'],
                    MYAAPTHA_S3_REGION=config['storage_region'], MYAAPTHA_CORS_ALLOWED_ORIGINS='https://' + config['domain'],
                    MYAAPTHA_PUBLIC_API_BASE_URL='https://' + config['domain'], MYAAPTHA_WEB_ORIGIN='https://' + config['domain'])
            elif kind == 'HorizontalPodAutoscaler' and obj['metadata']['name']=='backend':
                obj['spec']['maxReplicas']=config.get('backend_max_replicas',10)
            elif kind == 'Ingress':
                obj['spec']['ingressClassName'] = config['ingress_class']
                obj['spec']['tls'][0]['hosts'] = [config['domain']]
                obj['spec']['rules'][0]['host'] = config['domain']
            elif kind == 'NetworkPolicy' and obj['metadata']['name'] == 'public-gateway':
                obj['spec']['ingress'][0]['from'][0]['namespaceSelector']['matchLabels']['kubernetes.io/metadata.name'] = config['ingress_namespace']
        name = 'config.yaml' if source.name == 'config.example.yaml' else source.name
        (destination / name).write_text(yaml.safe_dump_all(objects, sort_keys=False))

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('config', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / 'kubernetes/rendered')
    args = parser.parse_args()
    try:
        render(json.loads(args.config.read_text()), args.output)
    except (ValueError, OSError) as ex:
        parser.exit(1, str(ex) + '\n')
    print('Rendered release manifests. Provision secrets, TLS and storage identity before deployment.')
