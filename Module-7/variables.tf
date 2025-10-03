#Types
#The Terraform language uses the following types for its values:

# https://developer.hashicorp.com/terraform/language/expressions/types
# string: a sequence of Unicode characters representing some text, like "hello".
# number: a numeric value. The number type can represent both whole numbers like 15 and fractional values like 6.283185.
# bool: a boolean value, either true or false. bool values can be used in conditional logic.
# list (or tuple): a sequence of values, like ["us-west-1a", "us-west-1c"]. Identify elements in a list with consecutive whole numbers, starting with zero.
# set: a collection of unique values that do not have any secondary identifiers or ordering.
# map (or object): a group of values identified by named labels, like {name = "Mabel", age = 52}.

# Default types are stings, lists, and maps

# AMI and Instance Configuration
variable "imageid" {
  description = "AMI ID for EC2 instances"
  type        = string
}

variable "instance-type" {
  description = "EC2 instance type"
  type        = string
}

variable "key-name" {
  description = "SSH key pair name"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "List of security group IDs"
  type        = list(string)
}

variable "cnt" {
  description = "Number of instances"
  type        = number
}

variable "install-env-file" {
  description = "Path to installation script"
  type        = string
  default     = "./install-env.sh"
}

# Availability Zones
variable "az" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["us-east-2a", "us-east-2b", "us-east-2c"]
}

# Load Balancer and Scaling Configuration
variable "elb-name" {
  description = "Elastic Load Balancer name"
  type        = string
}

variable "tg-name" {
  description = "Target Group name"
  type        = string
}

variable "asg-name" {
  description = "Auto Scaling Group name"
  type        = string
}

variable "lt-name" {
  description = "Launch Template name"
  type        = string
}

# Auto Scaling Group Capacity
variable "min" {
  description = "Minimum instances in ASG"
  type        = number
  default     = 2
}

variable "max" {
  description = "Maximum instances in ASG"
  type        = number
  default     = 5
}

variable "desired" {
  description = "Desired instances in ASG"
  type        = number
  default     = 3
}

# Tags
variable "module-tag" {
  description = "Module identification tag"
  type        = string
}

# S3 Buckets
variable "raw-s3-bucket" {
  description = "S3 bucket for raw images"
  type        = string
}

variable "finished-s3-bucket" {
  description = "S3 bucket for finished images"
  type        = string
}