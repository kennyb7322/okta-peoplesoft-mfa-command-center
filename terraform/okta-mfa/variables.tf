variable "okta_org_name" {
  description = "Okta org name, e.g. 'example' for example.okta.com"
  type        = string
}

variable "okta_base_url" {
  description = "Okta base domain"
  type        = string
  default     = "okta.com"
}

variable "pattern" {
  description = "Integration pattern: A (native SAML, PeopleTools 8.63), B (Okta Access Gateway), C (web-tier agent)"
  type        = string
  default     = "B"
  validation {
    condition     = contains(["A", "B", "C"], var.pattern)
    error_message = "pattern must be A, B, or C."
  }
}

variable "trusted_cidrs" {
  description = "Trusted network ranges (CIDR) — illustrative documentation ranges by default"
  type        = list(string)
  default     = ["198.51.100.0/24"]
}

variable "admin_cidrs" {
  description = "Admin network ranges allowed for privileged PeopleSoft sign-in"
  type        = list(string)
  default     = ["203.0.113.0/27"]
}

variable "ps_acs_url" {
  description = "PeopleSoft SAML assertion consumer service URL (pattern A)"
  type        = string
  default     = "https://ps-fin.example.gov/psp/FSPRD/?cmd=login"
}

variable "ps_entity_id" {
  description = "PeopleSoft SAML service provider entity ID (pattern A)"
  type        = string
  default     = "https://ps-fin.example.gov/sp"
}
