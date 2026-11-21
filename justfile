# requires just >= 1.58.0

default:
    @just --list

# Run all module tests (no AWS credentials required)
test:
    @just test-commons-vpc-es
    @just test-squid-auto

# Test the commons-vpc-es module (validates role_arn implicit dependency)
test-commons-vpc-es:
    cd tf_files/aws/modules/commons-vpc-es && \
        terraform init -backend=false -input=false > /dev/null && \
        terraform test

# Test the squid_auto module (validates SSM key dependency)
test-squid-auto:
    cd tf_files/aws/modules/squid_auto && \
        terraform init -backend=false -input=false > /dev/null && \
        terraform test
