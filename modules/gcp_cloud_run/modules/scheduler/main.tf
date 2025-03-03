variable job {}
variable project {}

data "google_project" "this" {}

data "google_cloud_run_v2_job" "parent" { 
  name      =  var.job.name
  location  = "us-central1"
}

data "google_service_account" "cloud_run_invoker" {
  account_id  = "carleski-test"
}

resource "random_pet" "this" {
  prefix = var.job.name
}

locals { 
  override_body = <<EOT
  { 
    "overrides": {
      "containerOverrides": [
        {
          "env": replace_env
        }
      ]
    }
  }
EOT
}
resource "google_cloud_scheduler_job" "job" {
  for_each = { for index, instance in var.job.scheduling.instances : md5(instance.gcp_schedule) => instance }

  provider          = google
  name              = "${var.project}_${random_pet.this.id}"
  schedule          = "${each.value.gcp_schedule}"
  attempt_deadline  = "320s"
  region            = "us-central1"
  project           = data.google_project.this.project_id

  retry_config {
    retry_count = 3
  }

  http_target {
    http_method = "POST"
    uri         = "https://${data.google_cloud_run_v2_job.parent.location}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${data.google_project.this.number}/jobs/${data.google_cloud_run_v2_job.parent.name}:run"
    headers     = {
      "Content-Type" = "application/json"
      "User-Agent" = "Google-Cloud-Scheduler"
    }
    body        = base64encode("{\"overrides\":{\"containerOverrides\":[{\"env\":${lower(jsonencode(each.value.environment))}}]}}")

    # oauth_token is reuired when submitting jobs to Cloud Run
    oauth_token {
      scope                 = "https://www.googleapis.com/auth/cloud-platform"
      service_account_email = data.google_service_account.cloud_run_invoker.email
    }
  }
}
