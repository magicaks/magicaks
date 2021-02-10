FROM ubuntu:18.04
ENV MAGIC_AKS_GIT_URL "https://github.com/sachinkundu/akstf.git"
ENV FLUX_VER "1.21.1"
ENV TERRAFORM_VER "0.14.6"
WORKDIR /root/

# Install tools and clone the Magic AKS repository
RUN apt-get update && \
    apt-get install -y curl && \
    apt-get install -y git && \
    apt-get install -u unzip

# Tool - Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash 

# Tool - Kubectl
RUN curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list && \
    apt-get update && \
    apt-get install -y kubectl

# Tool - Fluxctl
RUN curl -L https://github.com/fluxcd/flux/releases/download/${FLUX_VER}/fluxctl_linux_amd64 -o /usr/local/bin/fluxctl && \
    chmod a+x /usr/local/bin/fluxctl

# Tool - Terraform
RUN curl -LO https://releases.hashicorp.com/terraform/${TERRAFORM_VER}/terraform_${TERRAFORM_VER}_linux_amd64.zip && \
    unzip terraform_${TERRAFORM_VER}_linux_amd64.zip && \
    mv terraform /usr/local/bin/

RUN git clone ${MAGIC_AKS_GIT_URL}

RUN echo 'alias ll="ls -l"' >> ~/.bashrc
WORKDIR /root/akstf/
