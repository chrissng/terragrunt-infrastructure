module "iam_github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-provider"
  version = "~> 5.28"

  create = true
  client_id_list = [
    "https://github.com/chrissng",
    "sts.amazonaws.com",
  ]
}

module "iam_github_oidc_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "~> 5.28"

  create                = true
  name                  = "github"
  description           = "Role assumed by the GitHub OIDC provider."
  force_detach_policies = false
  provider_url          = module.iam_github_oidc_provider.url

  subjects = [
    "repo:chrissng/terragrunt-infrastructure:*"
  ]

  policies = {
    admin = "arn:aws:iam::aws:policy/AdministratorAccess"
  }
}
