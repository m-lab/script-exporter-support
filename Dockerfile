FROM alpine:3.7

RUN apk add --update nodejs nodejs-npm go
RUN npm init --yes
RUN npm install minimist ws

COPY ndt_client.js /bin/ndt_client.js
COPY ndt_e2e.sh /bin/ndt_e2e.sh
COPY script-exporter /bin/script_exporter
COPY script-exporter.yml /etc/script-exporter/config.yml

EXPOSE 9172
ENTRYPOINT [ "/bin/script_exporter" ]
CMD [ "-config.file=/etc/script-exporter/config.yml" ]
