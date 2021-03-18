FROM ubuntu:18.04
ENV FLUX_VER "1.21.1"
ENV TERRAFORM_VER "0.14.2"
WORKDIR /root/

# Install tools and clone the Magic AKS repository
RUN apt-get update && \
    apt-get install -y curl && \
    apt-get install -y git && \
    apt-get install -u unzip

# Tool - Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash 

# Tool - Fluxctl
RUN curl -L https://github.com/fluxcd/flux/releases/download/${FLUX_VER}/fluxctl_linux_amd64 -o /usr/local/bin/fluxctl && \
    chmod a+x /usr/local/bin/fluxctl

# Tool - Terraform
RUN curl -LO https://releases.hashicorp.com/terraform/${TERRAFORM_VER}/terraform_${TERRAFORM_VER}_linux_amd64.zip && \
    unzip terraform_${TERRAFORM_VER}_linux_amd64.zip && \
    mv terraform /usr/local/bin/

RUN echo 'alias ll="ls -l"' >> ~/.bashrc
