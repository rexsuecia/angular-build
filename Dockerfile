FROM node:8.9.4

### Unzip was added for terraform install
### Do we need python dev to start with?
### jq is used to parse package.json

RUN apt-get update && \
    apt-get dist-upgrade -y -q && \
    apt-get install -y -q apt-transport-https  && \
    apt-key adv \
        --keyserver hkp://keyserver.ubuntu.com:80 \
        --recv-keys 58118E89F3A912897C070ADBF76221572C52609D && \
    echo "deb https://apt.dockerproject.org/repo debian-jessie main" > \
                /etc/apt/sources.list.d/docker.list && \
    apt-get update  && \
    apt-get -y -qq install wget \
          python-dev \
          python-pip \
          vim \
          jq && \
    pip install -q awscli && \
    apt-get purge -y -q python-dev && \
    apt-get autoremove -y

RUN  curl -sL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
     -o google-chrome-stable_current_amd64.deb && \
     dpkg -i google-chrome-stable_current_amd64.deb || \
     apt-get install -f -y && \
     apt-get autoremove -y

RUN echo "deb https://deb.debian.org/debian stretch main" > \
                        /etc/apt/sources.list && \
        apt-get update  && \
        apt-get -y -qq install shellcheck


# Get us the latest version of yarn
RUN npm i -g yarn

COPY ./scripts/*.sh /usr/local/bin
RUN chmod +x /usr/local/bin/*.sh



