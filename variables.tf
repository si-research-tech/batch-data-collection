# DO NOT DEFINE VARIABLES IN THIS FILE!
# This file is only for declaring *which* variables this terraform module uses.
# Project-specific variable declarations should be made in a new file called
# terraform.tfvars

variable "shortcode" {
  type    = string
  default = null
  
  validation {
    condition     = can(regex("^[0-9]{6}$", var.shortcode)) || var.shortcode == null
    error_message = "Shortcode must be a six-digit numeric string"
  }
}

variable "project" {
  type    = string

  validation {
    condition     = can(regex("^[a-z]+$", var.project))
    error_message = "Project must be all lower case with no special characters. (Sorry, Amazon can't make up their mind on conventions.)"
  }
  # TODO: We might need to enforce this to be lowercase single-string
  # COMMENT: That blows.
}

variable "components" {
  type = object({
    batch = bool
    cloud_run = bool
    lambda = bool
    rds = bool
    s3  = bool
    sqs = bool
  })

  default = {
    batch = true
    cloud_run = false
    lambda = false
    rds = false
    s3 = false
    sqs = false
  }
}

variable "batch" {
  type      = object({
    fair_share_policy   = object({
      compute_reservation = number
      share_decay_seconds = number
    })
    share_distributions  = list(object({
      share_identifier  = string
      weight_factor     = number
    }))
    fargate_config      = object({
      compute_environment = object({
        use_spot  = bool
        max_vcpus = number
      })
    })
  })

  default   = {
    fair_share_policy = {
      compute_reservation = 1
      share_decay_seconds = 300
    }
    share_distributions = [
      {
        share_identifier  = "high"
        weight_factor     = 0.5
      },
      {
        share_identifier  = "medium"
        weight_factor     = 1
      },
      {
        share_identifier  = "low"
        weight_factor     = 2
      }
    ]
    fargate_config  = {
      compute_environment = {
        use_spot  = false
        max_vcpus = 32
      }
    }
  }
}

variable "cloud_run" {
  type = object({})
  default = {}
}

variable "rds" {
  type      = object({
    max_storage         = number

     # Using awscli, list engines/versions with `aws rds describe-db-engine-versions | jq '.[][] | "Engine=\(.Engine) Version=\(.EngineVersion)"'`
     # Leaving engine blank will use default
    engine              = string
    engine_version      = string

    # Valid instance sizes are at: https://aws.amazon.com/rds/instance-types/
    instance_class      = string
    publicly_accessible = bool 
    campus_proxy_ip     = string
  })

  default   = {
    max_storage         = 1000
    engine              = "mysql"
    engine_version      = "8.0.36"
    instance_class      = "db.t4g.micro"
    campus_proxy_ip     = null
    publicly_accessible = false
  }

  validation {
    condition     = can(cidrnetmask(var.rds.campus_proxy_ip)) || var.rds.campus_proxy_ip == null
    error_message = "Campus proxy IP must be a valid IPv4 CIDR block address."
  }

  validation {
    condition     = (can(cidrnetmask(var.rds.campus_proxy_ip)) && var.rds.publicly_accessible == false) || var.rds.campus_proxy_ip == null
    error_message = "If using a proxy to contact RDS, this must be set to true."
  }
}

variable "sqs" {
  type    = object({
    max_recieve_attempts  = number
    max_retention_seconds = number
  })

  default = {
    max_recieve_attempts  = 5
    max_retention_seconds = 72000
  }
}


variable "s3" {
  type    = object({
    cloudfront = bool
    versioning = string
  })

  default = {
    cloudfront = false
    versioning = "Disabled"
  }

  validation {
    condition     = contains(["Disabled", "Enabled", "Suspended"], var.s3.versioning)
    error_message = "Versioning for S3 must be set to Disabled, Enabled, or Suspended"
  }
}

variable "lambda" {
  type      = object({
    functions = list(object({
      name = string               # This name should match the directory name under /modules/lambda/data to package your function.
      runtime = string            # Valid runtimes are listed at: https://docs.aws.amazon.com/lambda/latest/dg/lambda-runtimes.html
      entrypoint = string
      variables = list(object({
        name  = string
        value = any
      }))
    }))
  })

  default   = {
    functions = []
  }
}

variable "user_variables" {
  type  = map(any)
}

variable "jobs" {
  type  = list(object({
    name              = string
    image_uri         = string
    vcpus             = string      # See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-tasks-services.html#fargate-tasks-size for valid combos
    memory            = string      # See https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-tasks-services.html#fargate-tasks-size for valid combos
    assign_public_ip  = bool
    runtime_platform  = string
    environment       = list(object({
      name  = string
      value = any
    }))
    scheduling        = object({
      enabled           = bool
      flex_minutes      = number
      instances         = list(object({
        environment = list(object({
          Name  = string
          Value = any
        })),
        aws_schedule          = string, # See https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-cron-expressions.html for valid expression examples
        gcp_schedule          = string, # See https://cloud.google.com/scheduler/docs/configuring/cron-job-schedules
        share_identifier  = string,
      }))
    })
  }))

  validation {
    condition     = alltrue([
     for job in var.jobs : job.scheduling.enabled && length(job.scheduling.instances) > 0
    ])
    error_message = "Scheduled jobs must have at least one run instance defined."
  }

  validation {
    condition     = alltrue([
      for job in var.jobs : can(regex("^(X86_64|ARM64)$", job.runtime_platform))
    ])
    error_message = "Runtime platform must be set to either `X86_64` or `ARM64`."
  }

  validation {
    condition     = alltrue([
      for job in var.jobs : can(regex("^(low|medium|high)$", join(" ", flatten([for instance in job.scheduling.instances : instance.share_identifier]))))
    ])
    error_message = "Share identifiers must be set to `low`, `medium`, or `high`."
  }
}
