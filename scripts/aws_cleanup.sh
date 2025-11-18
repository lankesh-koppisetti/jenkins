#!/bin/bash
set -e

echo "Starting AWS cleanup job at $(date)"

###########################################
# DELETE EC2 INSTANCES WITH A TAG
###########################################
echo "Deleting EC2 instances..."
INSTANCE_IDS=$(aws ec2 describe-instances \
  --filters "Name=tag:AutoDelete,Values=true" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text)

if [ -n "$INSTANCE_IDS" ]; then
  aws ec2 terminate-instances --instance-ids $INSTANCE_IDS
  echo "Terminated EC2 instances: $INSTANCE_IDS"
else
  echo "No EC2 instances found for deletion."
fi

###########################################
# DELETE S3 BUCKETS WITH A TAG
###########################################
echo "Deleting S3 buckets..."
BUCKETS=$(aws s3api list-buckets --query "Buckets[].Name" --output text)

for bucket in $BUCKETS; do
  TAGGED=$(aws s3api get-bucket-tagging --bucket "$bucket" 2>/dev/null | grep -c '"AutoDelete": "true"' || true)
  if [ "$TAGGED" -gt 0 ]; then
    echo "Deleting bucket: $bucket"
    aws s3 rm "s3://$bucket" --recursive
    aws s3api delete-bucket --bucket "$bucket"
  fi
done

###########################################
# DELETE LAMBDA FUNCTIONS WITH TAG
###########################################
echo "Deleting Lambda functions..."
LAMBDA_FUNCS=$(aws lambda list-functions --query "Functions[].FunctionName" --output text)

for fn in $LAMBDA_FUNCS; do
  TAG_VALUE=$(aws lambda list-tags --resource "arn:aws:lambda:us-east-1:<ACCOUNT_ID>:function:$fn" \
    --query "Tags.AutoDelete" --output text 2>/dev/null)

  if [ "$TAG_VALUE" == "true" ]; then
    echo "Deleting Lambda function: $fn"
    aws lambda delete-function --function-name "$fn"
  fi
done

echo "AWS cleanup job completed successfully."
