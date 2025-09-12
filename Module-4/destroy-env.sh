#!/bin/bash
##############################################################################
# Module-04 Destroy Script
# This script destroys the Cloud assets created in Module-04
# Remember to set your default output to text in the aws config command
##############################################################################

ltconfigfile="./config.json"

echo "Beginning destroy script for module-04 assessment..."

echo "Finding Launch template configuration file: $ltconfigfile..."
if [ -a "$ltconfigfile" ]; then
  echo "Deleting Launch template configuration file: $ltconfigfile..."
  rm "$ltconfigfile"
  echo "Deleted Launch template configuration file: $ltconfigfile..."
else
  echo "Launch template configuration file: $ltconfigfile doesn't exist, moving on..."
fi

# Collect Instance IDs of running instances
INSTANCEIDS=$(aws ec2 describe-instances --output=text --query 'Reservations[*].Instances[*].InstanceId' --filters "Name=instance-state-name,Values=running" 2>/dev/null || echo "")

echo 'Finding autoscaling group names...'
ASGNAMES=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[].AutoScalingGroupName" --output text 2>/dev/null || echo "")

if [ -n "$ASGNAMES" ]; then
  echo "Found AutoScalingGroups: $ASGNAMES..."
  for ASGNAME in $ASGNAMES; do
    echo "Processing Auto Scaling Group: $ASGNAME"

    # Set min-size and desired-capacity to 0 to start scale down
    aws autoscaling update-auto-scaling-group --auto-scaling-group-name "$ASGNAME" --min-size 0 --desired-capacity 0

    if [ -n "$INSTANCEIDS" ]; then
      echo "Waiting for all instances to be terminated..."
      aws ec2 wait instance-terminated --instance-ids $INSTANCEIDS
      echo "All instances terminated..."
    else
      echo "No instances to wait for termination..."
    fi
  done
else
  echo "No AutoScalingGroups Detected. Perhaps check if your create-env.sh script ran properly?"
fi

echo "Finding TARGETARN..."
TARGETARN=$(aws elbv2 describe-target-groups --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "")
if [ -n "$TARGETARN" ]; then
  echo "Found TargetARN: $TARGETARN..."
else
  echo "Could not find any TargetARN. Perhaps check if the create-env.sh ran properly?"
fi

if [ -n "$INSTANCEIDS" ] && [ -n "$TARGETARN" ]; then
  echo "\$INSTANCEIDS to be deregistered with the target group..."
  INSTANCEIDSARRAY=($INSTANCEIDS)
  for INSTANCEID in "${INSTANCEIDSARRAY[@]}"; do
    echo "Deregistering target $INSTANCEID..."
    aws elbv2 deregister-targets --target-group-arn "$TARGETARN" --targets Id="$INSTANCEID"
    echo "Waiting for target $INSTANCEID to be deregistered..."
    aws elbv2 wait target-deregistered --target-group-arn "$TARGETARN" --targets Id="$INSTANCEID"
  done
else
  echo 'There are no running or pending values in $INSTANCEIDS to wait for or no target group ARN...'
fi 

echo "Looking up ELB ARN..."
ELBARN=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "")
echo "$ELBARN"

if [ -n "$ELBARN" ] && [ "$ELBARN" != "None" ]; then
  LISTENERARNS=$(aws elbv2 describe-listeners --load-balancer-arn "$ELBARN" --query='Listeners[*].ListenerArn' --output text)
  for LISTENERARN in $LISTENERARNS; do
    echo "Deleting Listener $LISTENERARN..."
    aws elbv2 delete-listener --listener-arn "$LISTENERARN"
    echo "Listener deleted..."
  done
else
  echo "No ELB or listeners found to delete."
fi

if [ -z "$TARGETARN" ] || [ "$TARGETARN" = "None" ]; then  
  echo "No Target Groups to delete..."
else
  echo "Deleting target group $TARGETARN..."
  TARGETARNSARRAY=($TARGETARN)
  for TGARN in "${TARGETARNSARRAY[@]}"; do
    aws elbv2 delete-target-group --target-group-arn "$TGARN"
  done
fi

if [ -z "$ELBARN" ] || [ "$ELBARN" = "None" ]; then
  echo "No ELBs to delete..."
else
  echo "Issuing Command to delete Load Balancer..."
  aws elbv2 delete-load-balancer --load-balancer-arn "$ELBARN"
  echo "Load Balancer delete command has been issued..."

  echo "Waiting for ELB: $ELBARN to be deleted..."
  aws elbv2 wait load-balancers-deleted --load-balancer-arns "$ELBARN"
  echo "ELB: $ELBARN deleted..." 
fi

echo 'Finding autoscaling groups for deletion...'
ASGNAMES=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[*].AutoScalingGroupName" --output text)
if [ -z "$ASGNAMES" ]; then
  echo "No Autoscaling Groups found..."
else
  echo "Autoscaling Groups: $ASGNAMES found..."
  ASGNAMESARRAY=($ASGNAMES)
  for ASGNAME in "${ASGNAMESARRAY[@]}"; do
    echo "Deleting $ASGNAME..."
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name "$ASGNAME" --force-delete
    echo "Deleted $ASGNAME..."
  done
fi

echo 'Finding launch templates...'
LAUNCHTEMPLATEIDS=$(aws ec2 describe-launch-templates --query 'LaunchTemplates[].LaunchTemplateName' --output text)

if [ -n "$LAUNCHTEMPLATEIDS" ]; then
  echo "Found launch-templates: $LAUNCHTEMPLATEIDS..."
  for LAUNCHTEMPLATEID in $LAUNCHTEMPLATEIDS; do
    echo "Deleting launch-template: $LAUNCHTEMPLATEID"
    aws ec2 delete-launch-template --launch-template-name "$LAUNCHTEMPLATEID"
  done
else
  echo "No launch-templates found. Perhaps you forgot to run the create-env.sh script?"
fi