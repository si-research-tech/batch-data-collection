variable "project" {}
variable "config" {}

module "iam" {
  source = "./modules/iam"
  project = var.project
}

module "network" {
  source = "./modules/iam"
  project = var.project
}

data "aws_iam_role" "rds_monitoring" {
  name = "${var.project}-rds-monitoring-role"

  depends_on = [
    module.network,
    module.iam
  ]
}

data "aws_security_group" "rds_security" {
  name        = "${var.project}_rds"

  depends_on = [
    module.network,
    module.iam
  ]
}

data "aws_db_subnet_group" "rds" {
  name       = "${var.project}_rds"

  depends_on = [
    module.network,
    module.iam
  ]
}

locals {
  timestamp = formatdate("DDMMMYYYYhhmmZZZ", timestamp())
}

resource "aws_db_instance" "default" {
  db_name                             = "${var.project}"
  identifier                          = "${var.project}"
  engine                              = "${var.config.engine}"
  engine_version                      = "${var.config.engine_version}"
  instance_class                      = "${var.config.instance_class}"
  db_subnet_group_name                = "${data.aws_db_subnet_group.rds.name}"
  publicly_accessible                 = "${var.config.publicly_accessible}"
  username                            = "${var.project}"
  allocated_storage                   = 20
  max_allocated_storage               = "${var.config.max_storage}"
  manage_master_user_password         = true
  monitoring_interval                 = 30
  monitoring_role_arn                 = data.aws_iam_role.rds_monitoring.arn
  backup_window                       = "07:00-08:00"
  backup_retention_period             = 7
  maintenance_window                  = "Sat:05:00-Sat:06:00"
  vpc_security_group_ids              = ["${data.aws_security_group.rds_security.id}"]
  final_snapshot_identifier           = "${var.project}-${local.timestamp}"

  lifecycle {
    ignore_changes = [ final_snapshot_identifier ]
  } 

  depends_on = [
    module.network,
    module.iam
  ]
}

module "eventbridge" {
  source = "./modules/eventbridge"
  project = var.project

  depends_on = [
    module.network,
    module.iam
  ]
}

output "db_endpoint" {
  value = aws_db_instance.default.endpoint
}
