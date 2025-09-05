variable account_ids {
  description = "List of AWS account IDs to create backup vaults for"
  type        = set(string) 
  validation {
    condition = alltrue([
      for account_id in var.account_ids : can(regex("^[0-9]{12}$", account_id))
    ])
    error_message = "Account IDs must be 12-digit strings."
  }
}