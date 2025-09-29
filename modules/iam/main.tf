variable project {}
variable components {}

data "aws_partition" "current_partition" {}
data "aws_region" "current_region" {}
data "aws_caller_identity" "current_identity" {}


###############################################################################
# S3 Bucket Base Policy Document                                       BEGIN  #
#                                                                             #
#    Establish a policy document data source to append additional             #
#    statments to later in this module                                        #
###############################################################################
data "aws_iam_policy_document" "s3_bucket_base" {}

###############################################################################
# S3 Bucket Base Policy Document                                         END  #
###############################################################################

###############################################################################
# ECS Task Execution Role                                              BEGIN  #
#                                                                             #
#  The execution role grants the Amazon ECS container and AWS Fargate         #
#  agents permission to make AWS API calls on your behalf.                    #
###############################################################################
data "aws_iam_policy_document" "ecs_task_execution_assumption_policy" {
  statement {
    sid = "AllowECSServiceAssumption"
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
  name               = "${var.project}_ecs-task-execution"
  path               = "/${var.project}/batch/"
  description        = "iam role to allow ecs container execution and associated"

  assume_role_policy = data.aws_iam_policy_document.ecs_task_execution_assumption_policy.json

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}
###############################################################################
# ECS Task Execution Role                                                END  #
###############################################################################


###############################################################################
# Compute Environment Batch Service Role                               BEGIN  #
#                                                                             #
#  Makes calls to other AWS services on your behalf to manage the             #
#  resources that you use with AWS Batch.                                     #
###############################################################################
data "aws_iam_policy_document" "batch-service-assumption" {
  statement {
    sid     = "ECSBatchServiceAssumptionPolicy"
    actions = [ "sts:AssumeRole" ]

    principals {
      type        = "Service"
      identifiers = ["batch.${data.aws_partition.current_partition.dns_suffix}"]
    }
  }
}

resource "aws_iam_role" "batch-service" {
  name        = "${var.project}_batch-service"
  path        = "/${var.project}/batch/"
  description = "IAM service role for AWS Batch"

  assume_role_policy    = data.aws_iam_policy_document.batch-service-assumption.json

  lifecycle {
    create_before_destroy = true
  }
}

data "aws_iam_policy_document" "batch-service" {
  statement {
    actions = [
      "autoscaling:CreateOrUpdateTags",
      "ec2:CreateTags",
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
      "ecs:CreateCluster",
      "ecs:DescribeClusters",
      "ecs:DescribeContainerInstances",
      "ecs:DescribeTaskDefinition",
      "ecs:DescribeTasks",
      "ecs:ListClusters",
      "ecs:ListContainerInstances",
      "ecs:ListTaskDefinitionFamilies",
      "ecs:ListTaskDefinitions",
      "ecs:ListTasks",
      "ecs:RegisterTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "ecs:TagResource",
      "ecs:ListAccountSettings",
      "logs:DescribeLogGroups",
      "iam:GetInstanceProfile",
      "iam:GetRole",
      "iam:PassRole",
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/${var.project}*",
      "arn:aws:logs:*:*:log-group:/aws/${var.project}*",
      "arn:aws:logs:*:*:log-group:/aws/batch/${var.project}*",
      "arn:aws:logs:*:*:log-group:/aws/batch/job*",
    ]
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
}

resource "aws_iam_policy" "batch-service" {
  name               = "${var.project}_batch-service-execution"
  path               = "/${var.project}/batch/"
  description        = "IAM Role to allow Batch to manage AWS resources"
  policy             = data.aws_iam_policy_document.batch-service.json
}

resource "aws_iam_role_policy_attachment" "batch-service-execution" {
  role       = aws_iam_role.batch-service.name
  policy_arn = aws_iam_policy.batch-service.arn
}

resource "aws_iam_role_policy_attachment" "batch-ecs-task-execution" {
  role       = aws_iam_role.batch-service.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

###############################################################################
# Compute Environment Batch Service Role                                 END  #
###############################################################################

###############################################################################
# Project Interop Policy                                               BEGIN  #
#                                                                             #
#  Allow interaction between services in this project                         #
###############################################################################

locals {
  optional_permissions = [
    {
      service = "lambda"
      enabled = var.components.lambda,
      permissions = [
        "lambda:CreateFunction",
        "lambda:DeleteFunction",
        "lambda:GetFunction",
        "lambda:GetFunctionConfiguration",
        "lambda:InvokeFunction",
        "lambda:InvokeFunctionUrl",
        "lambda:ListFunctions",
        "lambda:ListTags",
        "lambda:TagResource",
        "lambda:UpdateFunctionCode",
      ]
      resources = ["*"]
    },
    {
      service = "rds"
      enabled = var.components.rds,
      permissions = [
        "rds-db:connect"
      ]
      resources = ["arn:aws:rds-db:${data.aws_region.current_region.name}:${data.aws_caller_identity.current_identity.id}:dbuser:*/${var.project}"]
    },
    {
      service = "s3"
      enabled = var.components.s3,
      permissions = [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:ListBucket",
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
        "s3:DeleteBucket",
      ]
      resources = ["*"]
    },
    {
      service     = "sqs"
      enabled     = var.components.sqs,
      permissions = [
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
    },
  ]
}

data "aws_iam_policy_document" "job-execution" {

  statement {
    sid     = "EC2BatchJobExecutionPolicySecretsManager"
    actions = [
      "secretsmanager:GetSecretValue",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "EC2BatchJobExecutionPolicyLogs"
    actions = [
      "logs:PutLogEvents",
      "logs:CreateLogStream",
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
  
  dynamic "statement" {
    for_each = [ for permission in local.optional_permissions : permission if permission.enabled ]
    
    content {
      sid = "ProjectInterop${statement.value.service}"
      actions = statement.value.permissions
      resources = statement.value.resources
    }
  }

}

resource "aws_iam_policy" "project-interop" {
  name   = "${var.project}-job-execution-policy"
  path   = "/${var.project}/"
  policy = data.aws_iam_policy_document.job-execution.json
}
###############################################################################
# Project Interop Policy                                                 END  #
###############################################################################

###############################################################################
# AWS Batch Task Role                                                  BEGIN  #
#                                                                             #
#  Role inherited by containers spun up by AWS batch                          #
###############################################################################

data "aws_iam_policy_document" "batch-task-assumption" {
  statement {
    sid     = "ECSBatchTaskAssuptionPolicy"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "batch-task" {
  name        = "${var.project}_batch-task"
  path        = "/${var.project}/batch/"
  description = "IAM role for AWS Batch Tasks"

  assume_role_policy    = data.aws_iam_policy_document.batch-task-assumption.json
  force_detach_policies = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "batch-task-execution" {
  role       = aws_iam_role.batch-task.name
  policy_arn = aws_iam_policy.project-interop.arn
}
###############################################################################
# AWS Batch Task Role                                                    END  #
###############################################################################

###############################################################################
# Lambda Execution Role                                                BEGIN  #
#                                                                             #
#  Role assumed by lambda functions created by this module                    #
###############################################################################

data "aws_iam_policy_document" "lambda-assumption" {
  statement {
    sid     = "LambdaExecutionAssumptioonPolicy"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda-job" {
  name        = "${var.project}_lambda-execution"
  path        = "/${var.project}/lambda/"
  description = "IAM execution role for AWS Lambda"

  assume_role_policy    = data.aws_iam_policy_document.lambda-assumption.json
  force_detach_policies = true

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "lambda-execution" {
  role       = aws_iam_role.lambda-job.name
  policy_arn = aws_iam_policy.project-interop.arn
}
###############################################################################
# Lambda Execution Role                                                 END  #
###############################################################################

###############################################################################
# Eventbridge Execution Role                                           BEGIN  #
#                                                                             #
#   Role granted to EventBridge to allow for execution of Batch jobs          # 
###############################################################################
data "aws_iam_policy_document" "eventbridge-assumption" {
  statement {
    sid     = "EventBridgeBatchAssuptionPolicy"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eventbridge" {
  name                = "${var.project}_eventbridge-batch-execution"
  path                = "/${var.project}/batch/"
  description         = "IAM role for Eventbridge to allow Batch and RDS API operations"
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
  path   = "/${var.project}/batch/"
  policy = data.aws_iam_policy_document.eventbridge.json
}

resource "aws_iam_role_policy_attachment" "eventbridge" {
  role       = aws_iam_role.eventbridge.name
  policy_arn = aws_iam_policy.eventbridge.arn
}
###############################################################################
# Eventbridge Execution Role                                             END  #
###############################################################################


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
