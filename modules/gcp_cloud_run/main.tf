variable project {}
variable jobs {}
variable cloud_run_config {}

data "google_project" "this" {}

# Define a Google Service Account for this project (module required)
resource "google_service_account" "cloud_run_invoker" {
  account_id    = var.project
  display_name  = var.project
}

data "google_iam_policy" "cloud_run_invoker" {
  binding {
    role = "roles/run.invoker"

    members = [
      "serviceAccount": google_service_account.cloud_run_invoker.email
    ]
  }
}

resrouce "google_service_account_iam_policy" "invoker_policy" {
  service_account_id  = google_service_account.cloud_run_invoker.name
  policy_data         = data.google_iam_policy.cloud_run_invoker.policy_data
}

# Authorize CloudScheduler API for this project
resource "google_project_service" "cloudscheduler_api" {
  service = "cloudscheduler.googleapis.com"
  disable_on_destroy = false #TODO: Come back and think about this https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service#disable_on_destroy-1
}

# Define cloud run job
resource "google_cloud_run_v2_job" "default" {
  name     = "cloudrun-job"
  location = "us-central1"
  deletion_protection = false

  template {
    template {
      containers {
        image = "us-docker.pkg.dev/cloudrun/container/job"
        resources {
          cpu = "2"
          memory = "1024Mi"
        }
      }
    }
  }
}


# Define scheduling
resource "google_cloud_scheduler_job" "job" {
  provider         = google-beta
  name             = "schedule-job"
  description      = "test http job"
  schedule         = "*/8 * * * *"
  attempt_deadline = "320s"
  region           = "us-central1"
  project          = data.google_project.this.project_id

  retry_config {
    retry_count = 3
  }

  http_target {
    http_method = "POST"
    uri         = "https://${google_cloud_run_v2_job.default.location}-run.googleapis.com/apis/run.googleapis.com/v1/namespaces/${data.google_project.project.number}/jobs/${google_cloud_run_v2_job.default.name}:run"

    # oauth_token is reuired when submitting jobs to Cloud Run
    oauth_token {
      service_account_email = google_service_account.cloud_run_invoker.email
    }
  }

  depends_on = [
    resource.google_project_service.cloudscheduler_api,
    resource.google_cloud_run_v2_job.default,
  ]
}
