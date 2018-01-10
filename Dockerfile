FROM debian:stretch-slim

# Install necessary packages
RUN apt-get update -qq
RUN apt-get install -qq curl dnsutils git gnupg golang iproute2 sudo 

# Setup and install Node.js, npm and required modules
RUN curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | apt-key add -
RUN echo "deb https://deb.nodesource.com/node_9.x stretch main" > /etc/apt/sources.list.d/nodesource.list
RUN apt-get update -qq
RUN apt-get install -qq nodejs
RUN npm install --global --quiet minimist ws

# Clone necessary git repos
RUN git clone https://github.com/m-lab/operator.git /opt/mlab/operator
RUN git clone https://github.com/m-lab/ndt.git /opt/mlab/ndt

# Fetch and build script_exporter
RUN GOPATH=/root/go go get github.com/nkinkade/script_exporter

# Copy scripts and configs
COPY apply_tc_rules.sh /bin/apply_tc_rules.sh
COPY ndt_e2e.sh /bin/ndt_e2e.sh
COPY script_exporter.yml /etc/script_exporter/config.yml

# Launch script_exporter, first running apply_tc_rules.sh
EXPOSE 9172
ENTRYPOINT /bin/apply_tc_rules.sh && /root/go/bin/script_exporter -config.file=/etc/script_exporter/config.yml
