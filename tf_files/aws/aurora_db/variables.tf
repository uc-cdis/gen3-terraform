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

# The username used to access the database you're trying to create 
# (for example, if this is a fence database, it might be 'fence_user')
variable "username" {
  default = ""
}

# The password used to access the database you're trying to create
variable "password" {
  default = ""
}

variable "secrets_manager_enabled" {
  default = true
}

# If you want to dump a database to an object in S3, then restore it, this variable is the S3 file
# to download and restore
variable "dump_file_to_restore" {
  default = ""
}

# If you want to take a dump of the database, this is where in S3 the file will be uploaded to
variable "dump_file_storage_location" {
  default = ""
}

variable "db_restore" {
  default = false
}

variable "db_dump" {
  default = false
}

variable "db_job_role_arn" {
  default = ""
}

variable "create_db" {
  default = true
}
