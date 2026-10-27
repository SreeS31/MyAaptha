"""Reproduce an indicative 36-month hosting budget; no cloud access."""
from pathlib import Path
import csv
import json

OUT = Path(__file__).resolve().parent
FX = 90  # Planning assumption, INR/USD; not a live exchange-rate claim.
GIB_TO_TB = 2**30 / 10**12
PHASES = [
    # months, accounts, quota GiB, low/high base cloud allowance by provider
    (6, 1000, 1, [(450, 700), (450, 650), (220, 380)]),
    (6, 3000, 1, [(600, 950), (550, 850), (300, 520)]),
    (12, 10000, 5, [(1100, 1800), (900, 1400), (550, 950)]),
    (12, 20000, 10, [(1700, 2700), (1300, 2100), (850, 1450)]),
]
PROVIDERS = ['AWS Mumbai + S3', 'DigitalOcean Bengaluru + Spaces',
             'Hetzner Singapore + EU Object Storage']


def tiers(amount, bands):
    result = 0
    for quantity, rate in bands:
        used = min(amount, quantity)
        result += used * rate
        amount -= used
        if amount <= 0:
            break
    return result


def media(provider, stored_gib, download_gib, phase):
    """Storage plus one end-user delivery path, avoiding double-counted AWS egress.

    DO lower bound uses same-region private Spaces -> API + included Droplet
    transfer. Upper bound budgets direct Spaces delivery without that benefit.
    Hetzner upper bound deliberately ignores included Singapore VM bandwidth;
    native EU object-store egress is counted separately on its real hop.
    """
    if provider == 0:
        storage = tiers(stored_gib, [(51200, .025), (460800, .024), (float('inf'), .023)])
        delivery = tiers(max(0, download_gib-100), [
            (10240, .1093), (40960, .085), (102400, .082), (float('inf'), .08)])
        return storage, delivery, delivery, [5, 10, 25, 50][phase], [15, 30, 75, 150][phase]
    if provider == 1:
        storage = 5 + max(0, stored_gib-250)*.02
        direct_delivery = max(0, download_gib-1024)*.01
        return storage, 0, direct_delivery, 0, 0
    storage_tb = stored_gib * GIB_TO_TB
    download_tb = download_gib * GIB_TO_TB
    # 730-hour average month; included quota is 730 TB-hours, i.e. 1 TB average.
    storage = 7.99 + max(0, storage_tb-1)*730*.0123
    object_delivery = max(0, download_tb-1)*1.2
    singapore_delivery = download_tb*8.49  # Conservative: ignores VM allowance.
    return storage, object_delivery, object_delivery+singapore_delivery, 0, 0


def build():
    rows = []
    for scenario, fill in [('20_percent_used', .2), ('100_percent_used', 1.)]:
        month = 0
        for phase, (duration, accounts, quota, allowances) in enumerate(PHASES):
            for _ in range(duration):
                month += 1
                for provider, name in enumerate(PROVIDERS):
                    live_gib = accounts*quota*fill
                    billed_gib = live_gib*1.2
                    storage, transfer_low, transfer_high, ops_low, ops_high = media(
                        provider, billed_gib, accounts, phase)
                    low, high = allowances[provider]
                    rows.append(dict(
                        scenario=scenario, month=month, year=(month-1)//12+1,
                        phase=phase+1, provider=name, accounts=accounts,
                        peak_sessions=accounts//10, quota_gib_per_account=quota,
                        fill_fraction=fill, live_gib=live_gib, billed_gib=billed_gib,
                        downloads_gib=accounts, base_low_usd=low, base_high_usd=high,
                        storage_usd=round(storage, 2), transfer_low_usd=round(transfer_low, 2),
                        transfer_high_usd=round(transfer_high, 2),
                        media_ops_low_usd=ops_low, media_ops_high_usd=ops_high,
                        total_low_usd=round(low+storage+transfer_low+ops_low, 2),
                        total_high_usd=round(high+storage+transfer_high+ops_high, 2),
                        planning_inr_per_usd=FX,
                        total_low_inr=round((low+storage+transfer_low+ops_low)*FX),
                        total_high_inr=round((high+storage+transfer_high+ops_high)*FX)))
    return rows


def main():
    rows = build()
    assert len(rows) == 216
    assert all(r['total_low_usd'] <= r['total_high_usd'] for r in rows)
    assert all(len([r for r in rows if r['provider']==p and r['scenario']==s]) == 36
               for p in PROVIDERS for s in ['20_percent_used', '100_percent_used'])
    assert abs(tiers(60000, [(51200,.025),(460800,.024)]) - 1491.2) < .00001
    with (OUT/'monthly-forecast.csv').open('w', newline='', encoding='utf-8-sig') as f:
        writer=csv.DictWriter(f, fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    summary=[]
    for scenario in ['20_percent_used', '100_percent_used']:
        for provider in PROVIDERS:
            selected=[r for r in rows if r['scenario']==scenario and r['provider']==provider]
            years=[]
            for year in [1,2,3]:
                subset=[r for r in selected if r['year']==year]
                years.append(dict(year=year,
                    low_usd=round(sum(r['total_low_usd'] for r in subset),2),
                    high_usd=round(sum(r['total_high_usd'] for r in subset),2)))
            summary.append(dict(scenario=scenario,provider=provider,years=years,
                total_low_usd=round(sum(r['total_low_usd'] for r in selected),2),
                total_high_usd=round(sum(r['total_high_usd'] for r in selected),2),
                phase_monthly=[selected[m-1] for m in [6,12,24,36]]))
    (OUT/'forecast-summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    for entry in summary:
        print(entry['scenario'],entry['provider'],
              [(r['total_low_usd'],r['total_high_usd']) for r in entry['phase_monthly']],
              '36 months',entry['total_low_usd'],entry['total_high_usd'])


if __name__ == '__main__':main()
