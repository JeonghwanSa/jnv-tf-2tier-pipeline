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
variable "build_image_credential_type" {
  default = "CODEBUILD"
}
variable "build_privileged_mode" {
  type    = bool
  default = false
}
variable "buildspec_name" {
  default = "buildspec.yaml"
}
variable "codebuild_vpc_id" {
  default = ""
}
variable "codebuild_vpc_subnets" {
  default = [""]
}
variable "codebuild_vpc_sg" {
  default = [""]
}
variable "codebuild_environment_variables" {
  default = []
}
variable "need_approval" {
  type    = bool
  default = false
}
variable "github_connection_arn" {}
variable "github_fullrepository_id" {}
