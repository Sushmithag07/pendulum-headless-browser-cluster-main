locals {
  region     = var.aws_region
  account_id = data.aws_caller_identity.current.account_id
  workspace  = terraform.workspace
  name       = "${terraform.workspace}_cp_ssr"
  stack_name = "headless-browser-tf"
}
