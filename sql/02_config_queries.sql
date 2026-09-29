-- 1. Benefits in effect on a given date
DECLARE @AsOf DATE = '2026-08-01';
SELECT p.PlanName, b.ServiceCategory, b.Copay, b.Coinsurance, b.PriorAuthRequired
FROM BenefitConfig b
JOIN Plans p ON p.PlanId = b.PlanId
WHERE b.EffectiveDate <= @AsOf
  AND (b.TermDate IS NULL OR b.TermDate >= @AsOf)
ORDER BY p.PlanName, b.ServiceCategory;

-- 2. CHECK: overlapping benefit rows (expect 0 rows)
SELECT a.PlanId, a.ServiceCategory, a.BenefitId AS RowA, b.BenefitId AS RowB
FROM BenefitConfig a
JOIN BenefitConfig b
  ON a.PlanId = b.PlanId
 AND a.ServiceCategory = b.ServiceCategory
 AND a.BenefitId < b.BenefitId
 AND a.EffectiveDate <= ISNULL(b.TermDate, '9999-12-31')
 AND b.EffectiveDate <= ISNULL(a.TermDate, '9999-12-31');

-- 3. CHECK: plans missing a service category (expect 0 rows)
SELECT p.PlanName, c.ServiceCategory
FROM Plans p
CROSS JOIN (SELECT DISTINCT ServiceCategory FROM CptCodes) c
LEFT JOIN BenefitConfig b
  ON b.PlanId = p.PlanId AND b.ServiceCategory = c.ServiceCategory
WHERE b.BenefitId IS NULL;

-- 4. CHECK: claim lines with no matching benefit on the service date (expect 0 rows)
SELECT cl.ClaimId, cl.CptCode
FROM ClaimLines cl
JOIN Claims c   ON c.ClaimId = cl.ClaimId
JOIN Members m  ON m.MemberId = c.MemberId
JOIN CptCodes cp ON cp.Code = cl.CptCode
LEFT JOIN BenefitConfig b
  ON b.PlanId = m.PlanId
 AND b.ServiceCategory = cp.ServiceCategory
 AND b.EffectiveDate <= c.ServiceDate
 AND (b.TermDate IS NULL OR b.TermDate >= c.ServiceDate)
WHERE b.BenefitId IS NULL;

-- 5. CHECK: claims with a service date outside member eligibility (expect 0 rows)
SELECT c.ClaimId, m.MemberNumber, c.ServiceDate, m.EffectiveDate, m.TermDate
FROM Claims c
JOIN Members m ON m.MemberId = c.MemberId
WHERE c.ServiceDate < m.EffectiveDate
   OR (m.TermDate IS NOT NULL AND c.ServiceDate > m.TermDate);

-- 6. Denied claim lines and reasons
SELECT ClaimId, CptCode, Icd10Code, DenialReason
FROM ClaimLines
WHERE LineStatus = 'Denied';

-- 7. Current copay comparison across plans by service category
SELECT b.ServiceCategory,
       MAX(CASE WHEN p.PlanType = 'HMO'  THEN b.Copay END) AS HMO_Copay,
       MAX(CASE WHEN p.PlanType = 'PPO'  THEN b.Copay END) AS PPO_Copay,
       MAX(CASE WHEN p.PlanType = 'HDHP' THEN b.Copay END) AS HDHP_Copay
FROM BenefitConfig b
JOIN Plans p ON p.PlanId = b.PlanId
WHERE b.TermDate IS NULL
GROUP BY b.ServiceCategory;
