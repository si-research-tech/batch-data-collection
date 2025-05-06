variable project {}

data "aws_iam_role" "eventbridge" {
  name  = "${var.project}_eventbridge-batch-execution"
}

resource "aws_scheduler_schedule" "rds_activate" {
  name                          = "database-spinup-${var.project}"
  group_name                    = "default"
  schedule_expression           = "cron(30 2 * * ? *)"
  schedule_expression_timezone  = "America/New_York"

  flexible_time_window {
    mode                        = "OFF"
  }

  target {
    arn                         = "arn:aws:scheduler:::aws-sdk:rds:startDBInstance"
    role_arn                    = "${data.aws_iam_role.eventbridge.arn}"

    input = jsonencode({
      DbInstanceIdentifier      = "${var.project}"
    })
  }
}

resource "aws_scheduler_schedule" "rds_deactivate" {
  name                          = "database-spindown-${var.project}"
  group_name                    = "default"
  schedule_expression           = "cron(30 6 * * ? *)"
  schedule_expression_timezone  = "America/New_York"

  flexible_time_window {
    mode                        = "OFF"
  }
  
  target {
    arn                         = "arn:aws:scheduler:::aws-sdk:rds:stopDBInstance"
    role_arn                    = "${data.aws_iam_role.eventbridge.arn}"

    input = jsonencode({
      DbInstanceIdentifier      = "${var.project}"
    })
  }
}
