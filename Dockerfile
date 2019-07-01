FROM node:10.16-jessie

### Unzip was added for terraform install
### Do we need python dev to start with?
### jq is used to parse package.json
### Unzip to install sonar scanner.

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
          unzip \
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

# Install Terraform
RUN wget https://releases.hashicorp.com/terraform/0.11.13/terraform_0.11.13_linux_amd64.zip
RUN unzip terraform_0.11.13_linux_amd64.zip
RUN mv terraform /usr/local/bin/

# Install Sonar Cube
RUN curl -sL https://binaries.sonarsource.com/Distribution/sonar-scanner-cli/sonar-scanner-cli-3.2.0.1227-linux.zip -o /tmp/scanner.zip
RUN unzip /tmp/scanner.zip -d /usr/local/bin/sonar
ENV PATH="${PATH}:/usr/local/bin/sonar/sonar-scanner-3.2.0.1227-linux/bin"
RUN rm /tmp/scanner.zip


COPY ./scripts/*.sh /usr/local/bin
RUN chmod +x /usr/local/bin/*.sh




