migration "state" "migrate_github_oidc" {
  dir   = "./this_repo_policy"
  force = true # If the state in which the terraform plan difference after import is expected, set this to true.
  actions = [
    "mv 'aws_iam_openid_connect_provider.github[0]' 'module.iam_github_oidc_provider.aws_iam_openid_connect_provider.this[0]'",
    "mv 'aws_iam_role.github[0]' 'module.iam_github_oidc_role.aws_iam_role.this[0]'",
    "mv 'aws_iam_role_policy_attachment.admin[0]' 'module.iam_github_oidc_role.aws_iam_role_policy_attachment.this[\"admin\"]'",
  ]
}
