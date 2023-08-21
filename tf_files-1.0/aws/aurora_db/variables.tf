variable "vpc_name" {
  default = ""
}

variable "service" {
  default = ""
}

variable "admin_database_username" {
  default = "postgres"
}

variable "admin_database_name" {
  default = "postgres"
}

variable "admin_database_password" {
  default = ""
}

variable "namespace" {
  default = "default"
}

variable "role" {
  default = ""
}

variable "database_name" {
  default = ""
}

variable "username" {
  default = ""
}

variable "password" {
  default = ""
}

variable "secrets_manager_enabled" {
  default = true
}
