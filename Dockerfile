# run with --uts=host --privileged --cap-add SYS_ADMIN
# -v /etc/ssl/docker
# -v /var/run/docker.sock
#
#
# ENV
# CONSUL_PORT CONSUL_HOSTNAME VAULT_PORT USER_VAULT_PORT USER_VAULT_HOSTNAME K8_TOKEN K8_HOST
# VAULT_TOKEN USER_VAULT_TOKEN
# DOCKER_CERT_PASS DOCKER_CERT_CA_BASE64 DOCKER_CERT_CA_KEY_BASE64

FROM ubuntu:14.04

RUN apt-get update && apt-get install -y openjdk-7-jdk wget make unzip jq vim systemd

WORKDIR /usr/local
RUN wget http://s3.amazonaws.com/ec2metadata/ec2-metadata -O ./bin/ec2-metadata

RUN wget http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip -O ./ec2-api-tools.zip
RUN unzip ./ec2-api-tools.zip -d .
RUN ln -s ./ec2-api-tools-1.7.5.1 ./ec2

RUN wget https://releases.hashicorp.com/vault/0.4.1/vault_0.4.1_linux_amd64.zip -O ./vault_0.4.1_linux_amd64.zip
RUN unzip ./vault_0.4.1_linux_amd64.zip -d ./bin

RUN wget https://releases.hashicorp.com/consul-template/0.11.1/consul-template_0.11.1_linux_amd64.zip -O ./consul-template_0.11.1_linux_amd64.zip
RUN unzip ./consul-template_0.11.1_linux_amd64.zip -d ./bin

WORKDIR /
ADD . /dock-init
WORKDIR /dock-init
ENV DOCK_INIT_BASE=/dock-init

CMD ./init.sh | tee /var/log/user-script-dock-init.log
