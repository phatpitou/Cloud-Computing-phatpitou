#!/bin/bash
##############################################################################
# Module-05
# This assignment requires you to destroy the Cloud assets you created
# Remember to set your default output to text in the aws config command
##############################################################################
ltconfigfile="./config.json"

echo "Beginning destroy script for module-05 assessment..."

echo "Finding Launch template configuration file: $ltconfigfile..."
if [ -a "$ltconfigfile" ]
then
  echo "Deleting Launch template configuration file: $ltconfigfile..."
  rm "$ltconfigfile"
  echo "Deleted Launch template configuration file: $ltconfigfile..."
else
  echo "Launch template configuration file: $ltconfigfile doesn't exist, moving on..."
# end of config.json delete
fi

# Collect Instance IDs of running instances only
INSTANCEIDS=$(aws ec2 describe-instances --output=text --query 'Reservations[*].Instances[*].InstanceId' --filters "Name=instance-state-name,Values=running")

echo 'Finding autoscaling groups...'
ASGNAMES=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[*].AutoScalingGroupName" --output text)
if [ "$ASGNAMES" != "" ]
  then
    echo "Found AutoScalingGroups: $ASGNAMES..."
    for ASGNAME in $ASGNAMES; do
      echo "Processing Auto Scaling Group: $ASGNAME"

      # Scale down ASG to zero instances before deletion
      aws autoscaling update-auto-scaling-group \
        --auto-scaling-group-name "$ASGNAME" \
        --min-size 0 \
        --desired-capacity 0

     if [ "$INSTANCEIDS" != "" ]
       then
         # Wait for all instances to be terminated
         echo "Waiting for all instances to be terminated..."
         aws ec2 wait instance-terminated --instance-ids $INSTANCEIDS
         echo "All instances terminated..."
    else
      echo "No instances to wait for termination..."
      # end of internal if to check number of instances
    fi
     
    done
else
  echo "No AutoScalingGroups Detected. Perhaps check if your create-env.sh script ran properly?"
# End of ASG discovery and delete phase
fi

echo "Finding TARGETARN..."
# Get Target Group ARNs
TARGETARN=$(aws elbv2 describe-target-groups --query "TargetGroups[*].TargetGroupArn" --output text)
if [ "$TARGETARN" != "" ]
  then
    echo "Found TargetARN: $TARGETARN..."
  else
    echo "Could not find any TargetARN. Perhaps check if the create-env.sh ran properly?"
# End of TargetARN discovery
fi

if [ "$INSTANCEIDS" != "" ] && [ "$TARGETARN" != "" ]
  then
    echo "\$INSTANCEIDS to be deregistered with the target group..."
    # Convert space-separated strings to arrays
    INSTANCEIDSARRAY=($INSTANCEIDS)
    TARGETARNSARRAY=($TARGETARN)
    for TGARN in "${TARGETARNSARRAY[@]}"; do
      for INSTANCEID in "${INSTANCEIDSARRAY[@]}"; do
        echo "Deregistering target $INSTANCEID from target group $TGARN..."
        aws elbv2 deregister-targets --target-group-arn "$TGARN" --targets Id="$INSTANCEID"
        echo "Waiting for target $INSTANCEID to be deregistered..."
        aws elbv2 wait target-deregistered --target-group-arn "$TGARN" --targets Id="$INSTANCEID"
      done
    done
  else
    echo 'There are no running instances or target groups to deregister...'
fi 

echo "Looking up ELB ARN..."
# Get Load Balancer ARNs
ELBARN=$(aws elbv2 describe-load-balancers --query "LoadBalancers[].LoadBalancerArn" --output text)
echo "$ELBARN"

# Collect ListenerARNs and delete listeners
ELBARNSARRAY=($ELBARN)
for ELB in "${ELBARNSARRAY[@]}"; do
  echo "Processing Load Balancer: $ELB"
  LISTENERARN=$(aws elbv2 describe-listeners --load-balancer-arn "$ELB" --query='Listeners[].ListenerArn' --output text)
  LISTENERARNARRAY=($LISTENERARN)
  for LISTENER in "${LISTENERARNARRAY[@]}"; do
    echo "Deleting Listener: $LISTENER..."
    aws elbv2 delete-listener --listener-arn "$LISTENER"
    echo "Listener deleted..."
  done
done

if [ "$TARGETARN" = "" ];
  then  
  echo "No Target Groups to delete..."
else
  echo "Deleting target group(s): $TARGETARN..."
  TARGETARNSARRAY=($TARGETARN)
  for TGARN in "${TARGETARNSARRAY[@]}"; do
    aws elbv2 delete-target-group --target-group-arn "$TGARN"
  done
fi

if [ "$ELBARN" = "" ];
  then
  echo "No ELBs to delete..."
else
  echo "Issuing Command to delete Load Balancer(s)..."
  for ELB in "${ELBARNSARRAY[@]}"; do
    aws elbv2 delete-load-balancer --load-balancer-arn "$ELB"
    echo "Load Balancer delete command has been issued for $ELB..."
    echo "Waiting for ELB: $ELB to be deleted..."
    aws elbv2 wait load-balancers-deleted --load-balancer-arns "$ELB"
    echo "ELB: $ELB deleted..." 
  done
fi

echo 'Finding autoscaling groups for deletion...'
ASGNAMES=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[*].AutoScalingGroupName" --output text)
if [ "$ASGNAMES" = "" ];
then
  echo "No Autoscaling Groups found..."
else
  echo "Autoscaling Groups: $ASGNAMES found..."
  ASGNAMESARRAY=($ASGNAMES)
  for ASGNAME in "${ASGNAMESARRAY[@]}"; do
    echo "Deleting $ASGNAME..."
    aws autoscaling delete-auto-scaling-group --auto-scaling-group-name "$ASGNAME" --force-delete
    echo "Deleted $ASGNAME..."
  done
# End of if for checking on ASGs
fi

echo 'Finding launch-templates...'
LAUNCHTEMPLATEIDS=$(aws ec2 describe-launch-templates --query 'LaunchTemplates[].LaunchTemplateName' --output text)

if [ "$LAUNCHTEMPLATEIDS" != "" ]
  then
    echo "Found launch-template(s): $LAUNCHTEMPLATEIDS..."
    for LAUNCHTEMPLATEID in $LAUNCHTEMPLATEIDS; do
      echo "Deleting launch-template: $LAUNCHTEMPLATEID"
      aws ec2 delete-launch-template --launch-template-name "$LAUNCHTEMPLATEID"
    done
else
   echo "No launch-templates found. Perhaps you forgot to run the create-env.sh script?"
# end of if for launchtemplateids
fi 

# Query for bucket names, delete objects then buckets
MYS3BUCKETS=$(aws s3api list-buckets --query "Buckets[].Name" --output text)
MYS3BUCKETS_ARRAY=($MYS3BUCKETS)

# Check if bucket list is non-empty
if [ -n "$MYS3BUCKETS" ]
  then 
    echo "Looping through buckets to delete objects and buckets..."
    for BUCKET in "${MYS3BUCKETS_ARRAY[@]}"
    do
      echo "Processing bucket: $BUCKET"
      MYKEYS=$(aws s3api list-objects-v2 --bucket "$BUCKET" --query "Contents[].Key" --output text)
      MYKEYS_ARRAY=($MYKEYS)

      if [ -n "$MYKEYS" ]; then
        echo "Deleting objects in bucket $BUCKET..."
        for KEY in "${MYKEYS_ARRAY[@]}"
        do
          echo "Deleting object $KEY in bucket $BUCKET..."
          aws s3api delete-object --bucket "$BUCKET" --key "$KEY"
          aws s3api wait object-not-exists --bucket "$BUCKET" --key "$KEY"
          echo "Deleted object $KEY in bucket $BUCKET..."
        done
      else
        echo "No objects found in bucket $BUCKET."
      fi

      echo "Deleting bucket $BUCKET..."
      aws s3api delete-bucket --bucket "$BUCKET"
      aws s3api wait bucket-not-exists --bucket "$BUCKET"
      echo "Deleted bucket $BUCKET..."
    done
  else  
    echo "There seems to be no buckets present -- did you run create-env.sh?"
# end of s3 deletion block
fi