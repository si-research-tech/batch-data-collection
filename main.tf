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

resource "aws_cloudwatch_log_group" "default" {
  name              = "${var.project}"
  retention_in_days = 30
}

module "network" {
  source  = "./modules/network"
  project = var.project
}

module "iam" {
  source          = "./modules/iam"
  project         = var.project
  lambda_enabled  = var.lambda.create
  rds_enabled     = var.rds.create
  s3_enabled      = var.s3.create
  sqs_enabled     = var.sqs.create
}

module "s3" {
  count = var.s3.create ? 1 : 0
  source = "terraform-aws-modules/s3-bucket/aws"

  bucket = "${var.project}"
}

module "sqs" {
  count   = var.sqs.create ? 1 : 0
  source  = "terraform-aws-modules/sqs/aws"

  name                      = "${var.project}"
  message_retention_seconds = var.sqs.max_retention_seconds
  create_dlq                = true

  redrive_policy            = {
    maxReceiveCount = "${var.sqs.max_recieve_attempts}"
  }

  depends_on  = [
    module.iam,
    module.network
  ]
}

module "rds" {
  count = var.rds.create ? 1 : 0

  source  = "./modules/rds"
  project = var.project
  config  = var.rds

  depends_on  = [
    module.iam,
    module.network
  ]
}

module "aws_batch" {
  count = var.batch.enabled ? 1 : 0
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
  count = var.cloud_run.enabled ? 1 : 0
  provisioner "local-exec" {
    command = "export GOOGLE_APPLICATION_CREDENTIALS='./etc/gcp-service-account.json'"
  }
}

module "aws_cloud_run" {
  count = var.cloud_run.enabled ? 1 : 0
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
