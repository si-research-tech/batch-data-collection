variable job {}
variable project {}

data "google_project" "this" {}

resource "random_pet" "this" {
  prefix = var.job.name
}

resource "google_cloud_scheduler_job" "job" {
  for_each = { for index, instance in var.job.scheduling.instances : md5(instance.schedule) => instance }

  provider          = google
  name              = "${var.project}_${random_pet.this.id}"
  schedule          = "${each.value.schedule}"
  time_zone         = "America/New_York"
  attempt_deadline  = "320s"
  region            = "us-central1"
  project           = data.google_project.this.project_id

  retry_config {
    retry_count = 3
  }

  http_target {
    http_method = "POST"
    uri         = "https://${google_cloud_run_v2_job.default.location}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${data.google_project.this.number}/jobs/${google_cloud_run_v2_job.default.name}:run"
`   body        = base64encode("{\"overrides\": ${jsonencode(each.value.environment)}}")    
    # oauth_token is reuired when submitting jobs to Cloud Run
    oauth_token {
      service_account_email = google_service_account.cloud_run_invoker.email
    }
  }
}
