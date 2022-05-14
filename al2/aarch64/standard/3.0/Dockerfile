# Copyright 2020-2020 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use this file except in compliance with the License.
# A copy of the License is located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file.
# This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or implied.
# See the License for the specific language governing permissions and limitations under the License.

FROM public.ecr.aws/amazonlinux/amazonlinux:2 AS core

ENV EPEL_REPO="https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm"

# Install git, SSH, and other utilities
RUN set -ex \
    && yum install -yq openssh-clients \
    && mkdir ~/.ssh \
    && touch ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa -H github.com >> ~/.ssh/known_hosts \
    && ssh-keyscan -t rsa,dsa -H bitbucket.org >> ~/.ssh/known_hosts \
    && chmod 600 ~/.ssh/known_hosts \
    && yum install -yq $EPEL_REPO \
    && rpm --import https://download.mono-project.com/repo/xamarin.gpg \
    && curl https://download.mono-project.com/repo/centos7-stable.repo | tee /etc/yum.repos.d/mono-centos7-stable.repo \
    && amazon-linux-extras enable docker \
    && yum groupinstall -yq "Development tools" \
    && yum install -yq \
           GeoIP-devel ImageMagick asciidoc bzip2-devel bzr bzrtools cvs cvsps \
           docbook-dtds docbook-style-xsl dpkg-dev e2fsprogs expat-devel expect fakeroot \
           glib2-devel groff gzip icu iptables jq krb5-server libargon2-devel \
           libcurl-devel libdb-devel libedit-devel libevent-devel libffi-devel \
           libicu-devel libjpeg-devel libpng-devel libserf libsqlite3x-devel \
           libtidy-devel libunwind libwebp-devel libxml2-devel libxslt libxslt-devel \
           libyaml-devel libzip-devel mariadb-devel mlocate \
           ncurses-devel oniguruma-devel openssl openssl-devel perl-DBD-SQLite \
           perl-DBI perl-HTTP-Date perl-IO-Pty-Easy perl-TimeDate perl-YAML-LibYAML \
           postgresql-devel procps-ng python-configobj readline-devel rsync sgml-common \
           subversion-perl tar tcl tk vim wget which xfsprogs xmlto xorg-x11-server-Xvfb xz-devel \
           amazon-ecr-credential-helper clang cmake3

RUN ln -s /usr/bin/cmake3 /usr/bin/cmake

RUN useradd codebuild-user

#=======================End of layer: core  =================

FROM core AS tools

# Install Git
RUN set -ex \
   && GIT_VERSION=2.27.0 \
   && GIT_TAR_FILE=git-$GIT_VERSION.tar.gz \
   && GIT_SRC=https://github.com/git/git/archive/v${GIT_VERSION}.tar.gz  \
   && curl -L -o $GIT_TAR_FILE $GIT_SRC \
   && tar zxf $GIT_TAR_FILE \
   && cd git-$GIT_VERSION \
   && make -j4 prefix=/usr \
   && make install prefix=/usr \
   && cd .. ; rm -rf git-$GIT_VERSION \
   && rm -rf $GIT_TAR_FILE /tmp/*

# Install stunnel
RUN set -ex \
   && STUNNEL_VERSION=5.56 \
   && STUNNEL_TAR=stunnel-$STUNNEL_VERSION.tar.gz \
   && STUNNEL_SHA256="7384bfb356b9a89ddfee70b5ca494d187605bb516b4fff597e167f97e2236b22" \
   && curl -o $STUNNEL_TAR https://www.usenix.org.uk/mirrors/stunnel/archive/5.x/$STUNNEL_TAR \
   && echo "$STUNNEL_SHA256 $STUNNEL_TAR" | sha256sum -c - \
   && tar xvfz $STUNNEL_TAR \
   && cd stunnel-$STUNNEL_VERSION \
   && ./configure \
   && make -j4 \
   && make install \
   && openssl genrsa -out key.pem 2048 \
   && openssl req -new -x509 -key key.pem -out cert.pem -days 1095 -subj "/C=US/ST=Washington/L=Seattle/O=Amazon/OU=Codebuild/CN=codebuild.amazon.com" \
   && cat key.pem cert.pem >> /usr/local/etc/stunnel/stunnel.pem \
   && cd .. ; rm -rf stunnel-${STUNNEL_VERSION}*

# AWS Tools
# https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html https://docs.aws.amazon.com/eks/latest/userguide/install-kubectl.html
RUN curl -sS -o /usr/local/bin/aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.16.8/2020-04-16/bin/linux/arm64/aws-iam-authenticator \
    && curl -sS -o /usr/local/bin/kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.16.8/2020-04-16/bin/linux/arm64/kubectl \
    && curl -sS -o /usr/local/bin/ecs-cli https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-arm64-latest \
    && chmod +x /usr/local/bin/kubectl /usr/local/bin/aws-iam-authenticator /usr/local/bin/ecs-cli

# Configure SSM
RUN set -ex \
    && yum install -yq https://s3.amazonaws.com/amazon-ssm-us-east-1/3.0.1390.0/linux_arm64/amazon-ssm-agent.rpm

# Install AWS CLI v2
# https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html
RUN curl https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip -o /tmp/awscliv2.zip \
    && unzip -q /tmp/awscliv2.zip -d /opt \
    && /opt/aws/install --update -i /usr/local/aws-cli -b /usr/local/bin \
    && rm /tmp/awscliv2.zip \
    && rm -rf /opt/aws \
    && aws --version

# Install env tools for runtimes

##nodejs
ENV N_SRC_DIR="$SRC_DIR/n"
RUN git clone https://github.com/tj/n $N_SRC_DIR \
     && cd $N_SRC_DIR && make install

##python
RUN curl https://pyenv.run | bash
ENV PATH="/root/.pyenv/shims:/root/.pyenv/bin:$PATH"

#=======================End of layer: tools  =================

FROM tools AS runtimes_1


#****************      NODEJS     ****************************************************

ENV NODE_10_VERSION="10.24.1"

RUN  n $NODE_10_VERSION && npm install --save-dev -g -f grunt && npm install --save-dev -g -f grunt-cli && npm install --save-dev -g -f webpack \
     && curl -sSL https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo \
     && rpm --import https://dl.yarnpkg.com/rpm/pubkey.gpg \
     && yum install -yq yarn \
     && yarn --version \
     && cd / && rm -rf $N_SRC_DIR; rm -rf /tmp/*

#****************      END NODEJS     ****************************************************

#**************** PYTHON *****************************************************
ENV PYTHON_37_VERSION="3.7.10"
ENV PYTHON_PIP_VERSION=21.1.2
ENV PYYAML_VERSION=5.4.1
ENV DOCKER_COMPOSE_VERSION="1.26.0"

COPY tools/runtime_configs/python/$PYTHON_37_VERSION /root/.pyenv/plugins/python-build/share/python-build/$PYTHON_37_VERSION
RUN   env PYTHON_CONFIGURE_OPTS="--enable-shared" pyenv install $PYTHON_37_VERSION; rm -rf /tmp/*
RUN   pyenv global  $PYTHON_37_VERSION
RUN set -ex \
    && pip3 install --no-cache-dir --upgrade --force-reinstall "pip==$PYTHON_PIP_VERSION" \
    && pip3 install --no-cache-dir --upgrade "PyYAML==$PYYAML_VERSION" \
    && pip3 install --no-cache-dir --upgrade 'setuptools==57.4.0' wheel aws-sam-cli awscli boto3 pipenv virtualenv \
    && pip3 install --no-cache-dir "docker-compose==$DOCKER_COMPOSE_VERSION" \
    && docker-compose version

#**************** END PYTHON *****************************************************

#****************     GOLANG     ****************************************************
ENV GOPATH="/go" \
    DEP_VERSION="0.5.4" \
    DEP_BINARY="dep-linux-arm64"

ENV GOLANG_18_VERSION="1.18.2"
ENV GOLANG_18_DOWNLOAD_SHA256="fc4ad28d0501eaa9c9d6190de3888c9d44d8b5fb02183ce4ae93713f67b8a35b"

RUN set -ex \
    && mkdir -p "$GOPATH/src" "$GOPATH/bin" \
    && chmod -R 777 "$GOPATH" \
    && wget -q "https://dl.google.com/go/go$GOLANG_18_VERSION.linux-arm64.tar.gz" -O /tmp/golang.tar.gz \
    && echo "$GOLANG_18_DOWNLOAD_SHA256 /tmp/golang.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/golang.tar.gz -C /tmp \
    && mv /tmp/go /usr/local/go18  \
    && rm -fr /tmp/* /var/tmp/* \
    && wget -q "https://github.com/golang/dep/releases/download/v$DEP_VERSION/$DEP_BINARY" -O "$GOPATH/bin/dep" \
    && chmod +x "$GOPATH/bin/dep"

RUN ln -s /usr/local/go18 /usr/local/go
ENV PATH="$GOPATH/bin:/usr/local/go/bin:$PATH"

#****************     GO 1.17   **********************************************************
ENV GOLANG_17_VERSION="1.17.9"
ENV GOLANG_17_DOWNLOAD_SHA256="44dcdcd4f0fa6f83c15ef70b31580f1e3f95895c2f11a00e36c440c3554b6ad5"

RUN set -ex \
    && wget -q "https://dl.google.com/go/go$GOLANG_17_VERSION.linux-arm64.tar.gz" -O /tmp/golang.tar.gz \
    && echo "$GOLANG_17_DOWNLOAD_SHA256 /tmp/golang.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/golang.tar.gz -C /tmp \
    && mv /tmp/go /usr/local/go17  \
    && rm -fr /tmp/* /var/tmp/*

#****************     GO 1.16   **********************************************************
ENV GOLANG_16_VERSION="1.16.15"
ENV GOLANG_16_DOWNLOAD_SHA256="c2f27f0ce5620a9bc2ff3446165d1974ef94e9b885ec12dbfa3c07e0e198b7ce"

RUN set -ex \
    && wget -q "https://dl.google.com/go/go$GOLANG_16_VERSION.linux-arm64.tar.gz" -O /tmp/golang.tar.gz \
    && echo "$GOLANG_16_DOWNLOAD_SHA256 /tmp/golang.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/golang.tar.gz -C /tmp \
    && mv /tmp/go /usr/local/go16  \
    && rm -fr /tmp/* /var/tmp/*

#****************      END GOLANG     ****************************************************

#**************** RUST *****************************************************
ENV RUST_1_VERSION="1.60.0"
ENV RUST_1_DOWNLOAD_SHA256="99c419c2f35d4324446481c39402c7baecd7a8baed7edca9f8d6bbd33c05550c"

RUN set -ex \
    && wget -q "https://static.rust-lang.org/dist/rust-${RUST_1_VERSION}-aarch64-unknown-linux-gnu.tar.gz" -O /tmp/rust.tar.gz \
    && echo "$RUST_1_DOWNLOAD_SHA256 /tmp/rust.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/rust.tar.gz -C /tmp \
    && /tmp/rust-${RUST_1_VERSION}-aarch64-unknown-linux-gnu/install.sh --prefix=/usr \
    && rm -rf /tmp/* /var/tmp/*

#**************** END RUST *****************************************************

#=======================End of layer: runtimes_1  =================
FROM runtimes_1 AS runtimes_2

#Docker 19
ENV DOCKER_BUCKET="download.docker.com" \
    DOCKER_CHANNEL="stable" \
    DIND_COMMIT="3b5fac462d21ca164b3778647420016315289034"

ENV DOCKER_SHA256="0259f8b6572f02cf0dafd7388ca0e4adfdbbfaba81cfb1b7443e89fccbed22c7"
ENV DOCKER_VERSION="20.10.9"

VOLUME /var/lib/docker

# Install Docker
RUN set -ex \
    && curl -fSL "https://${DOCKER_BUCKET}/linux/static/${DOCKER_CHANNEL}/aarch64/docker-${DOCKER_VERSION}.tgz" -o docker.tgz \
    && echo "${DOCKER_SHA256} *docker.tgz" | sha256sum -c - \
    && tar --extract --file docker.tgz --strip-components 1  --directory /usr/local/bin \
    && rm docker.tgz \
    && docker -v \
    # set up subuid/subgid so that "--userns-remap=default" works out-of-the-box
    && groupadd dockremap \
    && useradd -g dockremap dockremap \
    && echo 'dockremap:165536:65536' >> /etc/subuid \
    && echo 'dockremap:165536:65536' >> /etc/subgid \
    && wget -q "https://raw.githubusercontent.com/docker/docker/${DIND_COMMIT}/hack/dind" -O /usr/local/bin/dind \
    && chmod +x /usr/local/bin/dind

#Python 3.8
ENV PYTHON_38_VERSION="3.8.10"

COPY tools/runtime_configs/python/$PYTHON_38_VERSION /root/.pyenv/plugins/python-build/share/python-build/$PYTHON_38_VERSION
RUN   env PYTHON_CONFIGURE_OPTS="--enable-shared" pyenv install $PYTHON_38_VERSION; rm -rf /tmp/*
RUN   pyenv global  $PYTHON_38_VERSION
RUN set -ex \
    && pip3 install --no-cache-dir --upgrade --force-reinstall "pip==$PYTHON_PIP_VERSION" \
    && pip3 install --no-cache-dir --upgrade "PyYAML==$PYYAML_VERSION" \
    && pip3 install --no-cache-dir --upgrade 'setuptools==57.4.0' wheel aws-sam-cli awscli boto3 pipenv virtualenv \
    && pip3 install --no-cache-dir "docker-compose==$DOCKER_COMPOSE_VERSION" \
    && docker-compose version

#Python 3.9
ENV PYTHON_39_VERSION="3.9.5"

COPY tools/runtime_configs/python/$PYTHON_39_VERSION /root/.pyenv/plugins/python-build/share/python-build/$PYTHON_39_VERSION
RUN   env PYTHON_CONFIGURE_OPTS="--enable-shared" pyenv install $PYTHON_39_VERSION; rm -rf /tmp/*
RUN   pyenv global  $PYTHON_39_VERSION
RUN set -ex \
    && pip3 install --no-cache-dir --upgrade --force-reinstall "pip==$PYTHON_PIP_VERSION" \
    && pip3 install --no-cache-dir --upgrade "PyYAML==$PYYAML_VERSION" \
    && pip3 install --no-cache-dir --upgrade 'setuptools==57.4.0' wheel aws-sam-cli awscli boto3 pipenv virtualenv \
    && pip3 install --no-cache-dir "docker-compose==$DOCKER_COMPOSE_VERSION" \
    && docker-compose version

# Node 12
ENV NODE_12_VERSION="12.22.2"

RUN  n $NODE_12_VERSION && npm install --save-dev -g -f grunt && npm install --save-dev -g -f grunt-cli && npm install --save-dev -g -f webpack \
     && rm -rf /tmp/*

#=======================End of layer: runtimes_2  =================
FROM runtimes_2 AS aarch64_v2

# Configure SSH
COPY ssh_config /root/.ssh/config
COPY runtimes.yml /codebuild/image/config/runtimes.yml
COPY dockerd-entrypoint.sh /usr/local/bin/
COPY legal/THIRD_PARTY_LICENSES.txt /usr/share/doc
COPY legal/bill_of_material.txt     /usr/share/doc
COPY amazon-ssm-agent.json          /etc/amazon/ssm/

ENTRYPOINT ["dockerd-entrypoint.sh"]

#=======================End of layer: aarch64_v2  =================
