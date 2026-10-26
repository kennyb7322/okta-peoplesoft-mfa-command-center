# Oracle OCI and multi-cloud controls for a PeopleSoft MFA program

**Author:** Kenneth P. Barnes · Reference guidance · Confirm service availability for your region and agency.

PeopleSoft may run on premises, on OCI, or on AWS or Azure, and the clouds around it hold logs, keys, and integrations. Every console that can change the PeopleSoft environment must meet the same MFA standard as PeopleSoft administrators.

## Control map

| Control | Oracle OCI | AWS | Azure | Google Cloud |
|---|---|---|---|---|
| Admin federation & MFA | OCI IAM identity domain ← Okta / Entra (SAML) | IAM Identity Center ← Okta / Entra | Entra ID + Conditional Access, PIM | Cloud Identity / Workforce Identity Federation |
| Private admin access | OCI Bastion | Systems Manager Session Manager | Azure Bastion | Identity-Aware Proxy |
| Keys & secrets | OCI Vault | KMS · CloudHSM · Secrets Manager | Key Vault · Managed HSM | Cloud KMS · Secret Manager |
| Web tier protection | OCI WAF · Load Balancer | AWS WAF · ALB | Application Gateway WAF · Front Door | Cloud Armor · Load Balancing |
| Posture & guardrails | Cloud Guard · Security Zones | Security Hub · Config · SCPs | Defender for Cloud · Azure Policy | Security Command Center · Org Policy |
| Audit logs to SIEM | Audit · Logging · Service Connector Hub | CloudTrail · CloudWatch | Activity log · Entra logs → Log Analytics | Cloud Audit Logs · Log Router |
| Oracle database | Base Database / Exadata · Data Safe | Oracle Database@AWS · Oracle on EC2 | Oracle Database@Azure | Oracle Database@Google Cloud |
| PeopleSoft hosting fit | Oracle's target: Cloud Manager, new PeopleTools first | IaaS on EC2 | IaaS on VMs; BIG-IP VE or Okta Access Gateway in Azure | Uncommon for PeopleSoft; data and integration |

## OCI specifics

- **PeopleSoft Cloud Manager** provisions, clones, patches, and upgrades PeopleSoft on OCI. PeopleTools 8.63 reached general availability on OCI in July 2026 (upgrade through Cloud Manager Image 22), ahead of on-premises.
- **OCI IAM identity domains** control console and Cloud Manager access and can federate to Okta or Entra ID over SAML 2.0. Oracle also documents OCI IAM, with its App Gateway and the delivered `OAMSSO_AUTHENTICATION` sign-on PeopleCode, as a PeopleSoft SSO and MFA option.
- **Security services:** Security Zones block non-compliant resources at creation; Cloud Guard detects drift; Data Safe assesses database users and activity; Service Connector Hub forwards logs to the SIEM.

## Rule of thumb

Keep Okta as the PeopleSoft identity provider, federate every cloud console to the same identity provider under the privileged-administrator rule, and map each cloud's findings to the same NIST SP 800-53 Rev 5 controls so one report covers all of them.
