FROM xufan6/dragonwell8:8
LABEL maintainer="xufan6@gmail.com"

ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
RUN mkdir -p "$CATALINA_HOME"
WORKDIR $CATALINA_HOME

ENV ALI_TOMCAT_VERSION=7.0.92 \
    ALI_TOMCAT_SHA512=2934408cd3a0ec7fc158e0c0f2e7ca1bf5a27d0dba0643955efa28ba03b68025c5968cd262528e2f1c61366f828d6c3f1a20d8a5feb528cf7bfbb9b2518aed07 \
    EDAS_CONTAINER_VERSION=V3.5.4 \
    EDAS_CONTAINER_SHA512=57beb2e74e75607047ff28eb73d6551a60c4a1deb7526fcda0f1525cddcb3d3341e2d9af33303de1dad96149c810fcdc7a6770cc919117d0042705555178820d

ENV ALI_TOMCAT_TGZ_URL="https://edas-hz.oss-cn-hangzhou.aliyuncs.com/edas-container/$ALI_TOMCAT_VERSION/taobao-tomcat-production-$ALI_TOMCAT_VERSION.tar.gz" \
    EDAS_CONTAINER_TGZ_URL="https://edas-hz.oss-cn-hangzhou.aliyuncs.com/edas-plugins/edas.sar.${EDAS_CONTAINER_VERSION}/taobao-hsf.tgz"

RUN set -eux; \
# Ali Tomcat, see https://help.aliyun.com/document_detail/84095.html
    curl -L -o tomcat.tar.gz $ALI_TOMCAT_TGZ_URL; \
    echo "$ALI_TOMCAT_SHA512 *tomcat.tar.gz" | sha512sum --strict --check -; \
    tar -xvf tomcat.tar.gz --strip-components=1; \
    rm bin/*.bat; \
    rm tomcat.tar.gz*; \
    sed -i -e 's/appBase="deploy"/appBase="webapps"/g' conf/server.xml; \
    sed -i -e 's:/deploy/taobao-hsf.sar:/webapps/taobao-hsf.sar:g' conf/catalina.policy; \
    sed -i -e 's/.log.$/./g' conf/logging.properties; \
# sh removes env vars it doesn't support (ones with periods)
# https://github.com/docker-library/tomcat/issues/77
    find ./bin/ -name '*.sh' -exec sed -ri 's|^#!/bin/sh$|#!/usr/bin/env bash|' '{}' +; \
# Edas Container, see https://help.aliyun.com/document_detail/92614.html
    curl -L -o taobao-hsf.tgz $EDAS_CONTAINER_TGZ_URL; \
    echo "$EDAS_CONTAINER_SHA512 taobao-hsf.tgz" | sha512sum --strict --check -; \
    tar -xvf taobao-hsf.tgz -C webapps/; \
    rm taobao-hsf.tgz; \
# fix permissions (especially for running as non-root)
# https://github.com/docker-library/tomcat/issues/35
    chmod -R +rX .; \
    chmod 777 logs work; \
    exit 0

EXPOSE 12200 12201 8006 8204 8005 8080
CMD ["catalina.sh", "run"]
