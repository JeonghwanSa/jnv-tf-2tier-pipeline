# JNV_TF_2TIER_PIPELINE

## description
* 2-Tier(Source-Build) 파이프라인을 구성하는 모듈

## example
```
module "jnv_tf_2tier_pipeline" {
  source                   = "git::https://github.com/JeonghwanSa/jnv-tf-2tier-pipeline.git"
  application_name         = "jobis-example"
  pipeline_branch          = "main"
  github_connection_arn    = "arn:aws:codestar-connections:ap-northeast-2:111122223333:connection/1234abcd-5678-efgh-9000-ijkl0000mnop"
  github_fullrepository_id = "jobisnvillains/szs-jobis-example-tf"
}
```