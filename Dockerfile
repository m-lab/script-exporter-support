FROM debian:stretch-slim

# Install necessary packages
RUN apt-get update -qq && apt-get install -qq apt-transport-https cron curl dnsutils git gnupg golang iproute2 python sudo

# Setup Node.js repository, install nodejs, and any needed modules
RUN curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
RUN echo "deb https://deb.nodesource.com/node_0.12 jessie main" > /etc/apt/sources.list.d/nodesource.list
RUN apt-get update -qq && apt-get install -qq nodejs=0.12.18-1nodesource1~jessie1
RUN npm install --global --quiet minimist@1.2.0 ws@1.0.1

# Clone necessary git repos
RUN git clone https://github.com/m-lab/operator.git /opt/mlab/operator
RUN git clone https://github.com/m-lab/ndt.git /opt/mlab/ndt

# Fetch and build script_exporter
RUN GOPATH=/root/go go get github.com/m-lab/script_exporter

# Copy scripts and configs
COPY apply_tc_rules.sh /bin/apply_tc_rules.sh
COPY apply_tc_rules.cron /etc/cron.daily/apply_tc_rules
COPY ndt_e2e.sh /bin/ndt_e2e.sh
COPY script_exporter.yml /etc/script_exporter/config.yml

# First start cron, then run apply_tc_rules.sh, then script_exporter.
EXPOSE 9172
ENTRYPOINT service cron start && bin/apply_tc_rules.sh && /root/go/bin/script_exporter -config.file=/etc/script_exporter/config.yml
