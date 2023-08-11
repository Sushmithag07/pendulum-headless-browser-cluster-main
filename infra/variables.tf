variable "logging_level" {
  description = "Lambda logging level"
  type        = string
  default     = "ERROR"
}

variable "vpc_id" {
  description = "The vpc in which to create resources. If empty, will attempt to find it."
  type        = string
}

variable "aws_region" {
  description = "Target AWS region"
  type        = string
  default     = "us-west-2"
}

variable "app_name" {
  description = "Service name will be used in naming your resources like log groups, ECS services, etc."
  type        = string
  default     = "hb-ws-tf"
}

variable "container_image" {
  default = {
    "dev"  = "545704012723.dkr.ecr.us-west-2.amazonaws.com/pendulum-headless-browser/chrome"
    "prod" = "099132402094.dkr.ecr.us-west-2.amazonaws.com/pendulum-headless-browser/chrome"
  }
}

variable "container_environment" {
  type    = string
  default = "dev"
}

variable "container_port" {
  type    = number
  default = 3000
}

variable "service_desired_count" {
  description = "Number of tasks running in parallel"
  default     = 2
}

variable "container_cpu" {
  description = "The number of cpu units used by the task"
  default     = 256
}

variable "container_memory" {
  description = "The amount (in MiB) of memory used by the task"
  default     = 512
}

variable "health_check_path" {
  description = "Http path for task health check"
  default     = ${{ secrets.HEALTHCHECKPATH }}
}


variable "cidr" {
  description = "The CIDR block for the VPC."
  default     = "10.0.0.0/16"
}

variable "security_group_ids" {
  description = "Security groups for ALB"
}

variable "private_subnets" {
  description = "a list of CIDRs for private subnets in your VPC, must be set if the cidr variable is defined, needs to have as many elements as there are availability zones"
  default     = ["10.0.0.0/20", "10.0.32.0/20"]
}

variable "public_subnets" {
  description = "a list of CIDRs for public subnets in your VPC, must be set if the cidr variable is defined, needs to have as many elements as there are availability zones"
  default     = ["10.0.16.0/20", "10.0.48.0/20"]
}

variable "availability_zones" {
  description = "a comma-separated list of availability zones, defaults to all AZ of the region, if set to something other than the defaults, both private_subnets and public_subnets have to be defined as well"
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

variable "ecs_services" {
  description = "List of all the service names to be created"
  default = {
    "host_name" : ["tiktok.ingestion", "tiktok.discovery", "vk.ingestion"],
    "service_name" : ["tiktok-ing", "tiktok-dis", "vk-ing"]
  }
}

variable "ecs_services_rule_priority" {
  type        = list(string)
  description = "List of all the service names to be created"
  default     = ["100", "101", "102"]
}
