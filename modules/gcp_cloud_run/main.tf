variable project {}
variable jobs {}
variable cloud_run_config {}

data "google_project" "this" {}

# Define a Google Service Account for this project (module required)
#resource "google_service_account" "cloud_run_invoker" {
#  account_id    = var.project
#  display_name  = var.project
#}
#
#data "google_iam_policy" "cloud_run_invoker" {
#  binding {
#    role = "roles/run.invoker"
#
#    members = [
#      "serviceAccount:${google_service_account.cloud_run_invoker.email}",
#    ]
#  }
#}
#
#resource "google_service_account_iam_policy" "invoker_policy" {
#  service_account_id  = google_service_account.cloud_run_invoker.name
#  policy_data         = data.google_iam_policy.cloud_run_invoker.policy_data
#}

# Define cloud run job(s)
resource "google_cloud_run_v2_job" "default" {
  for_each = { for index, job in var.jobs : job.name => job }

  name     = "${each.value.name}"
  location = "us-central1"
  deletion_protection = false

  template {
    template {
      timeout = "300s"

      containers {
        image = "${each.value.image_uri}"

        dynamic "env" {
          for_each = each.value.environment
          content {
            name  = "${env.value.name}"
            value = "${env.value.value}"
          }
        }

        resources {
          limits = {
            cpu = "${each.value.vcpus}"
            memory = "${each.value.memory}Mi"
          }
        }
      }
    }
  }
}

module "cloudrun_scheduler" {
  for_each = { for index, job in var.jobs : job.name => job if job.scheduling.enabled }
  source  = "./modules/scheduler"

  project = var.project
  job     = each.value

  depends_on = [
    resource.google_cloud_run_v2_job.default,
  ]
}
