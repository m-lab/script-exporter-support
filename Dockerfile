FROM debian:stretch-slim

# Install necessary packages
RUN apt-get update
RUN apt-get install --yes curl git gnupg golang iproute2 sudo 
RUN curl -sL https://deb.nodesource.com/setup_9.x | sudo -E bash -
RUN apt-get install --yes nodejs
RUN npm install minimist ws

# Clone necessary git repos
RUN git clone https://github.com/m-lab/operator.git /opt/mlab/operator
RUN git clone https://github.com/m-lab/ndt.git /opt/mlab/ndt

COPY apply_tc_rules.sh /bin/apply_tc_rules.sh
COPY ndt_e2e.sh /bin/ndt_e2e.sh
COPY script_exporter.yml /etc/script_exporter/config.yml

# Apply traffic shaping rules
RUN /bin/apply_tc_rules.sh

EXPOSE 9172
ENTRYPOINT [ "/root/go/bin/script_exporter" ]
CMD [ "-config.file=/etc/script_exporter/config.yml" ]
