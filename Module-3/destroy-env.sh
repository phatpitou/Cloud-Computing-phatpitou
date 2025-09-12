#!/bin/bash
##############################################################################
# Module-03
# This assignment requires you to destroy the Cloud assets you created
# Remember to set you default output to text in the aws config command
##############################################################################

echo "Beginning destroy script for module-03 assessment..."

# Collect Instance IDs
INSTANCEIDS=$(aws ec2 describe-instances --output=text --query 'Reservations[*].Instances[*].InstanceId' --filter "Name=instance-state-name,Values=running,pending" "Name=tag:Name,Values=${7}")
echo "List of INSTANCEIDS to deregister..."
if [ "$INSTANCEIDS" == "" ];
  then
  echo "There are no INSTANCEIDS to echo..."
else
  echo $INSTANCEIDS
fi 

echo "Finding TARGETARN..."
TARGETARN=$(aws elbv2 describe-target-groups --names "${8}" --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
echo $TARGETARN

if [ "$INSTANCEIDS" != "" ]
  then
    echo '$INSTANCEIDS to be deregistered with the target group...'
    INSTANCEIDSARRAY=($INSTANCEIDS)
    for INSTANCEID in ${INSTANCEIDSARRAY[@]};
      do
      echo "Deregistering target $INSTANCEID..."
      aws elbv2 deregister-targets --target-group-arn $TARGETARN --targets Id=$INSTANCEID
      echo "Waiting for target $INSTANCEID to be deregistered..."
      aws elbv2 wait target-deregistered --target-group-arn $TARGETARN --targets Id=$INSTANCEID
      done
  else
    echo 'There are no running or pending values in $INSTANCEIDS to wait for...'
fi 

echo "Now terminating the detached INSTANCEIDS..."
if [ "$INSTANCEIDS" != "" ]
  then
    aws ec2 terminate-instances --instance-ids $INSTANCEIDS
    echo "Waiting for all instances report state as TERMINATED..."
    aws ec2 wait instance-terminated --instance-ids $INSTANCEIDS
    echo "Finished destroying instances..."
  else
    echo 'There are no running values in $INSTANCEIDS to be terminated...'
fi 

echo "Looking up ELB ARN..."
ELBARN=$(aws elbv2 describe-load-balancers --names "${9}" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)
echo $ELBARN

if [ "$ELBARN" != "" ] && [ "$ELBARN" != "None" ]; then
    LISTENERARNS=$(aws elbv2 describe-listeners --load-balancer-arn $ELBARN --query='Listeners[*].ListenerArn' --output text)
    for LISTENERARN in $LISTENERARNS;
      do
        echo "Deleting Listener $LISTENERARN..."
        aws elbv2 delete-listener --listener-arn $LISTENERARN
        echo "Listener deleted..."
      done
else
    echo "No ELB or listeners found to delete."
fi

if [ "$TARGETARN" = "" ] || [ "$TARGETARN" = "None" ];
  then  
  echo "No Target Groups to delete..."
else
  echo "Deleting target group $TARGETARN..."
  TARGETARNSARRAY=($TARGETARN)
    for TGARN in ${TARGETARNSARRAY[@]};
      do
        aws elbv2 delete-target-group --target-group-arn $TGARN
      done
fi

if [ "$ELBARN" = "" ] || [ "$ELBARN" = "None" ];
  then
  echo "No ELBs to delete..."
else
  echo "Issuing Command to delete Load Balancer.."
  aws elbv2 delete-load-balancer --load-balancer-arn $ELBARN
  echo "Load Balancer delete command has been issued..."

  echo "Waiting for ELB to be deleted..."
  aws elbv2 wait load-balancers-deleted --load-balancer-arns $ELBARN
fi