FROM debian:stretch-slim

# Install necessary packages
RUN apt-get update
RUN apt-get install --yes sudo curl gnupg git iproute2
RUN curl -sL https://deb.nodesource.com/setup_9.x | sudo -E bash -
RUN apt-get install --yes nodejs
RUN npm install minimist ws

# Clone necessary git repos
RUN git clone https://github.com/m-lab/operator.git
RUN git clone https://github.com/m-lab/ndt.git

COPY ndt_e2e.sh /bin/ndt_e2e.sh
COPY script_exporter /bin/script_exporter
COPY script-exporter.yml /etc/script-exporter/config.yml

EXPOSE 9172
ENTRYPOINT [ "/bin/script_exporter" ]
CMD [ "-config.file=/etc/script-exporter/config.yml" ]
