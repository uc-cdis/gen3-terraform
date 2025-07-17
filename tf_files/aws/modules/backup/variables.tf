variable "retention_period" {
  description = "The number of days to retain the backup"
  type        = number
  default     = 7
}

variable "excluded_dbs" {
  description = "A list of DB ARNs to be EXCLUDED from this backup"
  type        = list
  default     = []
}
