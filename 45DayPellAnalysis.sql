/*
Title: 45DayPellAnalysis
Author: Todd N./Agata K.
Description/Requirements:
    Identify pell disbursements that adhere to the pell disbursment policy
    of posting to the ledger within 45 days from date of determination(DOD).
    a.	If Pell paid prior to 45 days from DOD = PASS
    b.	If Pell paid after 45 days from the DOD = CRITICAL FAIL
    c.	If Pell is still in scheduled status prior to 45 days from DOD = PASS
    d.	If Pell is still in scheduled status after the 45 days from DOD = FAIL

Changes/Updates:
2019/01/07: Initial Code Completion.

*/

USE [RPTObjects];
GO
SET STATISTICS IO ON;
GO

/*school status with only 
permanent out and temporary out category*/
IF OBJECT_ID('tempdb..#SchoolStatKey') IS NOT NULL
    DROP TABLE #SchoolStatKey;
SELECT ss.syschoolstatusid,
       ss.descrip AS schoolStatus,
       sc.descrip AS category,
       sc.code
INTO #SchoolStatKey
FROM c2000.dbo.syschoolstatus AS ss(NOLOCK)
     INNER JOIN c2000.dbo.systatus AS s(NOLOCK) ON ss.systatusid = s.systatusid
     INNER JOIN c2000.dbo.systatuscategory AS sc(NOLOCK) ON sc.code = s.category
                                                            AND ss.active = 1
WHERE sc.descrip IN('Temporary Out', 'Permanent Out');

/*enrollment population limited by school category 
and drop 180 days before 2018-08-30 */
IF OBJECT_ID('tempdb.dbo.#enrollment') IS NOT NULL
    DROP TABLE #enrollment;
SELECT TOP 1 WITH TIES ae.SyStudentID,
                       ae.adenrollid,
                       ae.[adProgramDescrip] AS ProgramDescrip,
                       ae.DropDate,
                       ssk.SchoolStatus,
				   ae.LDA
INTO #enrollment
FROM C2000.dbo.adenroll ae(nolock)
     JOIN #SchoolStatKey ssk ON ssk.SySchoolStatusID = ae.SySchoolStatusID
WHERE ae.SyCampusID IN
(
    SELECT [SyCampusID]
    FROM [C2000].[dbo].[SyCampusList](nolock)
    WHERE SyCampusGrpID = 1570771
)
     AND ae.DropDate >= DATEADD(day, -180, '20180830')
ORDER BY ROW_NUMBER() OVER(PARTITION BY ae.SyStudentID ORDER BY ae.ExpStartDate DESC);

/*pell paid after drop date
or scheduled status with amount greater than 0
-apply pass/fail logic here relative to dropdate(see requirements)
*/
IF OBJECT_ID('tempdb.dbo.#45dayresults') IS NOT NULL
    DROP TABLE #45dayresults;
WITH disb_CTE
     AS (
     SELECT e.systudentid,
            e.ProgramDescrip,
		  e.LDA,
		  e.SchoolStatus,
            ffs.code AS FundName,
            fsa.awardyear,
            atm.code AS TermCode,
            fs.DisbNum,
            fs.Status,
            fs.GrossAmount,
            e.dropdate,
            fs.Datesched,
            s.PostDate
     FROM C2000.dbo.FaStudentAid fsa(nolock)
          JOIN #enrollment e ON e.adenrollid = fsa.adenrollid
          JOIN C2000.dbo.FaFundSource ffs(nolock) ON ffs.FaFundSourceID = fsa.FaFundSourceID
                                                     AND ffs.FaFundSourceID = 1
                                                     AND fsa.awardyear >= '2017-18'
          JOIN C2000.dbo.FaSched fs(nolock) ON fsa.FaStudentAidID = fs.FaStudentAidID
                                               AND fs.status <> 'c'
                                               AND fs.GrossAmount > 0
          JOIN C2000.dbo.adterm atm(nolock) ON atm.adtermid = fs.adtermid
          LEFT JOIN C2000.dbo.FaDisb fd(nolock) ON fd.FaSchedID = fs.FaSchedID
          LEFT JOIN C2000.dbo.SaTrans s(nolock) ON s.FaDisbID = fd.FaDisbID
     WHERE(s.PostDate >= e.dropdate
           OR fd.FaDisbID IS NULL)
     )
     SELECT d.*,
            CASE
                WHEN status <> 'p'
			 THEN 'NA'
                WHEN PostDate > DATEADD(day, 45, dropdate)
                THEN 'CRITICAL_FAIL'
                ELSE 'Pass'
            END AS PaidDisbCheck,
            CASE
                WHEN status = 'p'
			 THEN 'NA'
                WHEN GETDATE() > DATEADD(day, 45, dropdate)
                THEN 'Fail'
                ELSE 'Pass'
            END AS SchedCheck
    		  INTO #45dayresults
     FROM disb_CTE d;

--Documents analysis: verif and ccode checklist status
IF OBJECT_ID('tempdb.dbo.#documents') IS NOT NULL
    DROP TABLE #documents;
SELECT TOP 1 WITH TIES cdt.SyStudentID,
                       cdt.CmDocumentID,
                       cds.[Descrip] AS DocStatus,
                       cdt.AwardYear,
                       RIGHT(cdt.AwardYear, 2) AS Yr,
                       CASE
                           WHEN frd.[CCode] = 1
                           THEN 'C-CodeChecklist'
                           WHEN frd.[KHE] = 1
                           THEN 'VerifForm'
                       END AS DocGroup,
                       CASE
                           WHEN cdt.[cmDocStatusID] IN(2, 18, 33, 59)
                           THEN 'Complete'
                           WHEN cdt.[cmDocStatusID] = 41
                           THEN 'NotConfirmed'
                           WHEN cdt.[cmDocStatusID] = 3
                           THEN 'NA'
                           ELSE 'Incomplete'
                       END AS DStatus
INTO #documents
FROM [ORION].[dbo].[diDocumentsScheduled] ds(NOLOCK)
     INNER JOIN c2000.[dbo].CmDocument cdt(NOLOCK) ON cdt.CmDocumentID = ds.C2K_CmDocumentID
     INNER JOIN #45dayresults e ON e.[SyStudentId] = cdt.[SyStudentId]
     INNER JOIN C2000.dbo.[cmDocStatus] cds(NOLOCK) ON cdt.[cmDocStatusID] = cds.[cmDocStatusID]
     INNER JOIN [RPTObjects].[dbo].[FA_ReportingDocs] frd(nolock) ON cdt.[cmDocTypeID] = frd.[cmDocTypeID]
                                                                     AND frd.coversheet = 1
                                                                     AND frd.awardyear >= '2017-18'
WHERE cdt.AwardYear >= '2017-18'
ORDER BY ROW_NUMBER() OVER(PARTITION BY cdt.SyStudentID,
                                        cdt.AwardYear,
                                        cdt.[cmDocTypeID] ORDER BY CASE
                                                                       WHEN cdt.[cmDocStatusID] = 41
                                                                       THEN 2
                                                                       WHEN cdt.[cmDocStatusID] IN(2, 18, 33, 59)
                                                                       THEN 3
                                                                       WHEN cdt.[cmDocStatusID] = 3
                                                                       THEN 4
                                                                       ELSE 1
                                                                   END ASC);
--NotConfirm logic to document status
IF OBJECT_ID('tempdb.dbo.#documents2') IS NOT NULL
    DROP TABLE #documents2;
SELECT a.*,
       nxt.yr AS nxt_yr,
       nxt.dstatus AS nxt_dstatus,
       CASE
           WHEN a.DStatus = 'NotConfirmed'
                OR (a.DocGroup = 'C-CodeChecklist'
                    AND nxt.dstatus = 'NotConfirmed')
           THEN 'Incomplete'
           ELSE a.DStatus
       END AS DStatusAdj
INTO #documents2
FROM #documents a
     LEFT JOIN #documents nxt ON a.systudentid = nxt.systudentid
                                 AND a.DocGroup = nxt.DocGroup
                                 AND a.yr = (nxt.yr - 1);

--put verif and ccode into one row
IF OBJECT_ID('tempdb.dbo.#documents3') IS NOT NULL
    DROP TABLE #documents3;
SELECT SyStudentID,
       AwardYear,
       [VerifForm] AS VerifHOApproved,
       [C-CodeChecklist] AS CCodeHOApproved
INTO #documents3
FROM
(
    SELECT SyStudentID,
           AwardYear,
           DocGroup,
           DStatusAdj
    FROM #documents2
) d PIVOT(MAX(DStatusAdj) FOR DocGroup IN([C-CodeChecklist],
                                          [VerifForm])) piv;


--ISIR Student Level Data
IF OBJECT_ID('tempdb.dbo.#isir') IS NOT NULL
    DROP TABLE #isir;
SELECT TOP 1 WITH TIES i.[SyStudentId],
                       i.[AwardYear],
                       i.TransactionNumber,
                       i.SelectedForVerification AS SelectedVerif,
                       CASE
                           WHEN c.code IS NULL
                           THEN 'N'
                           ELSE 'Y'
                       END AS hasCcode
INTO #isir
FROM [RPTObjects].[dbo].[tblFAISIR] i(nolock)
     LEFT JOIN [RPTObjects].[dbo].FAISIR_CCode c(nolock) ON i.faisirid = c.faisirid
                                                            AND c.isccode = 1
     JOIN #45dayresults e ON e.[SyStudentId] = i.[SyStudentId]
WHERE i.[Type] = 'c2000'
      AND i.[AwardYear] >= '2017-18'
ORDER BY ROW_NUMBER() OVER(PARTITION BY i.[SyStudentId],
                                        i.[AwardYear] ORDER BY i.TransactionNumber DESC,
                                                               c.isccode DESC);
--add coa
--code

--Final ouptut
SELECT s.SyStudentid,
       ss.StuNum,
       ss.LastName,
       ss.FirstName,
       c.code AS Campus,
       s.ProgramDescrip,
       CAST(s.LDA AS DATE) LDA,
	  s.SchoolStatus,
       s.FundName,
       s.AwardYear,
       s.TermCode,
       s.DisbNum,
       s.Status AS DisbStatus,
       s.GrossAmount,
       CAST(s.dropdate AS DATE) DOD,
	  CAST(DATEADD(day,45,s.dropdate) AS DATE) ComplianceDate,
       CAST(s.Datesched AS DATE) Datesched,
       CAST(s.PostDate AS DATE) PostDate,
       s.PaidDisbCheck,
       s.SchedCheck,
       i.SelectedVerif,
       d.VerifHOApproved,
       i.HasCcode,
       d.CCodeHOApproved
FROM #45dayresults s
     JOIN C2000.dbo.SyStudent ss(nolock) ON ss.systudentid = s.systudentid
     JOIN C2000.dbo.syCampus c(nolock) ON c.syCampusid = ss.syCampusid
     LEFT JOIN #documents3 d ON s.systudentid = d.systudentid
                                AND s.awardyear = d.awardyear
     LEFT JOIN #isir i ON s.systudentid = i.systudentid
                          AND s.awardyear = i.awardyear;

