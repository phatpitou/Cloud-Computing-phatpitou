#!/bin/bash
##############################################################################
# Module-05 (extends Module-04)
# Adds Elastic Block Storage and S3 bucket creation with object uploads
##############################################################################

ltconfigfile="./config.json"

if [ $# -lt 20 ]; then
  echo 'You do not have enough variables in your arguments.txt, please ensure you have 20 arguments.'
  echo 'Run: bash ./create-env.sh $(< ~/arguments.txt)'
  exit 1 
elif ! [[ -a $ltconfigfile ]]; then
  echo 'The launch template configuration JSON file does not exist - run: bash ./create-lt-json.sh $(< ~/arguments.txt) first'
  echo "Now exiting the program..."
  exit 1
else
  if [ -a $ltconfigfile ]; then
    echo "Launch template data file: $ltconfigfile exists..." 
  fi

  # Assign arguments to variables for clarity
  image_id=$1
  instance_type=$2
  key_name=$3
  security_group_ids=$4
  count=$5
  user_data_file=$6
  tag_value=$7
  target_group_name=$8
  elb_name=$9
  az1=${10}
  az2=${11}
  launch_template_name=${12}
  asg_name=${13}
  asg_min=${14}
  asg_max=${15}
  asg_desired=${16}
  region=${17}
  ebs_size=${18}
  s3_bucket_one=${19}
  s3_bucket_two=${20}

  echo "Finding and storing default VPCID value..."
  VPCID=$(aws ec2 describe-vpcs --filters "Name=is-default,Values=true" --query "Vpcs[0].VpcId" --output=text --region "$region")
  echo "Default VPC ID: $VPCID"

  echo "Finding and storing the subnet IDs for Availability Zone 1 and 2..."
  SUBNET2A=$(aws ec2 describe-subnets --filters "Name=availability-zone,Values=$az1" "Name=vpc-id,Values=$VPCID" --query 'Subnets[0].SubnetId' --output=text --region "$region")
  SUBNET2B=$(aws ec2 describe-subnets --filters "Name=availability-zone,Values=$az2" "Name=vpc-id,Values=$VPCID" --query 'Subnets[0].SubnetId' --output=text --region "$region")
  echo "Subnet AZ1: $SUBNET2A"
  echo "Subnet AZ2: $SUBNET2B"

  echo "Creating the AutoScalingGroup Launch Template..."
  aws ec2 create-launch-template \
    --launch-template-name "$launch_template_name" \
    --version-description "v1" \
    --launch-template-data file://$ltconfigfile \
    --region "$region"
  echo "Launch Template created..."

  echo "Retrieving the Launch Template ID..."
  LAUNCHTEMPLATEID=$(aws ec2 describe-launch-templates --launch-template-names "$launch_template_name" --query "LaunchTemplates[0].LaunchTemplateId" --output text --region "$region")
  echo "Launch Template ID: $LAUNCHTEMPLATEID"

  echo "Creating the TARGET GROUP and storing the ARN in TARGETARN..."
  TARGETARN=$(aws elbv2 create-target-group \
    --name "$target_group_name" \
    --protocol HTTP \
    --port 80 \
    --vpc-id "$VPCID" \
    --health-check-protocol HTTP \
    --health-check-path / \
    --region "$region" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)
  echo "Target Group ARN: $TARGETARN"

  echo "Creating ELBv2 Elastic Load Balancer..."
  ELBARN=$(aws elbv2 create-load-balancer \
    --name "$elb_name" \
    --subnets "$SUBNET2A" "$SUBNET2B" \
    --security-groups "$security_group_ids" \
    --region "$region" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)
  echo "Load Balancer ARN: $ELBARN"

  echo "Decreasing deregistration timeout to 30 seconds..."
  aws elbv2 modify-target-group-attributes \
    --target-group-arn "$TARGETARN" \
    --attributes Key=deregistration_delay.timeout_seconds,Value=30 \
    --region "$region"

  echo "Waiting for load balancer to be available..."
  aws elbv2 wait load-balancer-available --load-balancer-arns "$ELBARN" --region "$region"
  echo "Load balancer available..."

  echo "Creating listener on port 80 forwarding to target group..."
  aws elbv2 create-listener \
    --load-balancer-arn "$ELBARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn="$TARGETARN" \
    --region "$region"

  echo "Creating Auto Scaling Group..."
  aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name "$asg_name" \
    --launch-template LaunchTemplateId="$LAUNCHTEMPLATEID",Version=1 \
    --min-size "$asg_min" \
    --max-size "$asg_max" \
    --desired-capacity "$asg_desired" \
    --vpc-zone-identifier "$SUBNET2A,$SUBNET2B" \
    --target-group-arns "$TARGETARN" \
    --tags Key=Name,Value="$tag_value",PropagateAtLaunch=true \
    --region "$region"

  echo "Waiting for Auto Scaling Group to spin up EC2 instances and attach them to the Target Group..."
  aws elbv2 wait target-in-service --target-group-arn "$TARGETARN" --region "$region"
  echo "Targets attached to Auto Scaling Group..."

  echo "Collecting Instance IDs..."
  INSTANCEIDS=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running,pending" "Name=tag:Name,Values=$tag_value" \
    --query 'Reservations[*].Instances[*].InstanceId' --output text --region "$region")

  if [ -n "$INSTANCEIDS" ]; then
    echo "Waiting for instances to be running..."
    aws ec2 wait instance-running --instance-ids $INSTANCEIDS --region "$region"
    echo "Finished launching instances..."
  else
    echo "No running or pending instances found with tag $tag_value."
  fi

  # --- New Module 5 additions start here ---

  echo "Installing unzip if needed..."
  sudo apt-get update -y
  sudo apt-get install -y unzip

  echo "Creating S3 bucket one: $s3_bucket_one"
  aws s3 mb s3://$s3_bucket_one --region $region
  if [ $? -eq 0 ]; then
    echo "S3 bucket $s3_bucket_one created."
  else
    echo "S3 bucket $s3_bucket_one creation failed or bucket exists."
  fi

  echo "Creating S3 bucket two: $s3_bucket_two"
  aws s3 mb s3://$s3_bucket_two --region $region
  if [ $? -eq 0 ]; then
    echo "S3 bucket $s3_bucket_two created."
  else
    echo "S3 bucket $s3_bucket_two creation failed or bucket exists."
  fi

  echo "Unzipping images..."
  unzip -o images.zip -d ./images_for_s3/
  if [ $? -ne 0 ]; then
    echo "Failed to unzip images."
    exit 1
  fi

  echo "Unzipped files:"
  ls ./images_for_s3/

  # Replace these filenames with actual names from your zip file
  echo "Uploading 2 images to $s3_bucket_one"
  aws s3 cp ./images_for_s3/elevate.webp s3://$s3_bucket_one/elevate.webp --region $region
  aws s3 cp ./images_for_s3/illinoistech.png s3://$s3_bucket_one/illinoistech.png --region $region

  echo "Uploading 2 images to $s3_bucket_two"
  aws s3 cp ./images_for_s3/ranking.jpg s3://$s3_bucket_two/ranking.jpg --region $region
  aws s3 cp ./images_for_s3/rohit.jpg s3://$s3_bucket_two/rohit.jpg --region $region

  echo "S3 uploads complete."

  # --- End of Module 5 additions ---

  echo "Retrieving ELB DNS Name..."
  URL=$(aws elbv2 describe-load-balancers --load-balancer-arns "$ELBARN" --query 'LoadBalancers[0].DNSName' --output text --region "$region")
  echo "Access your application at: http://$URL"

fi