
-- ===== SCHEMA =====
CREATE TABLE Plans (
    PlanId    INT PRIMARY KEY,
    PlanName  VARCHAR(100) NOT NULL,
    PlanType  VARCHAR(10)  NOT NULL CHECK (PlanType IN ('HMO','PPO','HDHP'))
);

CREATE TABLE Members (
    MemberId      INT PRIMARY KEY,
    MemberNumber  VARCHAR(12) NOT NULL UNIQUE,
    FirstName     VARCHAR(50) NOT NULL,
    LastName      VARCHAR(50) NOT NULL,
    DateOfBirth   DATE NOT NULL,
    PlanId        INT NOT NULL REFERENCES Plans(PlanId),
    EffectiveDate DATE NOT NULL,
    TermDate      DATE NULL
);

CREATE TABLE Providers (
    ProviderId   INT PRIMARY KEY,
    ProviderName VARCHAR(100) NOT NULL,
    NPI          CHAR(10) NOT NULL UNIQUE,
    Specialty    VARCHAR(50) NOT NULL,
    InNetwork    BIT NOT NULL
);

CREATE TABLE Icd10Codes (
    Code        VARCHAR(8) PRIMARY KEY,
    Description VARCHAR(200) NOT NULL
);

CREATE TABLE CptCodes (
    Code            CHAR(5) PRIMARY KEY,
    Description     VARCHAR(200) NOT NULL,
    ServiceCategory VARCHAR(30) NOT NULL
);

CREATE TABLE BenefitConfig (
    BenefitId         INT IDENTITY PRIMARY KEY,
    PlanId            INT NOT NULL REFERENCES Plans(PlanId),
    ServiceCategory   VARCHAR(30) NOT NULL,
    Copay             DECIMAL(8,2) NOT NULL DEFAULT 0,
    Coinsurance       DECIMAL(5,2) NOT NULL DEFAULT 0,
    PriorAuthRequired BIT NOT NULL DEFAULT 0,
    EffectiveDate     DATE NOT NULL,
    TermDate          DATE NULL
);

CREATE TABLE Claims (
    ClaimId     INT PRIMARY KEY,
    MemberId    INT NOT NULL REFERENCES Members(MemberId),
    ProviderId  INT NOT NULL REFERENCES Providers(ProviderId),
    ServiceDate DATE NOT NULL,
    ClaimStatus VARCHAR(10) NOT NULL CHECK (ClaimStatus IN ('Paid','Denied','Pending'))
);

CREATE TABLE ClaimLines (
    ClaimLineId   INT IDENTITY PRIMARY KEY,
    ClaimId       INT NOT NULL REFERENCES Claims(ClaimId),
    CptCode       CHAR(5) NOT NULL REFERENCES CptCodes(Code),
    Icd10Code     VARCHAR(8) NOT NULL REFERENCES Icd10Codes(Code),
    BilledAmount  DECIMAL(10,2) NOT NULL,
    AllowedAmount DECIMAL(10,2) NOT NULL,
    LineStatus    VARCHAR(10) NOT NULL,
    DenialReason  VARCHAR(100) NULL
);

CREATE TABLE AuditLog (
    AuditId    INT IDENTITY PRIMARY KEY,
    UserName   VARCHAR(100) NOT NULL,
    Action     VARCHAR(50)  NOT NULL,
    Entity     VARCHAR(50)  NOT NULL,
    EntityId   VARCHAR(50)  NOT NULL,
    AccessedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);

-- ===== SEED DATA (all fictional) =====
INSERT INTO Plans VALUES
(1,'Acme Select HMO','HMO'),
(2,'Acme Choice PPO','PPO'),
(3,'Acme Saver HDHP','HDHP');

INSERT INTO Members VALUES
(1,'M100000001','Ava','Turner','1985-04-12',1,'2026-01-01',NULL),
(2,'M100000002','Ben','Ortiz','1978-09-30',2,'2026-01-01',NULL),
(3,'M100000003','Cara','Nguyen','1992-02-17',3,'2026-01-01',NULL),
(4,'M100000004','Dan','Brooks','1969-11-05',2,'2026-01-01',NULL),
(5,'M100000005','Eve','Patel','1990-07-22',1,'2026-01-01','2026-04-30');

INSERT INTO Providers VALUES
(1,'Lakeside Family Clinic','1234567890','Family Medicine',1),
(2,'Metro Heart Center','2345678901','Cardiology',1),
(3,'City General ER','3456789012','Emergency',1);

INSERT INTO Icd10Codes VALUES
('E11.9','Type 2 diabetes mellitus without complications'),
('I10','Essential (primary) hypertension'),
('R07.9','Chest pain, unspecified'),
('J06.9','Acute upper respiratory infection, unspecified'),
('Z00.00','General adult medical exam without abnormal findings');

INSERT INTO CptCodes VALUES
('99213','Office visit, established patient, low complexity','Primary Care'),
('99214','Office visit, established patient, moderate complexity','Primary Care'),
('93000','Electrocardiogram, complete','Diagnostics'),
('80053','Comprehensive metabolic panel','Lab'),
('99283','Emergency department visit, moderate severity','Emergency'),
('99395','Preventive visit, established patient, 18-39','Preventive');

-- Every plan has every service category. PPO Primary Care copay changes on
-- 2026-07-01 using non-overlapping effective dates. HMO Diagnostics requires prior auth.
INSERT INTO BenefitConfig (PlanId,ServiceCategory,Copay,Coinsurance,PriorAuthRequired,EffectiveDate,TermDate) VALUES
(1,'Primary Care',20,0,0,'2026-01-01',NULL),
(1,'Diagnostics',0,20,1,'2026-01-01',NULL),
(1,'Lab',0,0,0,'2026-01-01',NULL),
(1,'Emergency',250,0,0,'2026-01-01',NULL),
(1,'Preventive',0,0,0,'2026-01-01',NULL),
(2,'Primary Care',30,0,0,'2026-01-01','2026-06-30'),
(2,'Primary Care',35,0,0,'2026-07-01',NULL),
(2,'Diagnostics',0,20,0,'2026-01-01',NULL),
(2,'Lab',0,20,0,'2026-01-01',NULL),
(2,'Emergency',300,0,0,'2026-01-01',NULL),
(2,'Preventive',0,0,0,'2026-01-01',NULL),
(3,'Primary Care',0,20,0,'2026-01-01',NULL),
(3,'Diagnostics',0,20,0,'2026-01-01',NULL),
(3,'Lab',0,20,0,'2026-01-01',NULL),
(3,'Emergency',0,20,0,'2026-01-01',NULL),
(3,'Preventive',0,0,0,'2026-01-01',NULL);

INSERT INTO Claims VALUES
(1,1,1,'2026-03-10','Paid'),
(2,2,2,'2026-04-02','Paid'),
(3,3,3,'2026-05-15','Paid'),
(4,1,1,'2026-06-01','Paid'),
(5,4,1,'2026-08-20','Paid'),
(6,5,1,'2026-04-15','Paid'),
(7,1,2,'2026-07-08','Denied');

INSERT INTO ClaimLines (ClaimId,CptCode,Icd10Code,BilledAmount,AllowedAmount,LineStatus,DenialReason) VALUES
(1,'99213','E11.9',150,120,'Paid',NULL),
(2,'93000','I10',80,60,'Paid',NULL),
(3,'99283','R07.9',1200,900,'Paid',NULL),
(4,'80053','E11.9',90,50,'Paid',NULL),
(5,'99213','I10',150,120,'Paid',NULL),
(6,'99395','Z00.00',200,160,'Paid',NULL),
(7,'93000','I10',80,0,'Denied','PRIOR AUTH NOT ON FILE');
