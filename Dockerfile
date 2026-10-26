# Use an official lightweight HashiCorp Terraform image as the base
FROM hashicorp/terraform:1.9.5

# Install dependencies
RUN apk add --no-cache \
    bash \
    git \
    curl \
    jq \
    kubectl \
    helm \
    aws-cli \
    python3 \
    py3-pip \
    openssh

# Set workdir inside container
WORKDIR /workspace

# Copy repo contents into container (optional if you mount instead)
COPY examples /workspace


# Pre-install Python requirements if needed (for scripts inside gen3-terraform)
# RUN pip install -r requirements.txt

# Terraform entrypoint
# ENTRYPOINT [ "/bin/terraform" ]
ENTRYPOINT ["/bin/sh", "-c"]
# CMD ["/bin/bash"]
