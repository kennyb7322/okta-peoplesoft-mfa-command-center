# Microsoft Entra ID coexistence with Okta for PeopleSoft MFA

**Author:** Kenneth P. Barnes · Reference guidance · Confirm settings against current Microsoft and Okta documentation before use.

Most state agencies run Microsoft 365 on Entra ID. The design has to decide which system performs MFA for which application, so users see one prompt and auditors see one owner.

## Models

| Model | How it works | Fits when | Watch for |
|---|---|---|---|
| 1 · Entra ID as user source | Okta imports users and groups from Entra ID (or AD through the Okta agent) and is the IdP and MFA authority for PeopleSoft. Microsoft 365 is unchanged. | Okta is new and PeopleSoft MFA cannot wait for a wider identity decision | Users may carry two authenticator apps |
| 2 · Okta federated for Microsoft 365 | The domain is federated through Okta's WS-Federation Office 365 app. With "Okta MFA from Microsoft Entra ID" enabled and `federatedIdpMfaBehavior` set to `enforceMfaByFederatedIdp`, Entra ID accepts Okta MFA. | Okta already federates the domain or is chosen as the primary workforce IdP | Okta must perform MFA for the Office 365 app, or users hit a sign-in loop |
| 3 · Entra ID upstream of Okta | Okta routes users to Entra ID for primary sign-in, then applies its PeopleSoft authentication policy (with an extra Okta factor for privileged roles if required). | Entra ID is the declared primary IdP but the engagement must deliver Okta MFA for PeopleSoft | Audit evidence must show which system performed each factor |
| 4 · Entra ID + F5 BIG-IP APM (reference) | BIG-IP APM is the SAML service provider in front of PeopleSoft, Entra ID the IdP; BIG-IP injects `PS_SSO_UID` and the delivered `OAMSSO_AUTHENTICATION` sign-on PeopleCode trusts it (Microsoft-documented). | The organization standardizes on Entra ID instead of Okta, or needs an interim path | Same header-trust and bypass controls as Okta Access Gateway |

## Entra ID controls in the design

- **Conditional Access and authentication strengths** — phishing-resistant MFA for administrators; block legacy authentication.
- **Privileged Identity Management** — just-in-time roles for the people who manage the Okta federation, Microsoft 365, and Azure-hosted infrastructure.
- **Access reviews** — recertify the groups that drive PeopleSoft populations (PS-Privileged, PS-Approvers, PS-Emergency).
- **Sign-in and audit logs to the SIEM** — correlate Entra, Okta, and PeopleSoft (`PSACCESSLOG`) events by user and time.

## Decision questions

1. Does Okta already federate the Microsoft 365 domain? If yes → model 2.
2. Is Entra ID the declared primary workforce identity provider? If yes → model 3.
3. Otherwise → model 1 for this engagement, with a roadmap to model 2 or 3.
