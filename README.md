# Healthcare Claims & Benefits

Synthetic health plan database (SQL Server / T-SQL) with a small ASP.NET Core API (C#).
Main Subjects: Benefit configuration, claims validation, and HIPAA-conscious API design.

**All data is fictional. No real PHI.**

## Files
- `sql/01_schema_and_seed.sql` tables and synthetic data
- `sql/02_config_queries.sql` benefit lookups and configuration validation checks
- `Api/` ASP.NET Core API: benefits by date, claim lookup, ICD-10 lookup
- `docs/hipaa-safeguards.md` safeguards used and why

## Run
1. Run the two SQL files in order
2. Set env vars `CLAIMS_DB` (connection string) and `API_KEY`
3. `dotnet run --project Api`
4. Send header `X-Api-Key` with each request

## Endpoints
- `GET /api/plans/{planId}/benefits?asOf=2026-08-01`
- `GET /api/claims/{claimId}`
- `GET /api/claims?status=Denied`
- `GET /api/codes/icd10/{code}`

## Configuration validation checks
`02_config_queries.sql` checks for overlapping benefit dates, missing service
categories per plan, claims outside member eligibility, and claims with no
matching benefit. On clean configuration, each check returns 0 rows.
