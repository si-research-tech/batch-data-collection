locals {
  # Manipulate vars.user_variables here to create locals for use in modules
}

provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      project   = var.project
    }
  }
}

provider "google" {
  project = "drivinghistory-f548"
  region  = "us-central1"
  access_token = "123thisisafaketoken456"
}

resource "aws_cloudwatch_log_group" "default" {
  name              = "${var.project}"
  retention_in_days = 30
}

module "iam" {
  source  = "./modules/iam"
  project = "${var.project}"
  components = var.components
}

module "sqs" {
  count   = var.components.sqs ? 1 : 0
  source  = "terraform-aws-modules/sqs/aws"

  name                      = "${var.project}"
  message_retention_seconds = var.sqs.max_retention_seconds
  create_dlq                = true

  redrive_policy            = {
    maxReceiveCount = "${var.sqs.max_recieve_attempts}"
  }

  depends_on = [ module.iam ]
}

module "rds" {
  count = var.components.rds ? 1 : 0

  source  = "./modules/rds"
  project = var.project
  config  = var.rds

  depends_on = [ module.iam ]
}

output "db_endpoint" {
  value = try(module.rds.0.db_endpoint, "None")
}

module "aws_batch" {
  count = var.components.batch ? 1 : 0
  source = "./modules/aws_batch"

  project         = var.project
  jobs            = var.jobs
  batch_config    = var.batch
  fargate_config  = var.batch.fargate_config

  depends_on = [
    module.iam, 
    module.sqs,
    module.rds,
    module.s3
  ]
}

resource "terraform_data" "gcp_environ" {
  count = var.components.cloud_run ? 1 : 0
  provisioner "local-exec" {
    command = "export GOOGLE_APPLICATION_CREDENTIALS='./etc/gcp-service-account.json'"
  }
}

module "aws_cloud_run" {
  count = var.components.cloud_run ? 1 : 0
  source = "./modules/gcp_cloud_run"

  cloud_run_config  = var.cloud_run
  project           = var.project
  jobs              = var.jobs

  depends_on = [
    module.iam,
    module.sqs,
    module.rds,
    module.s3
  ]
}

module "s3" {
  count = var.components.s3 ? 1 : 0
  source = "./modules/s3"

  project = "${var.project}"
  config = var.s3

  depends_on = [ module.iam ]
}

output "cloudfront_domain" {
  value = module.s3.0.cloudfront_domain
}
