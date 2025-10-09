# Terraform for Final Summative Assessment (ITMO-544) - Customized for us-east-1
# Combines Modules 5-7: EC2/ASG/ELB/S3/DynamoDB with Nginx via user data
##############################################################################

# Data sources for VPC, AZs, and subnets (default VPC in us-east-1)
data "aws_vpc" "main" {
  default = true
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_availability_zones" "primary" {
  filter {
    name   = "zone-name"
    values = ["us-east-1a"]
  }
}

data "aws_availability_zones" "secondary" {
  filter {
    name   = "zone-name"
    values = ["us-east-1b"]
  }
}

data "aws_subnets" "subneta" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1a"]
  }
}

data "aws_subnets" "subnetb" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "availability-zone"
    values = ["us-east-1b"]
  }
}

# Elastic Load Balancer (ALB)
resource "aws_lb" "lb" {
  name               = var.elb-name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.vpc_security_group_ids]
  subnets            = [data.aws_subnets.subneta.ids[0], data.aws_subnets.subnetb.ids[0]]

  enable_deletion_protection = false

  tags = {
    Name = var.module-tag
  }
}

output "elb_dns_name" {
  value = aws_lb.lb.dns_name
}

# Target Group
resource "aws_lb_target_group" "tg" {
  depends_on = [aws_lb.lb]
  name     = var.tg-name
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id
  target_type = "instance"

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

# Listener for ALB
resource "aws_lb_listener" "listener" {
  depends_on         = [aws_lb_target_group.tg]
  load_balancer_arn = aws_lb.lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# Launch Template (with user data for Nginx, 2 additional EBS volumes of 15GB each)
resource "aws_launch_template" "lt" {
  name   = var.lt-name
  image_id      = var.imageid
  instance_type = var.instance-type
  key_name      = var.key-name

  monitoring {
    enabled = false
  }

  vpc_security_group_ids = [var.vpc_security_group_ids]

  # Root volume (~8GB default, but specified for clarity)
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size = 8
      volume_type = "gp2"
      delete_on_termination = true
      encrypted = true
    }
  }

  # Additional EBS /dev/sdc (15GB)
  block_device_mappings {
    device_name = "/dev/sdc"
    ebs {
      volume_size = var.ebs-size
      volume_type = "gp2"
      delete_on_termination = true
      encrypted = true
    }
  }

  # Additional EBS /dev/sdd (15GB) - totals 3 EBS per instance
  block_device_mappings {
    device_name = "/dev/sdd"
    ebs {
      volume_size = var.ebs-size
      volume_type = "gp2"
      delete_on_termination = true
      encrypted = true
    }
  }

  user_data = base64encode(file(var.install-env-file))

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = var.module-tag
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group (min=1, max=3, desired=3)
resource "aws_autoscaling_group" "asg" {
  depends_on                = [aws_launch_template.lt, aws_lb_listener.listener]
  name                      = var.asg-name
  vpc_zone_identifier       = [data.aws_subnets.subneta.ids[0], data.aws_subnets.subnetb.ids[0]]
  target_group_arns         = [aws_lb_target_group.tg.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  min_size         = 1
  max_size         = 3
  desired_capacity = var.cnt

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = var.module-tag
    propagate_at_launch = true
  }

  availability_zones = [data.aws_availability_zones.primary.names[0], data.aws_availability_zones.secondary.names[0]]

  lifecycle {
    create_before_destroy = true
  }
}

# ASG Attachment to Target Group
resource "aws_autoscaling_attachment" "asg_attachment" {
  depends_on             = [aws_autoscaling_group.asg]
  autoscaling_group_name = aws_autoscaling_group.asg.id
  alb_target_group_arn   = aws_lb_target_group.tg.arn
}

# S3 Buckets (raw and finished, with public access disabled for security)
resource "aws_s3_bucket" "raw" {
  bucket = var.raw-s3
  force_destroy = true

  tags = {
    Name = var.module-tag
  }
}

resource "aws_s3_bucket_public_access_block" "raw" {
  bucket = aws_s3_bucket.raw.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "finished" {
  bucket = var.finished-s3
  force_destroy = true

  tags = {
    Name = var.module-tag
  }
}

resource "aws_s3_bucket_public_access_block" "finished" {
  bucket = aws_s3_bucket.finished.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# DynamoDB Table (replaces RDS; name=pt-database)
resource "aws_dynamodb_table" "table" {
  name           = var.dynamodb-table-name
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "Email"
  range_key      = "RecordNumber"

  attribute {
    name = "Email"
    type = "S"
  }

  attribute {
    name = "RecordNumber"
    type = "S"
  }

  tags = {
    Name = var.module-tag
  }
}

# Sample Item in DynamoDB (customized with placeholder; update as needed)
resource "aws_dynamodb_table_item" "sample" {
  depends_on = [aws_dynamodb_table.table]
  table_name = aws_dynamodb_table.table.name
  hash_key   = aws_dynamodb_table.table.hash_key
  range_key  = aws_dynamodb_table.table.range_key

  item = jsonencode({
    "Email"        = { "S" = "pt@example.com" }
    "RecordNumber" = { "S" = "pt-sample-uuid-1234" }
    "CustomerName" = { "S" = "PT User" }
    "Phone"        = { "S" = "123-456-7890" }
    "Stat"         = { "N" = "0" }
    "RAWS3URL"     = { "S" = "" }
    "FINISHEDS3URL" = { "S" = "" }
  })
}