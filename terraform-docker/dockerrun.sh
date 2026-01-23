# /bin/bash

if [ ! -z "$CLOUD" ]; then
    echo "cd ./${CLOUD}"
    cd ./${CLOUD}
else
    echo "NO CLOUD ENV VAR SET"
    exit 1
fi

export TF_IN_AUTOMATION=true

echo "Running terraform init"
terraform init

if [ "$PLAN" = "true" ]; then
    echo "Running terraform plan"
    terraform plan -out=tfplan >/dev/null
    terraform show -json tfplan >output.json
    tf-summarize output.json
fi

if [ "$DEPLOY" = "true" ]; then
    echo "Running terraform apply"
    terraform apply -auto-approve
fi

if [ "$DESTROY" = "true" ]; then
    echo "Running terraform destroy"
    terraform destroy -auto-approve
    echo "Done"
fi

exit 0
