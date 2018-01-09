FROM debian:stretch-slim

RUN apt-get update
RUN apt-get install sudo curl gnupg git iproute2
RUN curl -sL https://deb.nodesource.com/setup_9.x | sudo -E bash -
RUN apt-get install nodejs
RUN npm install minimist ws

COPY ndt/src/node_tests/ndt_client.js /bin/ndt_client.js
COPY ndt_e2e.sh /bin/ndt_e2e.sh
COPY script_exporter /bin/script_exporter
COPY script-exporter.yml /etc/script-exporter/config.yml

EXPOSE 9172
ENTRYPOINT [ "/bin/script_exporter" ]
CMD [ "-config.file=/etc/script-exporter/config.yml" ]
