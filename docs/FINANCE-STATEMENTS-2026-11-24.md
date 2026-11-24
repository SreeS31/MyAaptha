# Statement imports and finance reports

The finance update adds reviewed statement imports and calendar reports to the shared API, web and Flutter app. This update was deployed and verified on the beta VM on 24 November 2026.

## User flow

1. Open Finance and choose **Upload statement**. In the native app, open **Statements & reports**.
2. Give the account a memorable label, select the statement and its date order. Keep the label and timezone consistent for later imports of the same account.
3. Review the rows and suggested purposes. Correct categories or exclude rows before saving. Unreadable dates/amounts and unsupported currencies are flagged. Exact previously imported rows cannot be selected. Possible matches to recorded SMS/manual transactions start unselected and can be included after review.
4. View monthly, calendar-quarter or yearly income, spending, net, purposes and month-by-month totals. Choose a timezone and anchor month. Transfers are displayed separately and excluded from income/spending/net. Net is recorded cashflow, not an account balance.
5. Correct saved categories and export the selected period as CSV.

## Supported statements and limits

- CSV/TSV text and Excel XLSX: recognizable Date/Description and Debit/Credit columns, or Amount with DR/CR/Type. Signed negative amounts indicate expenses; unsigned positive amounts without direction are flagged rather than guessed. Headers may follow statement preamble lines.
- Text-based PDF: bounded extraction with [Apache PDFBox](https://pdfbox.apache.org/3.0/migration.html), requiring an explicitly labelled DR/CR amount in each transaction line. Running balances are not transaction amounts. Scanned PDFs, complex separate-column PDF layouts and password-protected documents need a bank CSV/Excel or unlocked readable PDF export. There is no OCR or external AI processing.
- INR only, 10 MB per file, 2,000 transaction rows, 100 columns, one Excel worksheet and 100 PDF pages. Ambiguous or incomplete extraction is surfaced; the user should compare the preview with the statement.
- Files are parsed in the request and are not retained as media assets. Only selected ledger entries are saved. Existing encrypted financial amount/merchant/description storage is retained. Account labels are used in hashed duplicate keys; bank login credentials are neither requested nor stored.
- Suggested purposes include groceries, clothing, shopping, food, utilities, bills, housing, transport, travel, health, insurance, education, entertainment, investment, tax, fees, salary, business, interest, refund, transfer and other. Unrecognized purposes remain Other; classification is editable and is not a claim of verified merchant intent.

## API

| Endpoint | Behaviour |
| --- | --- |
| `POST /api/finance/statements/preview` | Multipart file, account label, DMY/MDY/ISO date order, IANA timezone; returns rows, issues, duplicate flags and suggestions without saving. |
| `POST /api/finance/statements/commit` | Reviewed rows and the same account label; atomic import, per-user lock, duplicate keys scoped to the authenticated owner. |
| `GET /api/finance/reports` | MONTH/QUARTER/YEAR period, YYYY-MM anchor and IANA zone; explicit calendar boundaries, totals, expense/income categories, timeline and transactions. |
| `GET /api/finance/reports/export` | Same period arguments; CSV quoting and spreadsheet formula protection, no-store response. |
| `POST /api/finance/transactions/{id}/category` | Correct an owned transaction; other owners receive 404. |
| `GET /api/finance/categories` | Shared category catalogue. |

Existing manual/SMS APIs remain compatible. Exact re-import detection uses account label plus canonical source transaction data and occurrence count, preserving multiple identical legitimate rows in one statement. Possible SMS/manual matches use local date, direction and amount; they need review. Different descriptions/references, aliases, timezones or incomplete overlapping exports can require manual duplicate review. No automatic bank login, balance reconciliation, currency conversion, tax filing or investment advice is provided.

## Validation and release

Pending final local checks, exact-commit CI/image scans and the guarded GCP rollout. Live checks use synthetic CSV statements and removable test accounts only.


## Verified release

- Source `9e1b074eb0a58b19bbc5d7d4a138746fb27289dd`, tag `beta-20261124-finance-statements-r3`; [CI](https://github.com/SreeS31/MyAaptha/actions/runs/45325304451) and [image validation/scans](https://github.com/SreeS31/MyAaptha/actions/runs/45325303724) passed.
- Backend: 306 tests, zero failures/errors, one skip. This includes 22 targeted finance tests. Browser: 80 scenarios completed, with one existing diary-layout check passing on retry in image validation; finance scenarios passed first attempt. Web units: 26 passed. Native: clean analysis, 127 tests passed, two expected skips.
- Matching Android debug test APK: `.tools/preview/MyAaptha-beta-finance-statements-20261124.apk`, SHA-256 `6fed086d00ff1464d44fc059ce690f87f093fe50392359cbab5f30d2ad776bf1`. Physical-device and iOS acceptance remain pending; this is not an app-store publication.
- GCP immutable image references and deployment evidence: `infrastructure/production/finance-statements-images-20261124.json`. Fresh database backup restored into a disposable database and user count checked before the rollout. Existing schema 77 was retained; no new migration was required. Final HTTPS/API health: UP; Google Contacts and TURN configuration/service preserved.
- Four live desktop/mobile finance and public-quality checks passed. Invented statement data produced INR 1,000 income, 150 spending and 850 net, excluding 200 of transfer movements. Category correction, calendar-quarter/year reports, CSV download and repeat-import duplicate exclusion passed.
- Two exact synthetic accounts and eight private ledger rows were removed with identity-guarded cleanup. Zero test transactions or active media remain. No real bank statements were used in validation.
