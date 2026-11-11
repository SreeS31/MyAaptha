#!/bin/bash
set -euo pipefail
umask 077
base=https://raw.githubusercontent.com/SreeS31/MyAaptha/c9229fd23178e80fd6799ade4f1ee749e6ce3968/infrastructure
install -d -m 0700 /opt/myaaptha-beta/network-repair/production
curl --retry 4 -fsSL "$base/repair_gcp_beta_network.py" -o /opt/myaaptha-beta/network-repair/repair_gcp_beta_network.py
curl --retry 4 -fsSL "$base/production/compose.gcp-beta.yml" -o /opt/myaaptha-beta/network-repair/production/compose.gcp-beta.yml
python3 /opt/myaaptha-beta/network-repair/repair_gcp_beta_network.py
