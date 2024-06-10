# DO DEFINE VARIABLES IN THIS FILE!
# This file is only for declaring *which* variables this terraform module uses.
# Project-specific variable declarations should be made in a new file called
# terraform.tfvars

variable "shortcode" {
  type    = string

  validation {
    condition     = can(regex("^[0-9]{6}$", var.shortcode))
    error_message = "Shortcode must be a six-digit numeric string"
  }
}

variable "project" {
  type    = string
}

variable "fargate" {
  type      = object({
    compute_environment = object({
      use_spot  = bool
      max_vcpus = number
    })
  })

  default   = {
    compute_environment = object({
      use_spot  = false
      max_vcpus = 64
    })
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
  })

  default   = {
    fair_share_policy = object({
      compute_reservation = 0
      share_decay_seconds = 300
    })
    share_distributions = [
      {
        share_identifier  = "high"
        weight_factor     = 2
      },
      {
        share_identifier  = "medium"
        weight_factor     = 2
      },
      {
        share_identifier  = "low"
        weight_factor     = 2
      }
    ]
  }
}

variable "rds" {
  type      = object({
    create      = bool
    max_storage = number
  })

  default   = {
    create      = false
    max_storage = 10 
  }
}

variable "s3" {
  type      = object({
    create  = bool
  })

  default   = {
    create  = false
  }
}

variable "sqs" {
  type      = object({
    create                    = bool
    max_sqs_recieve_attempts  = number
    max_sqs_retention_seconds = number
  })

  default   = {
    create                     = false
    max_sqs_recieve_attempts  = 5
    max_sqs_retention_seconds = 72000
  }
}

variable "lambda" {
  type      = object({
    create    = bool
    functions = map(any)
  })

  default   = {
    create    = false
    functions = {}
  }
}

variable "user_variables" {
  type  = map(any)
}

variable "jobs" {
  type  = list(object({
    name              = string
    image_uri         = string
    vcpus             = number
    memory           = number
    assign_public_ip  = bool
    runtime_platform  = bool
    environment       = list(object({
      name  = string
      value = any
    }))
    scheduling        = object({
      enable            = bool
      schedule          = string
      share_identifier  = string
      flex_minutes      = number
    })
  }))

  validation {
    condition     = length(var.jobs) > 0
    error_message = "You must define jobs in your variables file. See variables.tf for example structure."
  }

  validation {
    condition     = regex("^(x86_64|ARM64)$", job.runtime_platform)
    error_message = "Runtime platform must be set to either `x86_64` or `ARM64`."
  }

  validation {
    condition     = alltrue([
      for job in var.jobs : regex("^[0-9*?]{1,2}\\w[0-9*?]{1,2}\\s[0-9*?]{1,2}\\s[0-9*?]{1,2}\\s[0-9*?]{1,2}\\s[0-9*?]{1,2}\\s?$", job.scheduling.shedule)
    ])
    error_message = "Schedules must be provided in cron format. Check https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-cron-expressions.html for help."
  }

  validation {
    condition     = alltrue([
      for job in var.jobs : regex("^(low|medium|high)$", job.scheduling.share_identifier)
    ])
    error_message = "Share identifiers must be set to `low`, `medium`, or `high`."
  }
}
