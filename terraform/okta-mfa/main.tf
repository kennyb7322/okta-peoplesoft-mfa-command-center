# Okta MFA for PeopleSoft Financials — reference policy configuration
# Kenneth P. Barnes · UCS Solutions
#
# Illustrative values only. Written for the okta/okta Terraform provider (4.x, Okta Identity Engine).
# Run `terraform init && terraform validate && terraform plan` against a non-production Okta org
# and review every rule before applying anywhere else.

terraform {
  required_version = ">= 1.5"
  required_providers {
    okta = {
      source  = "okta/okta"
      version = "~> 4.0"
    }
  }
}

provider "okta" {
  org_name = var.okta_org_name
  base_url = var.okta_base_url
  # Credentials come from OKTA_API_TOKEN or OAuth private-key settings in the environment.
}

# ---------------------------------------------------------------------------
# Groups — one per population. Membership is driven by directory / role rules.
# ---------------------------------------------------------------------------
resource "okta_group" "ps_users" {
  name        = "PS-Users"
  description = "PeopleSoft Financials general finance users"
}

resource "okta_group" "ps_approvers" {
  name        = "PS-Approvers"
  description = "Approvers and payment releasers (step-up on release)"
}

resource "okta_group" "ps_privileged" {
  name        = "PS-Privileged"
  description = "Security, PeopleTools, and system administrators"
}

resource "okta_group" "ps_service" {
  name        = "PS-Service"
  description = "Integration and batch accounts: no interactive sign-in"
}

resource "okta_group" "ps_emergency" {
  name        = "PS-Emergency"
  description = "Vaulted break-glass accounts; alert on use; disable after 24 hours"
}

# ---------------------------------------------------------------------------
# Network zones
# ---------------------------------------------------------------------------
resource "okta_network_zone" "trusted" {
  name     = "Trusted networks"
  type     = "IP"
  gateways = var.trusted_cidrs
  usage    = "POLICY"
}

resource "okta_network_zone" "admin" {
  name     = "Admin network"
  type     = "IP"
  gateways = var.admin_cidrs
  usage    = "POLICY"
}

# ---------------------------------------------------------------------------
# Authenticator enrollment policy — Okta Verify required, WebAuthn optional,
# phone limited to recovery (not offered for enrollment as a primary factor).
# ---------------------------------------------------------------------------
resource "okta_policy_mfa" "peoplesoft_enrollment" {
  name            = "PS - Authenticator enrollment"
  status          = "ACTIVE"
  description     = "Enrollment policy for PeopleSoft populations"
  is_oie          = true
  priority        = 1
  groups_included = [okta_group.ps_users.id, okta_group.ps_approvers.id, okta_group.ps_privileged.id]

  okta_verify  = { enroll = "REQUIRED" }
  webauthn     = { enroll = "OPTIONAL" }
  okta_email   = { enroll = "NOT_ALLOWED" }
  phone_number = { enroll = "NOT_ALLOWED" }
}

resource "okta_policy_rule_mfa" "peoplesoft_enrollment_rule" {
  policy_id = okta_policy_mfa.peoplesoft_enrollment.id
  name      = "Enroll at first sign-in"
  status    = "ACTIVE"
  enroll    = "LOGIN"
}

# ---------------------------------------------------------------------------
# Application authentication policy for PeopleSoft. Rules evaluate by priority;
# the first match wins. Mirrors the command center's policy table.
# ---------------------------------------------------------------------------
resource "okta_app_signon_policy" "peoplesoft" {
  name        = "PeopleSoft Financials - authentication policy"
  description = "MFA rules by population for PeopleSoft Financials"
}

resource "okta_app_signon_policy_rule" "ps_emergency" {
  policy_id       = okta_app_signon_policy.peoplesoft.id
  name            = "PS - Emergency accounts"
  priority        = 1
  access          = "ALLOW"
  groups_included = [okta_group.ps_emergency.id]
  factor_mode     = "2FA"
  re_authentication_frequency = "PT0S"
}

resource "okta_app_signon_policy_rule" "ps_privileged" {
  policy_id                   = okta_app_signon_policy.peoplesoft.id
  name                        = "PS - Security and PeopleTools admins"
  priority                    = 2
  access                      = "ALLOW"
  groups_included             = [okta_group.ps_privileged.id]
  network_connection          = "ZONE"
  network_includes            = [okta_network_zone.admin.id]
  device_is_registered        = true
  device_is_managed           = true
  factor_mode                 = "2FA"
  re_authentication_frequency = "PT0S" # prompt at every sign-in
  constraints = [jsonencode({
    possession = {
      required          = true
      phishingResistant = "REQUIRED"
      userPresence      = "REQUIRED"
    }
  })]
}

resource "okta_app_signon_policy_rule" "ps_approvers" {
  policy_id                   = okta_app_signon_policy.peoplesoft.id
  name                        = "PS - Approvers and payment release"
  priority                    = 3
  access                      = "ALLOW"
  groups_included             = [okta_group.ps_approvers.id]
  factor_mode                 = "2FA"
  re_authentication_frequency = "PT8H"
  constraints = [jsonencode({
    possession = { required = true, userPresence = "REQUIRED" }
  })]
}

resource "okta_app_signon_policy_rule" "ps_off_network" {
  policy_id                   = okta_app_signon_policy.peoplesoft.id
  name                        = "PS - Off-network users"
  priority                    = 4
  access                      = "ALLOW"
  groups_included             = [okta_group.ps_users.id]
  network_connection          = "ZONE"
  network_excludes            = [okta_network_zone.trusted.id]
  factor_mode                 = "2FA"
  re_authentication_frequency = "PT8H"
}

resource "okta_app_signon_policy_rule" "ps_users" {
  policy_id                   = okta_app_signon_policy.peoplesoft.id
  name                        = "PS - General finance users"
  priority                    = 5
  access                      = "ALLOW"
  groups_included             = [okta_group.ps_users.id]
  factor_mode                 = "2FA"
  re_authentication_frequency = "PT12H"
}

resource "okta_app_signon_policy_rule" "ps_service_deny" {
  policy_id       = okta_app_signon_policy.peoplesoft.id
  name            = "PS - Service accounts (deny interactive)"
  priority        = 6
  access          = "DENY"
  groups_included = [okta_group.ps_service.id]
}

# The policy's built-in catch-all rule should be set to DENY in the Okta console
# or managed with the provider's catch-all rule support for your provider version.

# ---------------------------------------------------------------------------
# Pattern A only — PeopleTools 8.63 native SAML 2.0 service provider.
# For pattern B (Okta Access Gateway) the gateway application is configured in
# Access Gateway and assigned the same authentication policy.
# ---------------------------------------------------------------------------
resource "okta_app_saml" "peoplesoft" {
  count                    = var.pattern == "A" ? 1 : 0
  label                    = "PeopleSoft Financials"
  sso_url                  = var.ps_acs_url
  recipient                = var.ps_acs_url
  destination              = var.ps_acs_url
  audience                 = var.ps_entity_id
  subject_name_id_template = "$${user.psOprid}"
  subject_name_id_format   = "urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified"
  response_signed          = true
  assertion_signed         = true
  signature_algorithm      = "RSA_SHA256"
  digest_algorithm         = "SHA256"
  authn_context_class_ref  = "urn:oasis:names:tc:SAML:2.0:ac:classes:PasswordProtectedTransport"
  authentication_policy    = okta_app_signon_policy.peoplesoft.id
}
