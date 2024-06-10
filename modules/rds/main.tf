variable "project" {}
variable "storage" {}
variable "rds_monitoring_role" {}
variable "rds_security_group" {}
variable "db_subnet_group" {}

locals {
  timestamp = formatdate("DDMMMYYYYhhmmZZZ", timestamp())
}

resource "aws_db_instance" "default" {
  db_name                             = "${var.project}"
  identifier                          = "${var.project}"
  engine                              = "mysql"
  instance_class                      = "db.t3.medium"
  db_subnet_group_name                = "${var.db_subnet_group}"
  publicly_accessible                 = true
  username                            = "${var.project}"
  allocated_storage                   = "${var.storage}"
  max_allocated_storage               = 1000
  manage_master_user_password         = true
  iam_database_authentication_enabled = true
  monitoring_interval                 = 30
  monitoring_role_arn                 = var.rds_monitoring_role
  backup_window                       = "07:00-08:00"
  backup_retention_period             = 7
  maintenance_window                  = "Sat:05:00-Sat:06:00"
  vpc_security_group_ids              = ["${var.rds_security_group}"]
  final_snapshot_identifier           = "${var.project}-${local.timestamp}"

  provisioner "local-exec" {
    command = "evsales-aws rds stop-db-instance --db-instance-identifier ${aws_db_instance.default.identifier}"
  }
}

module "eventbridge" {
  source = "./modules/eventbridge"
  project = var.project
}

# Alex- output the master secret
output "database_master_credentials_arn" {
  value = aws_db_instance.default.master_user_secret.0.secret_arn
}

output "database_address" {
  value = aws_db_instance.default.address
}

output "database_identifier" {
  value = aws_db_instance.default.identifier
}
