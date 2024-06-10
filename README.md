# Function
This terraform module utilizes Amazon Batch, ECS, RDS, and other services to create a robust web scraping solution. Scraping containers are launched on ECS Fargate and managed by Batch, while scraped data is written to a centralized database. 

# Batch Job Definitions

VCPU and Memory combos must be compliant with documentation here: 
https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-tasks-services.html#fargate-tasks-size

Template for job definitions is as follows. Items encapsulated in [] are mutable.

{
  name              = [ job-name ]
  image_uri         = [ identity/image-name:version ]
  vcpus             = [ 1 ]
  memory            = [ 1024 ]
  assign_public_ip  = [ bool ]
  runtime_platform  = [ X86_64 | ARM64 ]
  environment       = [
    {
      name  = [ name_x] 
      value = [ value_x ]
    },
    {
      name  = [ name_y ]
      value = [ value_y ]
    }
  }
  scheduling        = {
    enable            = [ bool ]
    schedule          = [ cron expression ]
    share_identifier  = [ low | medium | high ]
    flex_minutes      = [ number ]
  }
}
