# Decision record — Okta MFA integration pattern for PeopleSoft Financials

**Status:** Template with illustrative scoring · **Author:** Kenneth P. Barnes · **Applies to:** PeopleSoft Financials 9.2

## Context

The organization will enforce Okta multifactor authentication for every interactive PeopleSoft Financials sign-in. PeopleSoft roles and permission lists continue to decide what a user can do; Okta decides who the user is and how strongly they proved it. Integration Broker, Process Scheduler, and other non-interactive paths must keep working without Okta prompts.

## Options

| | Pattern | How it works | Main dependency |
|---|---|---|---|
| A | Native SAML 2.0 | PeopleTools 8.63 acts as a SAML 2.0 service provider; Okta is the identity provider. 8.63 also adds TOTP two-factor and a 2FA API for transaction step-up. | PeopleTools 8.63 (generally available on OCI July 2026; on-premises later) |
| B | Okta Access Gateway | Reverse proxy in front of PeopleSoft 9.2; after Okta authentication and MFA it passes the user ID in a header that sign-on PeopleCode trusts only from the gateway. | Access Gateway license and hosting; web tier reachable only through the gateway |
| C | Web-tier agent / partner gateway | An existing access manager (for example Oracle Access Manager WebGate) federated to Okta enforces authentication at the web tier. | The existing component and its support |
| D | Transaction step-up (add-on) | Second prompt on payment release, supplier bank changes, and security administration. | PeopleTools 2FA API (8.63) or a partner tool |

## Criteria and illustrative scores (1–5)

| Criterion | Weight | A | B | C |
|---|---|---|---|---|
| Security assurance | 5 | 5 | 4 | 4 |
| No PeopleTools upgrade needed | 5 | 1 (5 if already on 8.63) | 5 | 4 |
| Implementation effort (higher = less) | 3 | 3 | 3 | 2 |
| Operational simplicity | 3 | 5 | 3 | 2 |
| User experience | 3 | 4 | 4 | 3 |
| Transaction step-up support | 2 | 5 | 3 | 2 |
| Bypass resistance | 4 | 4 | 3 | 3 |
| **Weighted total (PeopleTools 8.60–8.62)** | | **92** | **93** | **77** |
| **Weighted total (PeopleTools 8.63+)** | | **112** | **93** | **77** |

The command center recalculates these totals live as weights change.

## Decision rule

- If production is on PeopleTools 8.63, or an 8.63 upgrade lands before the pilot, choose **A**.
- Otherwise choose **B** now and keep Okta policies pattern-neutral so the later move to A changes nothing for users.
- Choose **C** only where the component already exists and is supported.
- Add **D** for payment release and supplier bank-account changes once base MFA is stable.

## Consequences

- Pattern B adds a component to patch and monitor and requires network controls so the PeopleSoft web tier accepts requests only from the gateway (test cases TC-53, TC-54).
- Pattern A depends on the upgrade schedule and changes the negative tests to assertion replay and signature validation (TC-55).
- Either way, service and integration accounts are excluded from interactive MFA but restricted by network, certificates, and scope.
