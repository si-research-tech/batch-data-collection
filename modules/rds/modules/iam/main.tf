variable project {}

###############################################################################
# RDS Monitoring Role                                                  BEGIN  #
#                                                                             #
#   Role granted to EventBridge to allow for execution of Batch jobs          # 
###############################################################################
data "aws_iam_policy_document" "rds-monitoring-assumption" {
  statement {
    sid     = "RDSMonitoringBatchJobAssuptionPolicy"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["monitoring.rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_monitoring" {
  name        = "${var.project}-rds-monitoring-role"
  path        = "/${var.project}/rds/"
  description = "IAM service role for RDS/Cloudwatch Interaction"
  assume_role_policy  = data.aws_iam_policy_document.rds-monitoring-assumption.json

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "rds_monitoring" {
  statement {
    sid     = "EnableCreationAndManagementOfRDSCloudwatchLogGroups"
    actions = [
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy",
    ]
    resources = ["arn:aws:logs:*:*:log-group:RDS*"]
  }

  statement {
    sid     = "EnableCreationAndManagementOfRDSCloudwatchLogStreams"
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:GetLogEvents"
    ]
    resources = ["arn:aws:logs:*:*:log-group:RDS*:log-stream:*"]
  }
}

resource "aws_iam_policy" "rds_monitoring" {
  name   = "${var.project}-rds-monitoring-policy"
  path   = "/${var.project}/rds/"
  policy = data.aws_iam_policy_document.rds_monitoring.json
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
###############################################################################
# RDS Monitoring Role                                                    END  #
###############################################################################
