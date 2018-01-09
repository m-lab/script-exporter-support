FROM debian:stretch

# Install necessary packages
RUN apt-get update --quiet=2
RUN apt-get install --yes --quiet=2 curl git gnupg golang iproute2 sudo 
RUN curl -sL https://deb.nodesource.com/setup_9.x | sudo -E bash -
RUN apt-get install --yes --quiet=2 nodejs
RUN npm install --global --quiet minimist ws

# Clone necessary git repos
RUN git clone https://github.com/m-lab/operator.git /opt/mlab/operator
RUN git clone https://github.com/m-lab/ndt.git /opt/mlab/ndt

COPY apply_tc_rules.sh /bin/apply_tc_rules.sh
COPY ndt_e2e.sh /bin/ndt_e2e.sh
COPY script_exporter.yml /etc/script_exporter/config.yml

EXPOSE 9172
ENTRYPOINT /bin/apply_tc_rules.sh && /root/go/bin/script_exporter -config.file=/etc/script_exporter/config.yml
