# Terraform for Module 07
##############################################################################
# You will need to fill in the blank values using the values in terraform.tfvars
# or using the links to the documentation. You can also make use of the auto-complete
# in VSCode
# Reference your code in Module 04 to fill out the values
# This is the same exercise but converting from Bash to HCL
##############################################################################
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpc
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/vpcs
##############################################################################
# Configure AWS Provider
provider "aws" {
  region = "us-east-2"
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# Get subnets in the availability zones
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
  
  filter {
    name   = "availability-zone"
    values = var.az
  }
}

# Create S3 bucket for raw images
resource "aws_s3_bucket" "raw" {
  bucket = var.raw-s3-bucket
  
  tags = {
    Name = var.module-tag
  }
}

# Create S3 bucket for finished images
resource "aws_s3_bucket" "finished" {
  bucket = var.finished-s3-bucket
  
  tags = {
    Name = var.module-tag
  }
}

# Make raw bucket public
resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Make finished bucket public
resource "aws_s3_bucket_public_access_block" "finished" {
  bucket = aws_s3_bucket.finished.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket policy for raw bucket
resource "aws_s3_bucket_policy" "raw" {
  bucket = aws_s3_bucket.raw.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.raw.arn}/*"
      }
    ]
  })
  
  depends_on = [aws_s3_bucket_public_access_block.raw]
}

# Bucket policy for finished bucket
resource "aws_s3_bucket_policy" "finished" {
  bucket = aws_s3_bucket.finished.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.finished.arn}/*"
      }
    ]
  })
  
  depends_on = [aws_s3_bucket_public_access_block.finished]
}

# Create Launch Template
resource "aws_launch_template" "app" {
  name          = var.lt-name
  image_id      = var.imageid
  instance_type = var.instance-type
  key_name      = var.key-name
  
  vpc_security_group_ids = var.vpc_security_group_ids
  
  user_data = filebase64(var.install-env-file)
  
  tag_specifications {
    resource_type = "instance"
    
    tags = {
      Name = var.module-tag
    }
  }
  
  tags = {
    Name = var.module-tag
  }
}

# Create Target Group
resource "aws_lb_target_group" "app" {
  name     = var.tg-name
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  
  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 2
  }
  
  tags = {
    Name = var.module-tag
  }
}

# Create Application Load Balancer
resource "aws_lb" "app" {
  name               = var.elb-name
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.vpc_security_group_ids
  subnets            = data.aws_subnets.default.ids
  
  tags = {
    Name = var.module-tag
  }
}

# Create Load Balancer Listener
resource "aws_lb_listener" "app" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# Create Auto Scaling Group
resource "aws_autoscaling_group" "app" {
  name                = var.asg-name
  desired_capacity    = var.desired
  max_size            = var.max
  min_size            = var.min
  target_group_arns   = [aws_lb_target_group.app.arn]
  vpc_zone_identifier = data.aws_subnets.default.ids
  health_check_type   = "ELB"
  
  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }
  
  tag {
    key                 = "Name"
    value               = var.module-tag
    propagate_at_launch = true
  }
}

# Outputs
output "load_balancer_dns" {
  description = "DNS name of the load balancer"
  value       = aws_lb.app.dns_name
}

output "raw_s3_bucket" {
  description = "Name of the raw S3 bucket"
  value       = aws_s3_bucket.raw.bucket
}

output "finished_s3_bucket" {
  description = "Name of the finished S3 bucket"
  value       = aws_s3_bucket.finished.bucket
}