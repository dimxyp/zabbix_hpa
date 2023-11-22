FROM alpine:3.12

LABEL org.opencontainers.image.title="Zabbix agent 2" \
      org.opencontainers.image.authors="Alexey Pustovalov <alexey.pustovalov@zabbix.com>" \
      org.opencontainers.image.vendor="Zabbix LLC" \
      org.opencontainers.image.url="https://zabbix.com/" \
      org.opencontainers.image.description="Zabbix agent 2 is deployed on a monitoring target to actively monitor local resources and applications" \
      org.opencontainers.image.licenses="GPL v2.0"

STOPSIGNAL SIGTERM

RUN set -eux && \
    addgroup -S -g 1995 zabbix && \
    adduser -S \
            -D -G zabbix -G root \
            -u 1997 \
            -h /var/lib/zabbix/ \
        zabbix && \
    mkdir -p /etc/zabbix && \
    mkdir -p /etc/zabbix/zabbix_agentd.d && \
    mkdir -p /var/lib/zabbix && \
    mkdir -p /var/lib/zabbix/enc && \
    mkdir -p /var/lib/zabbix/modules && \
    apk add --no-cache --clean-protected \
            tini \
            tzdata \
            bash \
            pcre \
            coreutils \
            iputils && \
    rm -rf /var/cache/apk/*

ARG MAJOR_VERSION=5.0
ARG ZBX_VERSION=${MAJOR_VERSION}.3
ARG ZBX_SOURCES=https://git.zabbix.com/scm/zbx/zabbix.git

ENV TERM=xterm ZBX_VERSION=${ZBX_VERSION} ZBX_SOURCES=${ZBX_SOURCES}

LABEL org.opencontainers.image.documentation="https://www.zabbix.com/documentation/${MAJOR_VERSION}/manual/installation/containers" \
      org.opencontainers.image.version="${ZBX_VERSION}" \
      org.opencontainers.image.source="${ZBX_SOURCES}"

RUN set -eux && \
    apk add --no-cache --virtual build-dependencies \
            autoconf \
            automake \
            go \
            g++ \
            make \
            git \
            pcre-dev \
            openssl-dev \
            zlib-dev \
            coreutils && \
    cd /tmp/ && \
    git clone ${ZBX_SOURCES} --branch ${ZBX_VERSION} --depth 1 --single-branch zabbix-${ZBX_VERSION} && \
    cd /tmp/zabbix-${ZBX_VERSION} && \
    zabbix_revision=`git rev-parse --short HEAD` && \
    sed -i "s/{ZABBIX_REVISION}/$zabbix_revision/g" src/go/pkg/version/version.go && \
    ./bootstrap.sh && \
    export CFLAGS="-fPIC -pie -Wl,-z,relro -Wl,-z,now" && \
    export GOPATH=/tmp/zabbix-${ZBX_VERSION}/go && \
    ./configure \
            --datadir=/usr/lib \
            --libdir=/usr/lib/zabbix \
            --prefix=/usr \
            --sysconfdir=/etc/zabbix \
            --prefix=/usr \
            --with-openssl \
            --enable-ipv6 \
            --enable-agent2 \
            --enable-agent \
            --silent && \
    make -j"$(nproc)" -s && \
    cp /tmp/zabbix-${ZBX_VERSION}/src/go/bin/zabbix_agent2 /usr/sbin/zabbix_agent2 && \
    cp /tmp/zabbix-${ZBX_VERSION}/src/zabbix_get/zabbix_get /usr/bin/zabbix_get && \
    cp /tmp/zabbix-${ZBX_VERSION}/src/zabbix_sender/zabbix_sender /usr/bin/zabbix_sender && \
    cp /tmp/zabbix-${ZBX_VERSION}/src/go/conf/zabbix_agent2.conf /etc/zabbix/zabbix_agent2.conf && \
    cd /tmp/ && \
    rm -rf /tmp/zabbix-${ZBX_VERSION}/ && \
    chown --quiet -R zabbix:root /etc/zabbix/ /var/lib/zabbix/ && \
    chgrp -R 0 /etc/zabbix/ /var/lib/zabbix/ && \
    chmod -R g=u /etc/zabbix/ /var/lib/zabbix/ && \
    apk del --purge --no-network \
            build-dependencies && \
    rm -rf /var/cache/apk/*

EXPOSE 10050/TCP 31999/TCP

#Azure and kubectl
# Install Azure CLI
RUN apk add py3-pip gcc musl-dev python3-dev libffi-dev openssl-dev cargo make curl
RUN pip install --upgrade pip
RUN pip install azure-cli
# Install kubectl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl \
    && chmod +x ./kubectl \
    && mv ./kubectl /usr/local/bin/kubectl
# Config Azure CLI
RUN az login --service-principal --username "7af45c88-b300-4e6d-a5a2-c480ef6a8105" --password "1QL8Q~FilrpsQ-9OFxlYhbKVyGh2I6b~q_C5DbFK" --tenant "b11b0e93-0aec-47ed-bbaf-fc3e014e0b35"
RUN az aks get-credentials --resource-group Eurolife_AKS_RG --name Eurolife_AKS_Prod

#Custom UserParameter
#RUN mkdir -p /etc/zabbix/zabbix_agent.d
#replicas custom
RUN echo 'UserParameter=connect.replicas,kubectl get HorizontalPodAutoscaler -n prod connect -o=jsonpath='{.status.currentReplicas}'' > /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=haproxy-connect.replicas,kubectl get HorizontalPodAutoscaler -n prod haproxy-connect -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=agent.replicas,kubectl get HorizontalPodAutoscaler -n prod agent -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=dash.replicas,kubectl get HorizontalPodAutoscaler -n prod dash -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=enterprise.replicas,kubectl get HorizontalPodAutoscaler -n prod enterprise -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=health.replicas,kubectl get HorizontalPodAutoscaler -n prod health -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=life.replicas,kubectl get HorizontalPodAutoscaler -n prod life -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=motor.replicas,kubectl get HorizontalPodAutoscaler -n prod motor -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=nginx.replicas,kubectl get HorizontalPodAutoscaler -n prod nginx -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=notif.replicas,kubectl get HorizontalPodAutoscaler -n prod notif -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=other.replicas,kubectl get HorizontalPodAutoscaler -n prod other -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=property.replicas,kubectl get HorizontalPodAutoscaler -n prod property -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=rda.replicas,kubectl get HorizontalPodAutoscaler -n prod rda -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=renewals.replicas,kubectl get HorizontalPodAutoscaler -n prod renewals -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo 'UserParameter=shared.replicas,kubectl get HorizontalPodAutoscaler -n prod shared -o=jsonpath='{.status.currentReplicas}'' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
#all info HPA
RUN echo 'UserParameter=prod.hpa,kubectl get HorizontalPodAutoscaler -n prod' >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
# #cpu on pods
RUN echo "UserParameter=connect.cpu,kubectl get HorizontalPodAutoscaler -n prod connect -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=haproxy-connect.cpu,kubectl get HorizontalPodAutoscaler -n prod haproxy-connect -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=agent.cpu,kubectl get HorizontalPodAutoscaler -n prod agent -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=dash.cpu,kubectl get HorizontalPodAutoscaler -n prod dash -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=enterprise.cpu,kubectl get HorizontalPodAutoscaler -n prod enterprise -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=health.cpu,kubectl get HorizontalPodAutoscaler -n prod health -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=motor.cpu,kubectl get HorizontalPodAutoscaler -n prod motor -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=nginx.cpu,kubectl get HorizontalPodAutoscaler -n prod nginx -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=notif.cpu,kubectl get HorizontalPodAutoscaler -n prod notif -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=other.cpu,kubectl get HorizontalPodAutoscaler -n prod other -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=property.cpu,kubectl get HorizontalPodAutoscaler -n prod property -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=rda.cpu,kubectl get HorizontalPodAutoscaler -n prod rda -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=renewals.cpu,kubectl get HorizontalPodAutoscaler -n prod renewals -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=shared.cpu,kubectl get HorizontalPodAutoscaler -n prod shared -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$4}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
# #memory on pods
RUN echo "UserParameter=connect.memory,kubectl get HorizontalPodAutoscaler -n prod connect -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=haproxy-connect.memory,kubectl get HorizontalPodAutoscaler -n prod haproxy-connect -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=agent.memory,kubectl get HorizontalPodAutoscaler -n prod agent -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=dash.memory,kubectl get HorizontalPodAutoscaler -n prod dash -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=enterprise.memory,kubectl get HorizontalPodAutoscaler -n prod enterprise -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=health.memory,kubectl get HorizontalPodAutoscaler -n prod health -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=motor.memory,kubectl get HorizontalPodAutoscaler -n prod motor -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=nginx.memory,kubectl get HorizontalPodAutoscaler -n prod nginx -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=notif.memory,kubectl get HorizontalPodAutoscaler -n prod notif -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=other.memory,kubectl get HorizontalPodAutoscaler -n prod other -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=property.memory,kubectl get HorizontalPodAutoscaler -n prod property -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=rda.memory,kubectl get HorizontalPodAutoscaler -n prod rda -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=renewals.memory,kubectl get HorizontalPodAutoscaler -n prod renewals -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 
RUN echo "UserParameter=shared.memory,kubectl get HorizontalPodAutoscaler -n prod shared -o=jsonpath='{range .status.currentMetrics[?(@.type==\"Resource\")].resource}{.name}{\"\t\"}{.current.averageUtilization}{\"%\t\"}{end}' | awk '{print \$2}' | sed 's/%//'" >> /etc/zabbix/zabbix_agentd.d/hpa-config.conf 

RUN echo '#!/bin/sh' > /etc/zabbix/zabbix_agentd.d/hpa-execute.sh \
     && echo 'process_count=$(ls /etc | wc -l)' >> /etc/zabbix/zabbix_agentd.d/hpa-execute.sh \
     && echo 'echo $process_count' >> /etc/zabbix/zabbix_agentd.d/hpa-execute.sh 
RUN chmod +x /etc/zabbix/zabbix_agentd.d/hpa-execute.sh 
#RUN echo 'UserParameter=static,/usr/sbin/zabbix_agent2 -V' >> /etc/zabbix/zabbix_agent2.conf

WORKDIR /var/lib/zabbix

VOLUME ["/var/lib/zabbix/enc"]

COPY ["docker-entrypoint.sh", "/usr/bin/"]
RUN chmod +x /usr/bin/docker-entrypoint.sh
RUN mkdir -p /etc/zabbix/zabbix_agent2.d/plugins.d/
ENTRYPOINT ["/sbin/tini", "--", "/usr/bin/docker-entrypoint.sh"]

USER 1997

CMD ["/usr/sbin/zabbix_agent2", "--foreground", "-c", "/etc/zabbix/zabbix_agent2.conf"]