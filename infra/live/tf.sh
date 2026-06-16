#!/bin/bash
set -e

if [ "$#" -lt 2 ]; then
    echo "Usage: ./tf.sh <env> <command> [args...]"
    echo "Example: ./tf.sh dev plan"
    exit 1
fi

ENV=$1
CMD=$2
shift 2

# Ensure the .tfvars file exists
if [ ! -f "${ENV}.tfvars" ]; then
    echo "Error: ${ENV}.tfvars not found!"
    exit 1
fi

echo "=========================================================="
echo "Initializing Terraform for environment: ${ENV^^}"
echo "=========================================================="
terraform init -backend-config="key=jerney-eks/${ENV}/terraform.tfstate" -reconfigure

echo ""
echo "=========================================================="
echo "Running Terraform ${CMD} for environment: ${ENV^^}"
echo "=========================================================="
terraform $CMD -var-file="${ENV}.tfvars" "$@"
