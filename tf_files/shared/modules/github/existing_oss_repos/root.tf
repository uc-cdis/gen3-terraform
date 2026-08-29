# TODO: plan to accept forks
# data "github_organization_teams" "all" {}
data "github_organization_teams" "root_teams" {
  root_teams_only = true
}

data "github_external_groups" "external" {}

data "github_organization" "this" {
  name = var.github_organization
}

data "github_repository" "this" {
  full_name = "${data.github_organization.this.name}/${var.existing_repository}"
}

resource "github_branch" "development" {
  repository = data.github_repository.this.name
  branch     = "development"
}

resource "github_branch" "main" {
  repository = data.github_repository.this.name
  branch     = "main"
}

resource "github_branch_default" "default" {
  repository = data.github_repository.this.name
  branch     = github_branch.main.branch
}

locals {
  # TODO: no external groups in foreach
}

resource "github_organization_ruleset" "open_source_images" {
  name        = "open_source_software"
  target      = "branch"
  enforcement = "active"

  conditions {
    ref_name {
      include = [""]
      exclude = []
    }
  }

  bypass_actors {
    actor_type  = "OrganizationalAdmin"
    bypass_mode = "always"
  }

  # TODO: check this
  dynamic "bypass_actors" {
    for_each    = data.github_organization_teams.root_teams
    actor_id    = bypass_actors.value.node_id
    actor_type  = "Team"
    bypass_mode = "exempt"
  }


  rules {
    creation                = true
    update                  = true
    deletion                = true
    required_linear_history = true
    required_signatures     = false # FIXME: document it

    #    required_workflows {
    #      do_not_enforce_on_create = true
    #      required_workflow {
    #        repository_id = 1234
    #        path          = ".github/workflows/ci.yml"
    #        ref           = "main"
    #      }
    #    }
    #
    #    required_code_scanning {
    #      required_code_scanning_tool {
    #        alerts_threshold          = "errors"
    #        security_alerts_threshold = "high_or_higher"
    #        tool                      = "CodeQL"
    #      }
    #    }
    max_file_size {
      max_file_size = 100 # 100 MB
    }

    # If windowsproblems 64
    max_file_path_length {
      max_file_path_length = 255
    }

    # TODO: make cat .gitignore
    file_extension_restriction {
      restricted_file_extensions = ["*.exe", "*.dll", "*.so"]
    }
  }
}
