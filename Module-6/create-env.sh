#!/bin/bash

##############################################################################
# Module 06
# You will be creating an AWS secret, and RDS instance and a Read-Replica in 
# this module
# Append "-read-replica" to the ${22} to create the read-replica name
##############################################################################
# 1 image-id
# 2 instance-type
# 3 key-name
# 4 security-group-ids
# 5 count - of 3
# 6 user-data -- install-env.sh you will be provided 
# 7 Tag -- use the module name: `module6-tag`
# 8 Target Group (use your initials)
# 9 elb-name (use your initials)
# 10 Availability Zone 1
# 11 Availability Zone 2
# 12 Launch Template Name
# 13 ASG name
# 14 ASG min=2
# 15 ASG max=5
# 16 ASG desired=3
# 17 AWS Region for LaunchTemplate (use your default region)
# 18 EBS hard drive size in GB (15)
# 19 S3 bucket name one - use initials
# 20 S3 bucket name two - use initials
# 21 Secret Name
# 22 Database Name

#!/bin/bash

# Check if exactly 22 arguments are provided
if [ $# -ne 22 ]; then
    echo "Error: Exactly 22 arguments are required"
    exit 1
fi

# Retrieve the secret values
SECRET_JSON=$(aws secretsmanager get-secret-value --secret-id ${21} --query SecretString --output text 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Error: Failed to retrieve secret ${21}. Ensure create-secrets.sh was run first."
    exit 1
fi

# Parse JSON to get user and pass
USERVALUE=$(echo $SECRET_JSON | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['user'])")
PASSVALUE=$(echo $SECRET_JSON | python3 -c "import sys, json; data=json.load(sys.stdin); print(data['pass'])")

echo "Secret retrieved successfully. User: $USERVALUE"

# Create Primary RDS Instance
echo "Creating primary RDS instance: ${22}"

aws rds create-db-instance --db-instance-identifier ${22} --db-instance-class db.t3.micro --engine mysql --master-username $USERVALUE --master-user-password "$PASSVALUE" --allocated-storage 20 --db-name employee_database --tags "Key=assessment,Value=${7}"

# Wait for primary instance to be available
echo "Waiting for primary RDS to be available..."
aws rds wait db-instance-available --db-instance-identifier ${22}

# Get primary endpoint
PRIMARY_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier ${22} --query 'DBInstances[0].Endpoint.Address' --output text)
echo "Primary RDS Endpoint: $PRIMARY_ENDPOINT"

# Create Read-Replica RDS Instance
echo "Creating read-replica RDS: ${22}-read-replica"

aws rds create-db-instance-read-replica --db-instance-identifier ${22}-read-replica --source-db-instance-identifier ${22} --tags "Key=assessment,Value=${7}"

# Wait for replica to be available
echo "Waiting for read-replica RDS to be available..."
aws rds wait db-instance-available --db-instance-identifier ${22}-read-replica

# Get replica endpoint
REPLICA_ENDPOINT=$(aws rds describe-db-instances --db-instance-identifier ${22}-read-replica --query 'DBInstances[0].Endpoint.Address' --output text)
echo "Read-Replica RDS Endpoint: $REPLICA_ENDPOINT"

echo "RDS creation completed successfully!"
