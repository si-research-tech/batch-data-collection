# Variables #
variable project {}
variable jobs {}
variable fargate_config {}
variable batch_config {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "private_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_cloudwatch_log_group" "default" {
  name  = "${var.project}"
}
data "aws_iam_role" "ecs_task_execution" {
  name  = "${var.project}_ecs-task-execution"
}

data "aws_iam_role" "batch_service" {
  name  = "${var.project}_batch-service"
}

data "aws_iam_role" "batch_task" {
  name  = "${var.project}_batch-task"
}

data "aws_security_group" "fargate" {
  name  = "${var.project}_fargate"
}

resource "aws_batch_compute_environment" "fargate" {
    compute_environment_name    = "AWSBatch_${var.project}"
    service_role                = data.aws_iam_role.batch_service.arn
    type                        = "MANAGED"

    compute_resources {
      max_vcpus = var.fargate_config.compute_environment.max_vcpus
      security_group_ids = [ data.aws_security_group.fargate.id ]
      subnets = data.aws_subnets.private_subnets.ids
      type = var.fargate_config.compute_environment.use_spot ? "FARGATE_SPOT" : "FARGATE"
    }
}

resource "aws_batch_scheduling_policy" "queue-scheduling-policy" {
  name = "${var.project}_default"

  fair_share_policy {
    compute_reservation = var.batch_config.fair_share_policy.compute_reservation
    share_decay_seconds = var.batch_config.fair_share_policy.share_decay_seconds

    dynamic "share_distribution" {
      for_each = var.batch_config.share_distributions

      content {
        share_identifier  = share_distribution.value.share_identifier
        weight_factor     = share_distribution.value.weight_factor
      }
    }
  }
}

resource "aws_batch_job_queue" "fargate_queue" {
  name      = "${var.project}_default"
  state     = "ENABLED"
  priority  = 1
  scheduling_policy_arn = aws_batch_scheduling_policy.queue-scheduling-policy.arn

  compute_environment_order {
    order               = 0
    compute_environment = aws_batch_compute_environment.fargate.arn
  } 

}

resource "aws_batch_job_definition" "job_definitions" {
  for_each = { for index, job in var.jobs : job.name => job }

  name = "${each.value.name}"
  scheduling_priority = 9999
  type = "container"

  platform_capabilities = [ "FARGATE" ]

  container_properties = jsonencode({
    executionRoleArn  = "${data.aws_iam_role.ecs_task_execution.arn}"
    image             = "${each.value.image_uri}"
    jobRoleArn        = "${data.aws_iam_role.batch_task.arn}"
    environment       = "${each.value.environment}"
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group = "${data.aws_cloudwatch_log_group.default.name}"
        awslogs-stream-prefix = "${each.value.name}"
      }
    }

    timeout = {
      attempt_duration_seconds = "300"
    }

    fargatePlatformConfiguration = {
      platformVersion = "LATEST"
    }

    networkConfiguration = { 
      assignPublicIp = each.value.assign_public_ip ? "ENABLED" : "DISABLED"
    }

    runtimePlatform = {
      cpuArchitecture = "${each.value.runtime_platform}"
    }

    resourceRequirements = [
      {
       type  = "VCPU"
        value = "${each.value.vcpus}"
      },
      {
        type  = "MEMORY"
        value = "${each.value.memory}"
      }
    ]
  })

  lifecycle {
    ignore_changes = [ container_properties ]
  }
}

module "eventbridge_schedule" {
  for_each = { for index, job in var.jobs : job.name => job if job.scheduling.enabled }
  source  = "./modules/eventbridge"

  project = var.project
  job     = each.value

  depends_on = [ aws_batch_job_definition.job_definitions ]
}
