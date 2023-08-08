variable "application_name" {}
variable "jnv_project" {
  default = "szs"
}
variable "jnv_region" {
  default = "apne2"
}
variable "jnv_environment" {
  default = "dev"
}
variable "pipeline_branch" {}
variable "build_compute_size" {
  default = "BUILD_GENERAL1_LARGE"
}
variable "build_image" {
  default = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
}
variable "bulidspec_name" {
  default = "buildspec.yaml"
}
variable "need_approval" {
  type    = bool
  default = false
}
variable "github_connection_arn" {}
variable "github_fullrepository_id" {}
