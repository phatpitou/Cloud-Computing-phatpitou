# Variables for ITMO-544 Final Assessment


variable "elb-name" {
  description = "Name for Elastic Load Balancer"
  type        = string
  default     = "pt-elb"
}

variable "tg-name" {
  description = "Name for Target Group"
  type        = string
  default     = "pt-tg"
}

variable "lt-name" {
  description = "Name for Launch Template"
  type        = string
  default     = "pt-lt"
}

variable "asg-name" {
  description = "Name for Auto Scaling Group"
  type        = string
  default     = "pt-asg"
}

variable "imageid" {
  description = "AMI ID for instances (us-east-1 Amazon Linux 2)"
  type        = string
  default     = "ami-0c02fb55956c7d316" 
}

variable "instance-type" {
  description = "EC2 instance type (must be t2.micro for tests)"
  type        = string
  default     = "t2.micro"
}

variable "key-name" {
  description = "EC2 Key Pair name"
  type        = string
  default     = "coursera-key"  
}

variable "vpc_security_group_ids" {
  description = "Security Group ID (allows HTTP 80)"
  type        = string
  default     = "sg-0b1a68d08a66f0a1b"  
}

variable "install-env-file" {
  description = "Path to user_data script (Nginx install)"
  type        = string
  default     = "install-env.sh"
}

variable "cnt" {
  description = "Desired capacity for ASG (3 for tests)"
  type        = number
  default     = 3
}

variable "ebs-size" {
  description = "Size for additional EBS volumes (15GB)"
  type        = number
  default     = 15
}

variable "dynamodb-table-name" {
  description = "DynamoDB table name"
  type        = string
  default     = "pt-database"
}

variable "module-tag" {
  description = "Common tag for all resources (must be module-final-tag for tests)"
  type        = string
  default     = "module-final-tag"
}

variable "raw-s3" {
  description = "Name for raw images S3 bucket (unique)"
  type        = string
  default     = "pt-raw-images-2402"  
}

variable "finished-s3" {
  description = "Name for finished images S3 bucket (unique)"
  type        = string
  default     = "pt-processed-images-2402"  
}