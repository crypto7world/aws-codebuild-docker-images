#!/bin/sh

amazon-linux-extras install docker
sudo usermod -a -G docker ec2-user
yum groupinstall -yq "Development tools"
systemctl start docker

curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install

cd /home/ec2-user
sudo -u ec2-user git clone https://github.com/crypto7world/aws-codebuild-docker-images.git
cd aws-codebuild-docker-images/al2/aarch64/standard/2.0/
sudo -u ec2-user docker build -t crypto7/codebuild/amazonlinux2-aarch64-standard:2.0 .
