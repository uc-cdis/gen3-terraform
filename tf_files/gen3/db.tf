module "arborist-db" {
  count                            = var.arborist_enabled ? 1 : 0
  source                           = "../aws/aurora_db"
  vpc_name                         = var.vpc_name
  service                          = "arborist"
  database_instance_identifier     = var.database_instance_identifier
  admin_database_username          = var.aurora_username
  admin_database_password          = var.aurora_password
  namespace                        = var.namespace
  create_db                        = var.create_dbs
  secrets_manager_enabled          = true
}

module "argo-db" {
  count                            = var.argo_enabled ? 1 : 0
  source                           = "../aws/aurora_db"
  vpc_name                         = var.vpc_name
  service                          = "argo"
  database_instance_identifier     = var.database_instance_identifier
  admin_database_username          = var.aurora_username
  admin_database_password          = var.aurora_password
  namespace                        = var.namespace
  create_db                        = var.create_dbs
  secrets_manager_enabled          = true
}

module "audit-db" {
  count                            = var.audit_enabled ? 1 : 0
  source                           = "../aws/aurora_db"
  vpc_name                         = var.vpc_name
  service                          = "audit"
  database_instance_identifier     = var.database_instance_identifier
  admin_database_username          = var.aurora_username
  admin_database_password          = var.aurora_password
  namespace                        = var.namespace
  create_db                        = var.create_dbs
  secrets_manager_enabled          = true
}

module "dicom-viewer-db" {
  count                            = var.dicom-viewer_enabled ? 1 : 0
  source                           = "../aws/aurora_db"
  vpc_name                         = var.vpc_name
  service                          = "dicom"
  database_instance_identifier     = var.database_instance_identifier
  admin_database_username          = var.aurora_username
  admin_database_password          = var.aurora_password
  namespace                        = var.namespace
  create_db                        = var.create_dbs
  secrets_manager_enabled          = true
}

module "dicom-server-db" {
  count                            = var.dicom-server_enabled ? 1 : 0
  source                           = "../aws/aurora_db"
  vpc_name                         = var.vpc_name
  service                          = "dicom-server"
  database_instance_identifier     = var.database_instance_identifier
  admin_database_username          = var.aurora_username
  admin_database_password          = var.aurora_password
  namespace                        = var.namespace
  create_db                        = var.create_dbs
  secrets_manager_enabled          = true
}

module "fence-db" {
  count                            = var.fence_enabled ? 1 : 0
  source                           = "../aws/aurora_db"
  vpc_name                         = var.vpc_name
  service                          = "fence"
  database_instance_identifier     = var.database_instance_identifier
  admin_database_username          = var.aurora_username
  admin_database_password          = var.aurora_password
  namespace                        = var.namespace
  create_db                        = var.create_dbs
  secrets_manager_enabled          = true
}

module "indexd-db" {
  count                            = var.indexd_enabled ? 1 : 0
  source                           = "../aws/aurora_db"
  vpc_name                         = var.vpc_name
  service                          = "indexd"
  database_instance_identifier     = var.database_instance_identifier
  admin_database_username          = var.aurora_username
  admin_database_password          = var.aurora_password
  namespace                        = var.namespace
  create_db                        = var.create_dbs
  secrets_manager_enabled          = true
}

module "metadata-db" {
  count                            = var.metadata_enabled ? 1 : 0
  source                           = "../aws/aurora_db"
  vpc_name                         = var.vpc_name
  service                          = "metadata"
  database_instance_identifier     = var.database_instance_identifier
  admin_database_username          = var.aurora_username
  admin_database_password          = var.aurora_password
  namespace                        = var.namespace
  create_db                        = var.create_dbs
  secrets_manager_enabled          = true
}

module "requestor-db" {
  count                            = var.requestor_enabled ? 1 : 0
  source                           = "../aws/aurora_db"
  vpc_name                         = var.vpc_name
  service                          = "requestor"
  database_instance_identifier     = var.database_instance_identifier
  admin_database_username          = var.aurora_username
  admin_database_password          = var.aurora_password
  namespace                        = var.namespace
  create_db                        = var.create_dbs
  secrets_manager_enabled          = true
}

module "sheepdog-db" {
  count                            = var.sheepdog_enabled ? 1 : 0
  source                           = "../aws/aurora_db"
  vpc_name                         = var.vpc_name
  service                          = "sheepdog"
  database_instance_identifier     = var.database_instance_identifier
  admin_database_username          = var.aurora_username
  admin_database_password          = var.aurora_password
  namespace                        = var.namespace
  create_db                        = var.create_dbs
  secrets_manager_enabled          = true
}

module "wts-db" {
  count                            = var.wts_enabled ? 1 : 0
  source                           = "../aws/aurora_db"
  vpc_name                         = var.vpc_name
  service                          = "wts"
  database_instance_identifier     = var.database_instance_identifier
  admin_database_username          = var.aurora_username
  admin_database_password          = var.aurora_password
  namespace                        = var.namespace
  create_db                        = var.create_dbs
  secrets_manager_enabled          = true
}
