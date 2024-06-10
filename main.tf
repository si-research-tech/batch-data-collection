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
  source  = "./modules/iam"
  project = var.project
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

  source                = "./modules/rds"
  project               = var.project
  storage               = var.rds.max_storage
  rds_monitoring_role   = "${module.iam.rds_monitoring_role_arn}"
  rds_security_group    = "${module.network.rds_security_group}"
  db_subnet_group       = "${module.network.rds_subnet_group}"

  depends_on            = [
    module.iam,
    module.network
  ]
}

module "batch" {
  source = "./modules/batch"

  project         = var.project
  jobs            = var.jobs
  batch_config    = var.batch
  fargate_config  = var.fargate

  depends_on = [
    module.iam,
    module.sqs,
    module.rds,
    module.s3
  ]
}
