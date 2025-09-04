resource "aws_cognito_user_pool" "cognito_pool" {
  count = local.deploy_cognito ? 1 : 0
  name  = local.user_pool_name

  alias_attributes = ["email"]
  username_configuration {
    case_sensitive = false
  }

  auto_verified_attributes = ["email"]

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
    string_attribute_constraints {
      min_length = "5"
      max_length = "2048"
    }
  }

  schema {
    name                = "given_name"
    attribute_data_type = "String"
    required            = true
    mutable             = true
    string_attribute_constraints {
      min_length = "1"
      max_length = "2048"
    }
  }

  schema {
    name                = "family_name"
    attribute_data_type = "String"
    required            = true
    mutable             = true
    string_attribute_constraints {
      min_length = "1"
      max_length = "2048"
    }
  }

  password_policy {
    minimum_length                   = 8
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 7
  }

  mfa_configuration = "OFF"

  device_configuration {
    challenge_required_on_new_device      = false
    device_only_remembered_on_user_prompt = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
    recovery_mechanism {
      name     = "verified_phone_number"
      priority = 2
    }
  }

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }

}

resource "aws_cognito_user_pool_domain" "cognito_domain" {
  count        = local.deploy_cognito ? 1 : 0
  user_pool_id = aws_cognito_user_pool.cognito_pool[0].id
  domain       = local.domain_prefix
}

resource "aws_cognito_user_pool_client" "cognito_client" {
  count        = local.deploy_cognito ? 1 : 0
  name         = local.app_client_name
  user_pool_id = aws_cognito_user_pool.cognito_pool[0].id

  generate_secret = true

  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = local.allowed_oauth_flows
  allowed_oauth_scopes                 = local.allowed_oauth_scopes
  supported_identity_providers         = local.supported_identity_providers

  callback_urls = local.callback_urls
  logout_urls   = local.logout_urls

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  enable_token_revocation       = true
  prevent_user_existence_errors = "ENABLED"

  access_token_validity  = 60
  id_token_validity      = 60
  refresh_token_validity = 5
  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
  auth_session_validity = 3
}
