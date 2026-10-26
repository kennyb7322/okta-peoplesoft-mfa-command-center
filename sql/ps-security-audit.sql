-- ============================================================================
-- PeopleSoft security audit queries for an Okta MFA rollout
-- Kenneth P. Barnes · UCS Solutions
--
-- READ-ONLY. SELECT statements only; nothing here changes data.
-- Oracle Database syntax (SYSDATE, DUAL). Adjust date functions for SQL Server or Db2.
-- Replace the example permission lists and role names with the ones in your environment.
-- ============================================================================

-- 1. Users holding privileged permission lists  → Okta group PS-Privileged
--    Review every six months.
WITH PRIV AS (
  SELECT 'ALLPAGES' AS CLASSID FROM DUAL          -- example: replace with your list
  UNION ALL SELECT '<SECURITY_ADMIN_PERMLIST>' FROM DUAL
  UNION ALL SELECT '<PEOPLETOOLS_ADMIN_PERMLIST>' FROM DUAL
)
SELECT DISTINCT RU.ROLEUSER AS OPRID, O.OPRDEFNDESC, RC.ROLENAME, RC.CLASSID,
       O.ACCTLOCK, O.LASTSIGNONDTTM
  FROM PSROLEUSER RU
  JOIN PSROLECLASS RC ON RC.ROLENAME = RU.ROLENAME
  JOIN PSOPRDEFN  O  ON O.OPRID     = RU.ROLEUSER
  JOIN PRIV       P  ON P.CLASSID   = RC.CLASSID
 ORDER BY RC.CLASSID, RU.ROLEUSER;

-- 2. Active accounts with no sign-on in 90 days (dormant) — candidates to lock before a wave
SELECT OPRID, OPRDEFNDESC, LASTSIGNONDTTM
  FROM PSOPRDEFN
 WHERE ACCTLOCK = 0
   AND (LASTSIGNONDTTM IS NULL OR LASTSIGNONDTTM < SYSDATE - 90)
 ORDER BY LASTSIGNONDTTM NULLS FIRST;

-- 3. Likely shared, generic, or training accounts — cannot carry MFA; replace with named accounts
SELECT OPRID, OPRDEFNDESC, ACCTLOCK, LASTSIGNONDTTM
  FROM PSOPRDEFN
 WHERE UPPER(OPRID) LIKE 'TEST%'
    OR UPPER(OPRID) LIKE 'TRAIN%'
    OR UPPER(OPRID) LIKE 'GENERIC%'
    OR UPPER(OPRDEFNDESC) LIKE '%SHARED%'
 ORDER BY OPRID;

-- 4. OPRID ↔ Okta mapping gaps
--    Load an Okta user export (login, psOprid) into a staging table first:
--    CREATE TABLE OKTA_USERS_STG (OKTA_LOGIN VARCHAR2(254), PS_OPRID VARCHAR2(30));
-- 4a. PeopleSoft accounts with no Okta user (will be unable to sign in after enforcement)
SELECT O.OPRID, O.OPRDEFNDESC, O.LASTSIGNONDTTM
  FROM PSOPRDEFN O
 WHERE O.ACCTLOCK = 0
   AND NOT EXISTS (SELECT 1 FROM OKTA_USERS_STG S WHERE UPPER(S.PS_OPRID) = UPPER(O.OPRID));
-- 4b. Okta users pointing to an OPRID that does not exist
SELECT S.OKTA_LOGIN, S.PS_OPRID
  FROM OKTA_USERS_STG S
 WHERE NOT EXISTS (SELECT 1 FROM PSOPRDEFN O WHERE UPPER(O.OPRID) = UPPER(S.PS_OPRID));

-- 5. Sign-on activity from the PeopleSoft access log (for bypass detection and pilot baselines)
SELECT OPRID, LOGIPADDRESS, LOGINDTTM, LOGOUTDTTM
  FROM PSACCESSLOG
 WHERE LOGINDTTM >= SYSDATE - 1
 ORDER BY LOGINDTTM DESC;

-- 6. Segregation-of-duties check: same user holds entry and payment-release roles
--    Replace the role names with your voucher-entry and payment-release roles.
SELECT A.ROLEUSER AS OPRID, A.ROLENAME AS ENTRY_ROLE, B.ROLENAME AS RELEASE_ROLE
  FROM PSROLEUSER A
  JOIN PSROLEUSER B ON B.ROLEUSER = A.ROLEUSER
 WHERE A.ROLENAME = '<VOUCHER_ENTRY_ROLE>'
   AND B.ROLENAME = '<PAYMENT_RELEASE_ROLE>';

-- 7. Users per role, to size Okta groups and enforcement waves
SELECT RU.ROLENAME, COUNT(DISTINCT RU.ROLEUSER) AS USERS
  FROM PSROLEUSER RU
  JOIN PSOPRDEFN O ON O.OPRID = RU.ROLEUSER AND O.ACCTLOCK = 0
 GROUP BY RU.ROLENAME
 ORDER BY USERS DESC;
