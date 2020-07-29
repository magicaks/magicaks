FROM ubuntu:18.04
ENV MAGIC_AKS_GIT_URL 'https://github.com/sachinkundu/akstf.git'
WORKDIR /root/

# Install tools and clone the Magic AKS repository
RUN apt-get update && \
    apt-get install -y curl && \
    apt-get install -y git && \
    curl -sL https://aka.ms/InstallAzureCLIDeb | bash && \
    git clone ${MAGIC_AKS_GIT_URL}

RUN echo 'alias ll="ls -l"' >> ~/.bashrc
WORKDIR /root/akstf/
