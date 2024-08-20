# Overview
This terraform module utilizes Amazon Batch, ECS, RDS, and other services to create a robust web scraping solution. Scraping containers are launched on ECS Fargate and managed by AWS Batch, while scraped data is written to a centralized database, S3, or other storage solution.


# Getting Started with AWS
If you do not already have the AWS CLI configured, follow the steps in our documentation to get it configured:
https://umsi.atlassian.net/l/cp/VdGfd6Bu


# Creating the Job Container(s)
Your job containers are the most important part of the data collection process. These containers will be run automatically at times you specify with any input data you provide to collec the data you're interested in. Environment variables can be provided at both the Batch Job and Eventbridge Task level to provide flexibility. This module optionally creates an Elastic Container Registry for you to push your image to, which can then be referenced in your job definition. (see below) This module also allows you to specify images in other registries should you so choose. 


# Defining Your Jobs
Job definitions are the heart of this module, and specify what image runs at what time with what data pre-loaded into it. You may have multiple jobs with multiple schedules with varying starting inputs, or a single job that runs without special configuration; however, at least one job definition is always needed.

VCPU and Memory combinations must be compliant with Amazon's documentation found here:
https://docs.aws.amazon.com/AmazonECS/latest/developerguide/fargate-tasks-services.html#fargate-tasks-size

An example template for job definitions is as follows. Items encapsulated in [] are mutable.

```
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
  ]
  scheduling        = {
    enable            = [ bool ]
    schedule          = [ cron expression ]
    share_identifier  = [ low | medium | high ]
    flex_minutes      = [ number ]
    environment       = [{}]
}
```

# Real-World Application

## Use Case
In the example architecture below, the team was looking to collect data from multiple web-based sources on the sales of electric vehicles. After writing the Python code to scrape a single source using values from environment variables, the image, along with the configuration of this module, was able to be utilized to scrape thousands of pages per day to retrieve the necessary data. 

## Architecture 
![Batch Data Collection Example Architecture](./assets/images/scrape_example.png)