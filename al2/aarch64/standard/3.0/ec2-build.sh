#!/bin/sh

amazon-linux-extras install docker
sudo usermod -a -G docker ec2-user
yum groupinstall -yq "Development tools"
systemctl start docker

# Install AWS CLI v2
# If v1 is present uninstall it
if [[ "$(aws --version 2>&1)" =~ aws-cli/1 ]] ; then
  pip3 uninstall -y awscli
  yum remove -y awscli
fi
# If v2 is NOT present, install it
if ! [[ "$(aws --version 2>&1)" =~ aws-cli/2 ]] ; then
  curl https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip -o awscliv2.zip
  unzip awscliv2.zip
  ./aws/install -u -b /usr/bin
  rm -rf aws/ awscliv2.zip
fi

cd /home/ec2-user
sudo -u ec2-user git clone https://github.com/crypto7world/aws-codebuild-docker-images.git
cd aws-codebuild-docker-images/al2/aarch64/standard/2.0/
sudo -u ec2-user docker build -t crypto7/codebuild/amazonlinux2-aarch64-standard:3.0 .
