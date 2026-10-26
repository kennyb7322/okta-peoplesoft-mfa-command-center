# Okta MFA for PeopleSoft Financials — Implementation Command Center

**Live dashboard:** https://kennyb7322.github.io/okta-peoplesoft-mfa-command-center/

A working example of how I would run a 30-month Okta multifactor authentication rollout for a multi-agency **PeopleSoft Financials 9.2** environment as an Enterprise Security Architect supporting an existing project team: current-state assessment, integration-pattern decision, Okta policy design, PeopleSoft security mapping, a 60-case test plan, wave cutover with tested rollback, logging and monitoring, stabilization, and knowledge transfer.

> Values are **illustrative**; no client data is used. PeopleSoft and Okta behavior follows vendor documentation as of October 2026 (including native SAML 2.0 and TOTP two-factor in PeopleTools 8.63, and the Okta Access Gateway reference architecture for PeopleSoft). Confirm releases and licensing for your environment before relying on them.

## What's inside the dashboard

| Section | What it demonstrates |
|---|---|
| Engagement & KPIs | Live counts from the test plan and assessment; the leading integration pattern; every tile opens a nine-part detail view |
| Sign-on architecture | Interactive flow for pattern A (native SAML 2.0), B (Okta Access Gateway), and C (web-tier agent), including the bypass path that must be closed |
| Pattern decision | Weighted scorer with a PeopleTools release switch (8.60–8.62 vs 8.63+) |
| Current-state assessment | 24 discovery questions with the reason each matters |
| Okta policy design | Six populations, ordered authentication-policy rules, authenticator choices |
| PeopleSoft security mapping | OPRID mapping, web profile, sign-on PeopleCode, roles and permission lists, Integration Broker, bypass paths |
| Access, exceptions & standards | Controls traced to NIST SP 800-63B, NIST SP 800-53 Rev 5, and New York State ITS identity, account-management, and logging standards |
| Test plan | 60 traceable cases you can mark Pass / Fail (kept in your browser) with a live chart |
| Waves, cutover & rollback | Pilot plus five waves, a runbook, and an interactive rollback decision |
| Logging & monitoring | Okta System Log events, PeopleSoft sign-on audit, and SIEM detections (MFA fatigue, Okta bypass, emergency-account use) |
| Roadmap, RAID, knowledge transfer | Eight phases over 30 months, risks with mitigations, dependencies, and hand-off deliverables |
| JD coverage map | Every responsibility, minimum, and preferred qualification mapped to a section |

## Code

| File | Purpose | Changes anything? |
|---|---|---|
| [`terraform/okta-mfa`](terraform/okta-mfa) | Okta groups, network zones, enrollment policy, PeopleSoft authentication-policy rules by population, and the pattern A SAML app (okta/okta provider 4.x) | `terraform apply` |
| [`sql/ps-security-audit.sql`](sql/ps-security-audit.sql) | Read-only PeopleTools security queries: privileged users, dormant and shared accounts, OPRID ↔ Okta gaps, sign-on activity, segregation of duties | No |
| [`scripts/okta_syslog_report.py`](scripts/okta_syslog_report.py) | Read-only Okta System Log summary: enrollment, MFA failure rate, lockouts, policy rule hits, MFA-fatigue detection; live API or offline JSON | No |
| [`tests/test-plan.csv`](tests/test-plan.csv) | The 60 test cases from the dashboard | — |
| [`tests/sample-syslog.json`](tests/sample-syslog.json) | Synthetic System Log events for an offline run of the report | — |
| [`docs/decision-record.md`](docs/decision-record.md) | Integration-pattern decision record with criteria, weights, and scores | — |
| [`docs/cutover-runbook.md`](docs/cutover-runbook.md) | Wave timeline, interface checks, rollback decision, rollback steps per pattern | — |

The Python script compiles and runs against the synthetic sample (`python3 scripts/okta_syslog_report.py --input tests/sample-syslog.json`). Run `terraform init && terraform validate && terraform plan` against a non-production Okta org before applying the Terraform anywhere.

## Run the dashboard

`index.html` is one self-contained file (Chart.js and Google Fonts from CDN; works offline after first load). Open it in a browser or serve the folder:

```bash
python3 -m http.server 8080
```

## Author

**Kenneth P. Barnes** — Enterprise Security Architect · Founder, CTO & CISO, Ultimate Computer Solutions, Inc. (UCS Solutions, est. 1993) · U.S. Citizen
Worked at PeopleSoft and directly for PeopleSoft customers (Financials, HR, Student) across higher education, government, state agencies, and manufacturing · Okta SSO, MFA, Lifecycle Management, and Workflows · CISSP · Okta Certified Professional
KBarnes@ucsolutions.com · [linkedin.com/in/drkennethpbarnes](https://www.linkedin.com/in/drkennethpbarnes) · [github.com/kennyb7322](https://github.com/kennyb7322)
