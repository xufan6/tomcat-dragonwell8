FROM xufan6/dragonwell8:8.0.0-GA AS base
LABEL maintainer="xufan6@gmail.com"

ENV CATALINA_HOME /usr/local/tomcat
ENV PATH $CATALINA_HOME/bin:$PATH
RUN mkdir -p "$CATALINA_HOME"
WORKDIR $CATALINA_HOME

# let "Tomcat Native" live somewhere isolated
ENV TOMCAT_NATIVE_LIBDIR $CATALINA_HOME/native-jni-lib
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}$TOMCAT_NATIVE_LIBDIR

ENV TOMCAT_MAJOR=8 \
    TOMCAT_VERSION=8.5.42 \
    TOMCAT_SHA512=3e6b38e48d315d142e96f8e3809c86632f3c3903f8751c6602581a587edf840893ff0c737a65fcf9560a495b0118b5b8d60d4d1ce7947fe2abe34a89839b640f
ENV TOMCAT_TGZ_URLS \
# https://issues.apache.org/jira/browse/INFRA-8753?focusedCommentId=14735394#comment-14735394
    https://www.apache.org/dyn/closer.cgi?action=download&filename=tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
# if the version is outdated, we might have to pull from the dist/archive :/
    https://www-us.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
    https://www.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz \
    https://archive.apache.org/dist/tomcat/tomcat-$TOMCAT_MAJOR/v$TOMCAT_VERSION/bin/apache-tomcat-$TOMCAT_VERSION.tar.gz

RUN set -eux; \
    success=; \
    for url in $TOMCAT_TGZ_URLS; do \
        if curl -L -o tomcat.tar.gz "$url"; then \
            success=1; \
            break; \
        fi; \
    done; \
    [ -n "$success" ]; \
    \
    echo "$TOMCAT_SHA512 *tomcat.tar.gz" | sha512sum -c -; \
    tar -xvf tomcat.tar.gz --strip-components=1; \
    rm bin/*.bat; \
    rm tomcat.tar.gz*; \
# sh removes env vars it doesn't support (ones with periods)
# https://github.com/docker-library/tomcat/issues/77
    find ./bin/ -name '*.sh' -exec sed -ri 's|^#!/bin/sh$|#!/usr/bin/env bash|' '{}' +; \
# fix permissions (especially for running as non-root)
# https://github.com/docker-library/tomcat/issues/35
    chmod -R +rX .; \
    chmod 777 logs work; \
    exit 0

FROM base AS build
RUN set -eux; \
# install native
    nativeBuildDir="$(mktemp -d)"; \
    tar -xvf bin/tomcat-native.tar.gz -C "$nativeBuildDir" --strip-components=1; \
    yum install -y apr-devel openssl-devel make gcc; \
    ( \
        export CATALINA_HOME="$PWD"; \
        cd "$nativeBuildDir/native"; \
        ./configure \
            --libdir="$TOMCAT_NATIVE_LIBDIR" \
            --prefix="$CATALINA_HOME" \
            --with-apr="/usr/bin/apr-1-config" \
            --with-java-home="$JAVA_HOME" \
            --with-ssl=yes; \
        make -j "$(nproc)"; \
        make install; \
    ); \
    rm -rf "$nativeBuildDir"; \
    rm bin/tomcat-native.tar.gz; \
    mkdir target && mv include native-jni-lib target; \
# fix permissions (especially for running as non-root)
# https://github.com/docker-library/tomcat/issues/35
    chmod -R +rX .; \
    exit 0

FROM base AS prod
COPY --from=build /usr/local/tomcat/target /usr/local/tomcat/
COPY --from=build /lib64/libapr-1.so.0 /lib64/libapr-1.so.0
# verify Tomcat Native is working properly
RUN set -e \
    && nativeLines="$(catalina.sh configtest 2>&1)" \
    && nativeLines="$(echo "$nativeLines" | grep 'Apache Tomcat Native')" \
    && nativeLines="$(echo "$nativeLines" | sort -u)" \
    && if ! echo "$nativeLines" | grep 'INFO: Loaded APR based Apache Tomcat Native library' >&2; then \
        echo >&2 "$nativeLines"; \
        exit 1; \
    fi

EXPOSE 8080
CMD ["catalina.sh", "run"]
