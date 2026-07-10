FROM gcr.io/google.com/cloudsdktool/google-cloud-cli:stable

ARG TF_VERSION=1.13.0

RUN apt-get update && \
    apt-get install -y wget unzip && \
    wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip && \
    unzip terraform_${TF_VERSION}_linux_amd64.zip && \
    mv terraform /usr/local/bin && \
    rm terraform_${TF_VERSION}_linux_amd64.zip

COPY init.sh /
