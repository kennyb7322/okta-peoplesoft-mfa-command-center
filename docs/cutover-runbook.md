# Wave cutover and rollback runbook — Okta MFA for PeopleSoft Financials

**Author:** Kenneth P. Barnes · Illustrative values · Use one copy of this runbook per wave.

## Wave plan (illustrative planning counts)

| Wave | Population | Users | Window |
|---|---|---|---|
| Pilot | IT, security, PeopleSoft support | 250 | M13–M15 |
| Wave 1 | Central finance and accounting | 1,800 | M15–M16 |
| Wave 2 | Agency group A (largest) | 3,200 | M16–M18 |
| Wave 3 | Agency group B | 3,900 | M18–M19 |
| Wave 4 | Agency group C | 4,100 | M19–M21 |
| Wave 5 | Remaining users; approver step-up | 2,750 | M21–M22 |

Enforcement dates avoid month-end close and state fiscal year-end close (March 31 for New York State).

## Timeline

| When | Activity | Gate |
|---|---|---|
| T-14 days | Communications to wave users; enrollment opens (MFA optional for the wave group) | Comms sent; service desk scripts published |
| T-7 days | Regression subset run; rollback rehearsed in non-production; enrollment rate reviewed | Enrollment ≥ 85%; no open critical or high defects |
| T-1 day | Go / no-go board: test results, enrollment, service desk staffing, change calendar | Board approves |
| T-0 06:00 | Move the wave group to the enforced Okta rule; verify sign-on, deep links, interfaces | Smoke tests TC-01 to TC-08 pass within 30 minutes |
| T-0 09:00–17:00 | Hypercare bridge; watch sign-in success, MFA failures, lockouts, service desk queue | Sign-in success ≥ 97% over a rolling 30 minutes |
| T+1 to T+5 | Daily review; tune policies; close issues; report to sponsor | Stabilization metrics within thresholds |

## Interface check after enforcement

- Integration Broker inbound and outbound queues processing (TC-45, TC-46)
- Process Scheduler jobs running under scheduled user IDs (TC-47)
- Bank and payment interfaces on schedule (TC-49)
- Workflow email deep links landing on the worklist through Okta (TC-50)

## Rollback decision

1. **Okta or the gateway unavailable?** Use emergency access for critical finance work now. If the outage passes 15 minutes, roll back the wave.
2. **Sign-in success below 97% for 30 minutes, or a critical finance process blocked?** If no, continue.
3. **Cause isolated to a configuration fix that can be made and re-tested within 60 minutes?** If yes, hold the next wave and fix forward under emergency change. If no, roll back.

### Rollback steps by pattern

| Pattern | Rollback |
|---|---|
| A · Native SAML | Disable SAML on the web profile; restore the previous sign-on page; restart web servers in sequence |
| B · Okta Access Gateway | Switch the load-balancer pool back to the pre-MFA path; disable the header-trust branch of sign-on PeopleCode |
| C · Web-tier agent | Revert the agent policy to the previous authentication scheme |
| All | Move the wave group back to the pre-enforcement Okta rule; confirm sign-on; notify users and the service desk; log the incident |
