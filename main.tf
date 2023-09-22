data "aws_caller_identity" "current" {}
locals {
  account_id = data.aws_caller_identity.current.account_id
}

resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = join("-", ["${var.jnv_project}", "${var.jnv_region}", lower("${var.application_name}"), "pipeline-artifact", "${var.jnv_environment}"])
}

resource "aws_s3_bucket_ownership_controls" "bucketownership" {
  bucket = aws_s3_bucket.codepipeline_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.codepipeline_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_role" "codepipeline_role" {
  name = join("-", ["${var.jnv_project}", "${var.jnv_region}", "${var.application_name}", "pipeline-service-role", "${var.jnv_environment}"])

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  name = "codepipeline_policy"
  role = aws_iam_role.codepipeline_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ec2:Describe*",
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning",
          "s3:PutObject"
        ],
        Resource = [
          "${aws_s3_bucket.codepipeline_bucket.arn}",
          "${aws_s3_bucket.codepipeline_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "codebuild:BatchGetBuilds",
          "codebuild:StartBuild",
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "codestar-connections:UseConnection"
        ],
        Resource = [
          "${var.github_connection_arn}"
        ]
      }
    ]
  })
}

resource "aws_codepipeline" "jnv-2tier-pipeline" {
  name     = join("-", ["${var.jnv_project}", "${var.jnv_region}", "${var.application_name}", "pipeline", "${var.jnv_environment}"])
  role_arn = aws_iam_role.codepipeline_role.arn
  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }
  stage {
    name = "Source"
    action {
      name             = "FetchCode"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      run_order        = 1
      output_artifacts = ["SourceArtifact"]
      configuration = {
        ConnectionArn    = var.github_connection_arn
        FullRepositoryId = var.github_fullrepository_id
        BranchName       = var.pipeline_branch
      }
    }
  }
  dynamic "stage" {
    for_each = var.need_approval == true ? [1] : []
    content {
      name = "Approval"
      action {
        name     = "Approval"
        category = "Approval"
        owner    = "AWS"
        provider = "Manual"
        version  = "1"
      }
    }
  }
  stage {
    name = "Build"
    action {
      category = "Build"
      configuration = {
        "ProjectName" = "${aws_codebuild_project.codebuild_project.name}"
      }
      input_artifacts = [
        "SourceArtifact",
      ]
      name      = "Build"
      owner     = "AWS"
      provider  = "CodeBuild"
      run_order = 1
      version   = "1"
    }
  }
}

resource "aws_iam_role" "codebuild" {
  name = join("-", ["${var.jnv_project}", "${var.jnv_region}", "${var.application_name}", "cb-service-role", "${var.jnv_environment}"])

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# TODO: fix policy
# resource "aws_iam_role_policy_attachment" "codebuild_role_attach" {
#   role       = aws_iam_role.codebuild.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# }
resource "aws_iam_role_policy" "codebuild_policy" {
  name = "codebuild_policy"
  role = aws_iam_role.codebuild.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "cloudformation:*",
          "ecs:*",
          "ecr:*",
          "ec2:*",
          "lambda:*",
          "apigateway:*",
          "iam:PassRole",
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Resource = [
          "${aws_s3_bucket.codepipeline_bucket.arn}",
          "${aws_s3_bucket.codepipeline_bucket.arn}/*"
        ],
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketAcl",
          "s3:GetBucketLocation"
        ]
      },
      {
        Effect = "Allow",
        Resource = [
          "arn:aws:logs:ap-northeast-2:${local.account_id}:log-group:/aws/codebuild/*",
          "arn:aws:logs:ap-northeast-2:${local.account_id}:log-group:/aws/codebuild/*:*",
        ],
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
      }
    ]
  })
}

resource "aws_codebuild_project" "codebuild_project" {
  badge_enabled  = false
  build_timeout  = 60
  name           = join("-", ["${var.jnv_project}", "${var.jnv_region}", "${var.application_name}", "cb", "${var.jnv_environment}"])
  queued_timeout = 480
  service_role   = aws_iam_role.codebuild.arn
  artifacts {
    encryption_disabled    = false
    name                   = var.application_name
    override_artifact_name = true
    packaging              = "NONE"
    type                   = "CODEPIPELINE"
  }

  environment {
    compute_type                = var.build_compute_size
    image                       = var.build_image
    image_pull_credentials_type = var.build_image_credential_type
    privileged_mode             = var.build_privileged_mode
    type                        = "LINUX_CONTAINER"

    environment_variable {
      name  = "CODEPIPELINE_BUCKET"
      value = aws_s3_bucket.codepipeline_bucket.id
    }

    dynamic "environment_variable" {
      for_each = var.codebuild_environment_variables
      content {
        type  = environment_variable.value["type"]
        name  = environment_variable.value["name"]
        value = environment_variable.value["value"]
      }
    }
  }

  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }

    s3_logs {
      encryption_disabled = false
      status              = "DISABLED"
    }
  }

  source {
    git_clone_depth     = 0
    insecure_ssl        = false
    report_build_status = false
    type                = "CODEPIPELINE"
    buildspec           = var.bulidspec_name
  }

  dynamic "vpc_config" {
    for_each = var.codebuild_vpc_id != "" ? [1] : []
    content {
      security_group_ids = var.codebuild_vpc_sg
      subnets            = var.codebuild_vpc_subnets
      vpc_id             = var.codebuild_vpc_id
    }
  }

  # lifecycle {
  #   ignore_changes = [
  #     environment[0].environment_variable
  #   ]
  # }
}
