variable project {}

data "aws_partition" "current_partition" {}
data "aws_region" "current_region" {}
data "aws_caller_identity" "current_identity" {}


#######################################################################
# ECS Task Execution Role                                      BEGIN  #
#                                                                     #
#  The execution role grants the Amazon ECS container and AWS Fargate #
#  agents permission to make AWS API calls on your behalf.            #
#######################################################################
data "aws_iam_policy_document" "ecs_task_execution_assumption_policy" {
  statement {
    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name               = "${var.project}_ecs-task-exec"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assumption_policy.json
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_access_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
#######################################################################
# ECS Task Execution Role                                        END  #
#######################################################################


#######################################################################
# Compute Environment Batch Service Role                       BEGIN  #
#                                                                     #
#  Makes calls to other AWS services on your behalf to manage the     #
#  resources that you use with AWS Batch.                             #
#######################################################################
data "aws_iam_policy_document" "service-assumption" {
  statement {
    sid     = "ECSBatchServiceAssumptionPolicy"
    actions = [ "sts:AssumeRole" ]

    principals {
      type        = "Service"
      identifiers = ["batch.${data.aws_partition.current_partition.dns_suffix}"]
    }
  }
}

data "aws_iam_policy_document" "service-execution" {
  statement {
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeInstances",
      "ec2:DescribeInstanceStatus",
      "ec2:DescribeInstanceAttribute",
      "ec2:DescribeSubnets",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeKeyPairs",
      "ec2:DescribeImages",
      "ec2:DescribeImageAttribute",
      "ec2:DescribeSpotInstanceRequests",
      "ec2:DescribeSpotFleetInstances",
      "ec2:DescribeSpotFleetRequests",
      "ec2:DescribeSpotPriceHistory",
      "ec2:DescribeVpcClassicLink",
      "ec2:DescribeLaunchTemplateVersions",
      "ec2:RequestSpotFleet",
      "autoscaling:DescribeAccountLimits",
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeAutoScalingInstances",
      "eks:DescribeCluster",
      "ecs:DescribeClusters",
      "ecs:DescribeContainerInstances",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListClusters",
      "ecs:ListContainerInstances",
      "ecs:ListTaskDefinitionFamilies",
      "ecs:ListTaskDefinitions",
      "ecs:ListTasks",
      "ecs:DeregisterTaskDefinition",
      "ecs:TagResource",
      "ecs:ListAccountSettings",
      "logs:DescribeLogGroups",
      "iam:GetInstanceProfile",
      "iam:GetRole",
      "sqs:*",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/batch/${var.project}*",
      "arn:aws:logs:*:*:log-group:/aws/batch/job*",
    ]
  }

  statement {
    actions = [
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/batch/${var.project}*:log-stream:*",
      "arn:aws:logs:*:*:log-group:/aws/batch/job*",
    ]
  }

  statement {
    actions = [ "autoscaling:CreateOrUpdateTags"]
    resources = ["*"]
  }

  statement {
    actions = ["iam:PassRole" ]
    resources = ["*"]
  }

  statement {
    actions = ["ec2:CreateLaunchTemplate"]
    resources = ["*"]
  }

  statement {
    actions = [
      "autoscaling:CreateLaunchConfiguration",
      "autoscaling:DeleteLaunchConfiguration",
    ]
    resources = ["arn:aws:autoscaling:*:*:launchConfiguration:*:launchConfigurationName/*"]
  }

  statement {
    actions = [
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:UpdateAutoScalingGroup",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:SuspendProcesses",
      "autoscaling:PutNotificationConfiguration",
      "autoscaling:TerminateInstanceInAutoScalingGroup"
    ]
    resources = ["arn:aws:autoscaling:*:*:autoScalingGroup:*:autoScalingGroupName/*"]
  }

  statement {
    actions = [
      "ecs:DeleteCluster",
      "ecs:DeregisterContainerInstance",
      "ecs:RunTask",
      "ecs:StartTask",
      "ecs:StopTask",
    ]
    resources = ["arn:aws:ecs:*:*:cluster/*"]
  }

  statement {
    actions = [
      "ecs:RunTask",
      "ecs:StartTask",
      "ecs:StopTask"
    ]
    resources = ["arn:aws:ecs:*:*:task-definition/*"]
  }

  statement {
    actions = ["ecs:StopTask"]
    resources = ["arn:aws:ecs:*:*:task/*/*"]
  }

  statement {
    actions = [
      "ecs:CreateCluster",
      "ecs:RegisterTaskDefinition"
    ]
    resources = ["*"]
  }

  statement {
    actions = ["ec2:RunInstances"]
    resources = [
      "arn:aws:ec2:*::image/*",
      "arn:aws:ec2:*::snapshot/*",
      "arn:aws:ec2:*:*:subnet/*",
      "arn:aws:ec2:*:*:network-interface/*",
      "arn:aws:ec2:*:*:security-group/*",
      "arn:aws:ec2:*:*:volume/*",
      "arn:aws:ec2:*:*:key-pair/*",
      "arn:aws:ec2:*:*:launch-template/*",
      "arn:aws:ec2:*:*:placement-group/*",
      "arn:aws:ec2:*:*:capacity-reservation/*",
      "arn:aws:ec2:*:*:elastic-gpu/*",
      "arn:aws:elastic-inference:*:*:elastic-inference-accelerator/*",
      "arn:aws:resource-groups:*:*:group/*"
    ]
  }

  statement {
    actions = ["ec2:RunInstances"]
    resources = ["arn:aws:ec2:*:*:instance/*"]
  }

  statement {
    actions = ["ec2:CreateTags"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "service" {
  name        = "${var.project}_batch-service"
  path        = "/batch/"
  description = "IAM service role for AWS Batch"

  assume_role_policy    = data.aws_iam_policy_document.service-assumption.json

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_policy" "service-execution" {
  name   = "${var.project}-service-execution-policy"
  path   = "/batch/"
  policy = data.aws_iam_policy_document.service-execution.json
}

resource "aws_iam_role_policy_attachment" "service-execution" {
  role       = aws_iam_role.service.name
  policy_arn = aws_iam_policy.service-execution.arn
}
#######################################################################
# Compute Environment Batch Service Role                         END  #
#######################################################################


#######################################################################
# Fargate Container Job Role                                   BEGIN  #
#                                                                     #
#  Role inherited by containers spun up by AWS batch                  #
#######################################################################
data "aws_iam_policy_document" "job-assumption" {
  statement {
    sid     = "ECSBatchJobAssuptionPolicy"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "job" {
  name        = "${var.project}_fargate-job"
  path        = "/batch/"
  description = "IAM service role for AWS Batch"

  assume_role_policy    = data.aws_iam_policy_document.job-assumption.json
  force_detach_policies = true

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "job-execution" {
  statement {
    sid     = "EC2BatchJobExecutionPolicyRDS"
    actions = [
      "rds-db:connect",
    ]
    resources = ["arn:aws:rds-db:${data.aws_region.current_region.name}:${data.aws_caller_identity.current_identity.id}:dbuser:*/${var.project}"]
  }

  # (Alex) Give batch permission to query secrets
  statement {
    sid     = "EC2BatchJobExecutionPolicySecretsManager"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = ["*"]
  }

  # (Alex) Give batch permission to create and add log events 
  statement {
    sid     = "EC2BatchJobExecutionPolicyLogs"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "EC2BatchJobExecutionPolicySQS"
    actions = [
      "sqs:SendMessage",
      "sqs:ReceiveMessage",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueues",
      "sqs:ListQueueTags",
      "sqs:TagQueue",
      "sqs:DeleteMessage",
    ]
    resources = ["*"]
  }
  # (Alex) Removed duplicate sid here
  statement {
    sid     = "EC2BatchJobExecutionPolicyS3"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:ListBucket",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:DeleteBucket",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "EC2BatchJobExecutionPolicyBatch"
    actions = [
      "batch:ListJobs",
      "batch:DescribeJobQueues",
      "batch:DescribeJobs",
      "batch:CancelJob",
      "batch:SubmitJob",
      "batch:TerminateJob"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "job-execution" {
  name   = "${var.project}-job-execution-policy"
  path   = "/batch/"
  policy = data.aws_iam_policy_document.job-execution.json
}

resource "aws_iam_role_policy_attachment" "job-execution" {
  role       = aws_iam_role.job.name
  policy_arn = aws_iam_policy.job-execution.arn
}
#######################################################################
# Fargate Container Job Role                                     END  #
#######################################################################


#######################################################################
# Eventbridge Execution Role                                   BEGIN  #
#                                                                     #
#   Role granted to EventBridge to allow for execution of Batch jobs  # 
#######################################################################
data "aws_iam_policy_document" "eventbridge-assumption" {
  statement {
    sid     = "EventBridgeBatchJobAssuptionPolicy"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eventbridge" {
  name                = "${var.project}_eventbridge-execution"
  path                = "/batch/"
  description         = "IAM service role for Eventbridge"
  assume_role_policy  = data.aws_iam_policy_document.eventbridge-assumption.json

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "eventbridge" {
  statement {
    sid     = "ECSBatchEventbridgePolicy"
    actions = [
      "batch:*",
      "rds:StopDBInstance",
      "rds:StartDBInstance",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "eventbridge" {
  name   = "${var.project}-eventbridge-execution-policy"
  path   = "/batch/"
  policy = data.aws_iam_policy_document.eventbridge.json
}

resource "aws_iam_role_policy_attachment" "eventbridge" {
  role       = aws_iam_role.eventbridge.name
  policy_arn = aws_iam_policy.eventbridge.arn
}
#######################################################################
# Eventbridge Execution Role                                     END  #
#######################################################################


#######################################################################
# RDS Monitoring Role                                          BEGIN  #
#                                                                     #
#   Role granted to EventBridge to allow for execution of Batch jobs  # 
#######################################################################
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
  path        = "/batch/"
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
  path   = "/batch/"
  policy = data.aws_iam_policy_document.rds_monitoring.json
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  role       = aws_iam_role.rds_monitoring.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}
#######################################################################
# RDS Monitoring Role                                            END  #
#######################################################################


output "fargate_service_role_arn" {
  value = aws_iam_role.service.arn
}

output "fargate_execution_role_arn" {
  value = aws_iam_role.ecs_task_execution_role.arn
}

output "fargate_job_role_arn" {
  value = aws_iam_role.job.arn
}

output "eventbridge_role_arn" {
  value = aws_iam_role.eventbridge.arn
}

output "rds_monitoring_role_arn" {
  value = aws_iam_role.rds_monitoring.arn
}
