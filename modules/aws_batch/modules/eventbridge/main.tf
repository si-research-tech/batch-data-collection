variable job {}
variable project {}


data "aws_iam_role" "eventbridge" {
  name  = "${var.project}_eventbridge-execution"
}

data "aws_batch_job_queue" "default" {
  name  = "${var.project}_default"
}

data "aws_batch_job_definition" "this" {
  name  = var.job.name
}

resource "random_pet" "this" {
  prefix = var.job.name
}

resource "aws_scheduler_schedule" "batch_schedule_runner" {
  for_each = { for index, instance in var.job.scheduling.instances : md5(instance.aws_schedule) => instance }

  name                          = "${var.project}_${random_pet.this.id}"
  group_name                    = "default"
  schedule_expression           = "cron(${each.value.aws_schedule})"
  schedule_expression_timezone  = "America/New_York"

  flexible_time_window {
    maximum_window_in_minutes   = "10"
    mode                        = "FLEXIBLE"
  }

  target {
    arn                         = "arn:aws:scheduler:::aws-sdk:batch:submitJob"
    role_arn                    = "${data.aws_iam_role.eventbridge.arn}"

    input = jsonencode({
      JobName                     = "${var.project}_${random_pet.this.id}_${timestamp()}"
      JobDefinition               = "${data.aws_batch_job_definition.this.arn}"
      JobQueue                    = "${data.aws_batch_job_queue.default.arn}"
      ShareIdentifier             = try("${each.value.share_identifier}", "${var.job.scheduling.share_identifier}")
      ContainerOverrides           = {
        Environment = try("${each.value.environment}", [])
      }
    })
  }
}
