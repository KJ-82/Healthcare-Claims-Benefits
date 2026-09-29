# HIPAA-Style Safeguards

This project uses synthetic data only. These are the safeguards the code demonstrates
and how they map to real HIPAA expectations.

| Safeguard | Where | Why |
|---|---|---|
| Access control | `X-Api-Key` check in `Program.cs` | Only authorized users reach PHI |
| Audit logging | `AuditLog` table + `Audit()` | Track who accessed what and when |
| Data masking | `MaskMember()` | Minimum necessary: show only what is needed |
| Parameterized SQL | All Dapper queries | Prevents SQL injection |
| Input validation | Status allow-list, ICD-10 regex | Rejects malformed input |
| No secrets in repo | `CLAIMS_DB`, `API_KEY` env vars | Prevents credential leaks |
| No PHI in logs | Audit stores IDs only | Logs are not a data leak path |
| HTTPS | `UseHttpsRedirection()` | Encryption in transit |

## Production notes (not implemented here)
- Encryption at rest (e.g. SQL Server TDE)
- Per-user authentication and role-based access (Analyst vs. ReadOnly)
- Audit log retention and review process
- Business Associate Agreements with any vendor that touches PHI
