using System.Text.RegularExpressions;
using Dapper;
using Microsoft.Data.SqlClient;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// Secrets come from environment variables, never from the repo (HIPAA safeguard)
var connStr = Environment.GetEnvironmentVariable("CLAIMS_DB")
    ?? throw new InvalidOperationException("Set CLAIMS_DB");
var apiKey = Environment.GetEnvironmentVariable("API_KEY")
    ?? throw new InvalidOperationException("Set API_KEY");

app.UseHttpsRedirection();

// Access control: every request needs the API key
app.Use(async (ctx, next) =>
{
    if (!ctx.Request.Headers.TryGetValue("X-Api-Key", out var key) || key.ToString() != apiKey)
    {
        ctx.Response.StatusCode = 401;
        return;
    }
    await next();
});

// Audit: record who accessed what (IDs only, no PHI)
async Task Audit(string action, string entity, string id)
{
    using var db = new SqlConnection(connStr);
    await db.ExecuteAsync(
        "INSERT INTO AuditLog (UserName, Action, Entity, EntityId) VALUES (@u, @a, @e, @i)",
        new { u = "api-key-user", a = action, e = entity, i = id });
}

// Masking: show only the last 4 characters of a member number
static string MaskMember(string n) =>
    n.Length <= 4 ? "****" : new string('*', n.Length - 4) + n[^4..];

// GET benefits in effect for a plan on a date
app.MapGet("/api/plans/{planId:int}/benefits", async (int planId, DateOnly? asOf) =>
{
    var date = (asOf ?? DateOnly.FromDateTime(DateTime.UtcNow)).ToDateTime(TimeOnly.MinValue);
    using var db = new SqlConnection(connStr);
    var rows = await db.QueryAsync<Benefit>(
        @"SELECT ServiceCategory, Copay, Coinsurance, PriorAuthRequired
          FROM BenefitConfig
          WHERE PlanId = @planId AND EffectiveDate <= @date
            AND (TermDate IS NULL OR TermDate >= @date)",
        new { planId, date });
    await Audit("READ", "Benefits", planId.ToString());
    return Results.Ok(rows);
});

// GET one claim with lines (member number masked)
app.MapGet("/api/claims/{claimId:int}", async (int claimId) =>
{
    using var db = new SqlConnection(connStr);
    var claim = await db.QuerySingleOrDefaultAsync<ClaimHeader>(
        @"SELECT c.ClaimId, m.MemberNumber, c.ServiceDate, c.ClaimStatus
          FROM Claims c JOIN Members m ON m.MemberId = c.MemberId
          WHERE c.ClaimId = @claimId",
        new { claimId });
    if (claim is null) return Results.NotFound();

    var lines = await db.QueryAsync<ClaimLineDto>(
        @"SELECT CptCode, Icd10Code, BilledAmount, AllowedAmount, LineStatus, DenialReason
          FROM ClaimLines WHERE ClaimId = @claimId",
        new { claimId });

    await Audit("READ", "Claim", claimId.ToString());
    return Results.Ok(new
    {
        claim.ClaimId,
        MemberNumber = MaskMember(claim.MemberNumber),
        claim.ServiceDate,
        claim.ClaimStatus,
        Lines = lines
    });
});

// GET claims by status (input validated against an allow-list)
app.MapGet("/api/claims", async (string status) =>
{
    var allowed = new[] { "Paid", "Denied", "Pending" };
    if (!allowed.Contains(status)) return Results.BadRequest("status must be Paid, Denied, or Pending");

    using var db = new SqlConnection(connStr);
    var rows = await db.QueryAsync<ClaimSummary>(
        "SELECT ClaimId, ServiceDate, ClaimStatus FROM Claims WHERE ClaimStatus = @status",
        new { status });
    await Audit("READ", "ClaimList", status);
    return Results.Ok(rows);
});

// GET ICD-10 code lookup (format validated)
app.MapGet("/api/codes/icd10/{code}", async (string code) =>
{
    if (!Regex.IsMatch(code, @"^[A-Z][0-9]{2}(\.[0-9A-Z]{1,4})?$"))
        return Results.BadRequest("Invalid ICD-10 format");

    using var db = new SqlConnection(connStr);
    var row = await db.QuerySingleOrDefaultAsync<CodeInfo>(
        "SELECT Code, Description FROM Icd10Codes WHERE Code = @code", new { code });
    return row is null ? Results.NotFound() : Results.Ok(row);
});

app.Run();

record Benefit(string ServiceCategory, decimal Copay, decimal Coinsurance, bool PriorAuthRequired);
record ClaimHeader(int ClaimId, string MemberNumber, DateTime ServiceDate, string ClaimStatus);
record ClaimLineDto(string CptCode, string Icd10Code, decimal BilledAmount, decimal AllowedAmount, string LineStatus, string? DenialReason);
record ClaimSummary(int ClaimId, DateTime ServiceDate, string ClaimStatus);
record CodeInfo(string Code, string Description);
