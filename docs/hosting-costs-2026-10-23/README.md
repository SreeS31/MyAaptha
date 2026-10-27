# MyAaptha hosting options and 36-month budget

Reviewed: 23 October 2026. USD list-price scenario, not a vendor quote or capacity certification.

## Recommendation

For the stated media-heavy growth target, DigitalOcean Bengaluru with managed PostgreSQL Advanced, managed Valkey and private Spaces is the balanced cost option. Choose AWS Mumbai when multi-AZ isolation, workload identity and the closest fit to the existing S3 adapter outweigh media-transfer cost. Hetzner Singapore is a lower infrastructure-price option only with an operations owner: the modeled databases are self-managed and its native object storage is in Europe.

The September project recommendation favored AWS for technical fit before these storage/concurrency targets were supplied. This dated cost comparison adds the new business assumptions; it does not select or provision a provider.

## Project basis

- Release application: Next.js/React, Java 21 Spring Boot API, PostgreSQL 17, Redis-compatible shared state, Python helper, ClamAV, private S3-style media, Flutter clients using the same API.
- Infrastructure includes Compose and Kubernetes templates; AWS ECS provisioning remains additional implementation work.
- Existing storage adapter explicitly sends SSE-S3 AES256. DigitalOcean Spaces and Hetzner document SSE-C support; R2 explicitly lacks that SSE-S3 request header. These services require provider-specific encryption/authentication/recovery integration before promotion. Do not simply remove encryption without choosing and validating an equivalent design.
- Private attachment endpoints currently stream through the API. Storage egress-free pricing does not remove application-host egress. Access-controlled direct delivery would require implementation and verification.
- Local documented load result: 20 requests/second for 30 seconds, 19 sessions, maximum 8 active k6 VUs. It does not prove 2,000 active users. Some readiness-document sections are historical; current launch acceptance remains tracked separately.

Source: [deployment handoff](../MYAAPTHA-DEPLOYMENT-HANDOFF.md), [scaling evidence](../scaling-readiness.md), [production Compose](../../infrastructure/production/docker-compose.prod.yml), [S3 adapter](../../backend/spring-boot-app/src/main/java/com/myaaptha/platform/media/S3MediaObjectStorage.java), and [current acceptance inputs](../launch-board/LAUNCH-INPUTS-2026-10-22.md).

## Explicit forecast assumptions

Only the six-month and three-year account targets, 10% concurrency, and 1-10 GB quota range came from the owner. Intermediate milestones, upgrade timing, fill level, download usage and cost allowances below are engineering planning assumptions.

| Period | Accounts budgeted throughout period | Peak sessions | Quota per account | 20% scenario average live use | Billable media including 20% overhead | Monthly user downloads |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Months 1-6 | 1,000 | 100 | 1 GiB | 0.2 GiB | 240 GiB | 1,000 GiB |
| Months 7-12 | 3,000 | 300 | 1 GiB | 0.2 GiB | 720 GiB | 3,000 GiB |
| Months 13-24 | 10,000 | 1,000 | 5 GiB | 1 GiB | 12,000 GiB | 10,000 GiB |
| Months 25-36 | 20,000 | 2,000 | 10 GiB | 2 GiB | 48,000 GiB | 20,000 GiB |

This charges the full phase account count every month, rather than assuming a precise signup curve. The 20% fill scenario is illustrative, not measured user behavior. The 100% scenario uses the same timing and assumes every user fills the quota. Recalculate when usage is measured. The forecast treats app quota units as GiB (matching the initial 1,073,741,824-byte setting); provider-specific units are normalized in the script.

The 20% overhead is for previews and retained versions; it is not a complete independent copy of all media. Database backups, a small staging allowance and routine operational infrastructure are in the base budget. A full second media backup copy is additional.

Prices are held constant over 36 months, without free-tier credits, commitments or startup discounts. INR uses a fixed planning assumption of INR 90/USD, not a current FX quotation. Taxes are excluded. Add a separate 20-25% approval contingency for currency, future prices and usage variance; it is not already included in the displayed figures.

## Monthly hosting forecast: 20% quota used

| Provider | Months 1-6 USD/month | Months 7-12 | Months 13-24 | Months 25-36 |
| --- | ---: | ---: | ---: | ---: |
| AWS Mumbai + S3 | $559-$819 | $945-$1,315 | $2,507-$3,257 | $4,890-$5,990 |
| DigitalOcean Bengaluru + Spaces | $455-$655 | $564-$884 | $1,140-$1,730 | $2,260-$3,250 |
| Hetzner Singapore + EU Object Storage | $228-$397 | $311-$558 | $676-$1,168 | $1,336-$2,119 |

## Monthly hosting forecast: 100% quota used

| Provider | Months 1-6 USD/month | Months 7-12 | Months 13-24 | Months 25-36 |
| --- | ---: | ---: | ---: | ---: |
| AWS Mumbai + S3 | $583-$843 | $1,017-$1,387 | $3,698-$4,448 | $9,502-$10,602 |
| DigitalOcean Bengaluru + Spaces | $474-$674 | $622-$942 | $2,100-$2,690 | $6,100-$7,090 |
| Hetzner Singapore + EU Object Storage | $231-$400 | $336-$584 | $1,139-$1,630 | $3,187-$3,970 |

At 20,000 users with 10 GiB fully used, live media is 200,000 GiB (about 214.7 decimal TB), and the modeled overhead raises billable storage to 240,000 GiB (about 257.7 TB). Hetzner documents a 100 TB per-bucket cap, so this scenario requires multiple buckets and application routing changes or a negotiated solution. The current adapter has one configured bucket; that capacity is not supported merely by changing a quota. Other providers also need account/service quota review.

## Annual and 36-month costs

| Scenario / provider | Year 1 USD | Year 2 USD | Year 3 USD | 36-month total USD | 36-month total INR lakh at 90/USD |
| --- | ---: | ---: | ---: | ---: | ---: |
| 20 percent used / AWS Mumbai + S3 | $9,026-$12,806 | $30,085-$39,085 | $58,684-$71,884 | $97,795-$123,775 | 88.0-111.4 |
| 20 percent used / DigitalOcean Bengaluru + Spaces | $6,116-$9,235 | $13,680-$20,757 | $27,120-$38,997 | $46,916-$68,989 | 42.2-62.1 |
| 20 percent used / Hetzner Singapore + EU Object Storage | $3,232-$5,731 | $8,117-$14,011 | $16,036-$25,424 | $27,385-$45,166 | 24.6-40.6 |
| 100 percent used / AWS Mumbai + S3 | $9,602-$13,382 | $44,379-$53,379 | $114,018-$127,218 | $168,000-$193,980 | 151.2-174.6 |
| 100 percent used / DigitalOcean Bengaluru + Spaces | $6,576-$9,695 | $25,200-$32,277 | $73,200-$85,077 | $104,976-$127,049 | 94.5-114.3 |
| 100 percent used / Hetzner Singapore + EU Object Storage | $3,402-$5,901 | $13,670-$19,564 | $38,249-$47,637 | $55,322-$73,102 | 49.8-65.8 |

## What makes up the budget

Base infrastructure allowances below exclude media bytes, internet delivery and separately identified media-operation allowance. These are sizing estimates, not published provider bundle prices. They include continuously running services, redundant application instances, database primary/standby, cache redundancy, load balancing, database disk/backup allowance, modest monitoring/secrets/WAF allowance and a small staging environment. Large production-equivalent staging or extensive log retention requires more.

| Base cloud allowance USD/month | Months 1-6 | Months 7-12 | Months 13-24 | Months 25-36 |
| --- | ---: | ---: | ---: | ---: |
| AWS | 450-700 | 600-950 | 1,100-1,800 | 1,700-2,700 |
| DigitalOcean | 450-650 | 550-850 | 900-1,400 | 1,300-2,100 |
| Hetzner | 220-380 | 300-520 | 550-950 | 850-1,450 |

AWS launch anchor: aggregate 4 vCPU / 10 GiB Fargate across two copies of API/frontend/helper/scanner is about $158/month at 730 hours; t4g.medium Multi-AZ PostgreSQL compute about $122; two small Valkey nodes about $48. The remaining base allowance covers database storage, networking, load balancer, secrets/logs/edge controls and staging. Burstable database CPU credits can add cost; sustained workload should use the later non-burstable database allowance. At the final phase, approximately $600 application compute, $660 Multi-AZ database compute, $95 cache and $345 additional infrastructure explain the lower $1,700 baseline. These totals are not a tested capacity promise.

DigitalOcean launch anchor: two $48 8-GiB application VMs ($96), Advanced PostgreSQL primary and standby ($260 minimum before extra database disk), cache and roughly $60-100 of load balancer/backup/staging/operations. The minimum new-account HA database requires Advanced Edition under the published October 2026 plan changes. The model does not use a legacy $60 HA Standard configuration. Its low transfer bound requires same-region private Spaces reads and sufficient pooled Droplet transfer (at least 20,000 GiB/month in the final phase). Upper bound budgets separately billed direct Spaces downloads; actual topology must be verified.

Hetzner launch anchor: Singapore CPX32 list price is $57.99, CPX22 $30.99, excluding IPv4. Two application VMs plus two smaller database VMs are about $178 before ancillary costs; Redis can share those hosts only with explicit memory isolation and failover design. Larger stages budget dedicated compute and more database/cache capacity. This is self-managed PostgreSQL/Redis, with no managed-database service, staffing or application-level HA promise included.

## Price anchors checked against primary sources

| Service | Price basis used | Source |
| --- | --- | --- |
| AWS Fargate Mumbai, Linux x86 | $0.04256/vCPU-hour + $0.004655/GiB-hour | [AWS Fargate](https://aws.amazon.com/fargate/pricing/) and dated public rate snapshot |
| AWS RDS PostgreSQL Mumbai | t4g.medium Multi-AZ $0.167/hour; m6g.large $0.452/hour; m6g.xlarge $0.904/hour, database storage extra | [RDS pricing](https://aws.amazon.com/rds/postgresql/pricing/) and snapshot |
| AWS ElastiCache Valkey Mumbai | t4g.small $0.0328/node-hour, t4g.medium $0.0648/node-hour | [ElastiCache](https://aws.amazon.com/elasticache/pricing/) and snapshot |
| AWS S3 Standard Mumbai | First 51,200 billed GB $0.025/month; next tier $0.024 | [S3 pricing](https://aws.amazon.com/s3/pricing/) and snapshot |
| AWS Mumbai internet delivery | Global first 100 billed GB free, first paid 10,240 GB $0.1093/GB, next 40,960 GB $0.085/GB | [AWS Data Transfer public rate list](https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AWSDataTransfer/current/ap-south-1/index.json) |
| DigitalOcean VMs | Shared 4-vCPU/8-GiB $48/month; dedicated 2-vCPU/8-GiB $63/month | [Droplet pricing](https://www.digitalocean.com/pricing/droplets) |
| DigitalOcean HA PostgreSQL | Advanced primary from $130/month, matching standby same rate; extra disk $0.115/GiB/month | [PostgreSQL pricing and plan changes](https://docs.digitalocean.com/products/databases/postgresql/details/pricing/) |
| DigitalOcean Spaces | $5/month includes 250 GiB; extra $0.02/GiB/month; 1,024 GiB internet transfer then $0.01/GiB | [Spaces pricing](https://docs.digitalocean.com/products/spaces/details/pricing/) |
| Hetzner Singapore compute | CPX32 $57.99/month; CPX22 $30.99; IPv4 extra | [Current price adjustment](https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/) |
| Hetzner EU objects | $7.99/month base; extra storage $0.0123/TB-hour; extra object egress $1.20/TB | [Object storage](https://www.hetzner.com/storage/object-storage/) and public product APIs CLOUD_84, CLOUD_85, CLOUD_86 in snapshot |
| Hetzner Singapore transfer | Plan-specific included allowance; extra $8.49/TB | [Singapore pricing](https://www.hetzner.com/cloud-singapore/) |
| Cloudflare R2 Standard alternative | $0.015/decimal GB-month, no direct R2 egress fee, operations extra | [R2 pricing](https://developers.cloudflare.com/r2/pricing/) |

AWS media-operation allowance in the model is $5-15, $10-30, $25-75 and $50-150/month by phase. It is a planning allowance, not a measured operation count. ALB/network overhead and routine cross-AZ allowance are in the base ranges. No AWS media-transfer charge is counted twice when a download travels from same-region S3 through the API to the internet. The model assumes an S3 gateway endpoint rather than routing bulk S3 downloads through a metered NAT gateway.

## Performance, speed and availability

| Factor | AWS Mumbai | DigitalOcean Bengaluru | Hetzner Singapore + EU objects |
| --- | --- | --- | --- |
| Indian-user origin latency | Favorable India region; test actual ISP routes | Favorable India region; test actual ISP routes | Additional Singapore distance; private-file cache misses also reach Europe |
| Compute scaling | Fargate service scaling; managed network/database ecosystem | Straightforward VM scaling; dedicated CPU for sustained loads | Shared CPU varies; dedicated CCX for steady workloads, automation maintained by us |
| Database operations | RDS manages backups/failover; configure Multi-AZ | Advanced PostgreSQL standby/failover; validate BLR plan availability | Our team owns patches, replication, failover, PITR, monitoring and recovery |
| Published service SLA | Fargate Multi-AZ 99.99%; RDS Multi-AZ 99.95% | CPU Droplet 99.99%; database with standby 99.95% | Cloud server 99.9%; not an application/database uptime guarantee |
| Failure isolation | Explicit multi-AZ architecture available | Same-region host redundancy is not automatically equivalent to AWS AZ isolation | Separate hosts alone do not prove independent failure domains |
| Media placement | Mumbai S3, private access policies | Bengaluru Spaces; verify encryption integration | Native storage currently only Germany/Finland |
| Fit to current app | Closest storage/identity fit; ECS infrastructure still needed | Compatible app runtime; encryption and Valkey acceptance required | More operations and storage changes; multi-bucket changes at full capacity |

Speed comparisons above are geographic/architectural expectations, not measured vendor benchmarks. The application SLA is not the SLA of one component. For perspective, 99.9% corresponds to about 43 minutes in a 30-day month, 99.95% about 22 minutes, and 99.99% about 4 minutes; service credits, exclusions and measurement terms differ. Regional outage recovery is not included as an active second-region deployment.

Primary availability sources: [AWS ECS/Fargate SLA](https://aws.amazon.com/ecs/sla/), [RDS SLA](https://aws.amazon.com/rds/sla/), [DigitalOcean CPU SLA](https://www.digitalocean.com/sla/cpu-droplets), [DigitalOcean database SLA](https://www.digitalocean.com/sla/databases), [DigitalOcean regions](https://docs.digitalocean.com/platform/regional-availability/), [Hetzner cloud SLA](https://www.hetzner.com/legal/cloud-server/), and [Hetzner object endpoints](https://docs.hetzner.com/storage/object-storage/overview/).

## Capacity plan and acceptance

For initial planning, 100 active sessions each making one request every five seconds is 20 RPS; 2,000 such sessions is 400 RPS, before polling, uploads and other background work. If they make one request per second instead, final load is 2,000 RPS and the estimate needs resizing. Concurrent sessions are not simultaneous in-flight HTTP requests. Calling concurrency is a separate workload.

Begin with two API/application instances, independent managed database primary/standby and redundant Redis-compatible state. The VM option uses two 8-GiB app hosts at launch, which must accommodate ClamAV as well as Java/Next/Python. By the final phase, initially evaluate roughly 8-16 aggregate dedicated API vCPUs, separately budgeted frontend/scanner/helper capacity, an 8-16 GiB HA database and cache capacity; let measured database CPU, memory, connection pressure and API p95 determine resizing. Bound replica DB pools to the connection budget. A 2,000-session capacity commitment requires staged representative 100/300/1,000/2,000-session tests, soak tests, failover, upload/download and restore drills.

## Storage sensitivity and cost controls

Quota does not reserve physical object bytes. A 10-GiB limit for every account does not create a 200,000-GiB bill unless files are stored. Offer the larger limit as a paid tier rather than assuming every user must immediately be upgraded. At final scale, each additional average 1 GiB actually stored per account adds 24,000 GiB including the modeled overhead: about $480/month on Spaces, roughly $600/month in the first S3 tier (slightly less in the next tier), or about $231/month in marginal Hetzner storage. Downloads and other services are separate.

Cloudflare R2 is an alternative to evaluate for frequently downloaded media, not an already-supported drop-in. At the final 20% scenario, 48,000 GiB is about 51,540 decimal GB, costing about $773/month at the R2 Standard list rate before operations, versus $960 Spaces or $1,200 S3 storage. R2 direct egress is free, but API-proxied delivery still incurs VM/cloud egress. Provider-native encryption, private URL authorization, checksums, deletion and recovery semantics need implementation and tests. R2 versioning is not interchangeable with S3 versioned recovery, and India-only placement must not be assumed. See [R2 compatibility](https://developers.cloudflare.com/r2/api/s3/api/), [Spaces compatibility](https://docs.digitalocean.com/products/spaces/reference/s3-compatibility/), [Hetzner encryption limitations](https://docs.hetzner.com/storage/object-storage/supported-actions/).

## Not included in hosting totals

- AI inference/API usage, SMS/WhatsApp/email delivery and third-party subscription charges. The Python helper hosting is included; model tokens are not. Estimate each from events per user, unit price and retry rate after providers/models are chosen.
- TURN-relayed voice/video, SFU/group calling, recording/transcoding or continuous video streaming. These can materially change bandwidth and compute costs; 2,000 concurrent app users must not be treated as 2,000 simultaneous calls.
- A complete second independent media copy, cross-region active disaster-recovery infrastructure, long immutable media retention or unlimited version retention.
- Paid premium cloud support, engineers/on-call staff, independent penetration tests, legal work, store fees and one-time provider migration/integration work.
- GST/other taxes, payment processing and future exchange-rate changes. At an illustrative applicable 18% tax, multiply by 1.18; actual invoicing and tax-credit treatment depend on the purchasing entity.

## Reuse the calculation

[Monthly CSV, 216 provider/scenario rows](monthly-forecast.csv) opens in Excel. [JSON summary](forecast-summary.json) contains annual totals and phase details. [Dated primary price snapshot](price-snapshot.json) records fetched public rates. Run `python docs/hosting-costs-2026-10-23/forecast.py` to regenerate after editing clearly marked planning assumptions. This does not create cloud resources or contact users.
