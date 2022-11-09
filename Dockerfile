# Dockerfile - alpine
# https://github.com/openresty/docker-openresty

FROM alpine:3.12

ARG RESTY_VERSION="1.17.8.2"
ARG RESTY_LIBRESSL_VERSION="3.3.3"
ARG RESTY_PCRE_VERSION="8.45"
ARG RESTY_J="1"
ARG RESTY_CONFIG_OPTIONS="\
    --with-http_stub_status_module \
    --with-http_realip_module \
    --with-http_ssl_module \
    --with-http_v2_module \
    --with-pcre-jit \
    --with-stream \
    --with-stream_ssl_preread_module \
    "
ARG RESTY_CONFIG_OPTIONS_MORE=""
ARG _RESTY_CONFIG_DEPS="--with-openssl=/usr/src/boringssl --with-pcre=/tmp/pcre-${RESTY_PCRE_VERSION} --with-cc-opt=-I'/usr/src/boringssl/.openssl/include/'"

RUN apk add --no-cache --virtual .build-deps \
        build-base \
        linux-headers \
        make \
        cmake \
        libunwind \
        go \
        readline-dev \
        zlib-dev \
        xz \
        coreutils \
    && apk add --no-cache \
        libgcc \
        zlib \
        curl \
        iproute2 \
        perl \
    && cd /tmp \
    && git clone --depth 1 https://boringssl.googlesource.com/boringssl "/usr/src/boringssl" \
    && mkdir "/usr/src/boringssl/build/" \
    && cd "/usr/src/boringssl/build/" \
    && cmake -DCMAKE_BUILD_TYPE=Release ../ \
    && make -j$(getconf _NPROCESSORS_ONLN) \
    && mkdir -p "/usr/src/boringssl/.openssl/lib" \
    && cd "/usr/src/boringssl/.openssl" \
    && ln -s ../include \
    && cd "/usr/src/boringssl" \
    && cp "build/crypto/libcrypto.a" "build/ssl/libssl.a" ".openssl/lib" \
    && curl -fSL https://sourceforge.net/projects/pcre/files/pcre/${RESTY_PCRE_VERSION}/pcre-${RESTY_PCRE_VERSION}.tar.gz/download -o pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && tar xzf pcre-${RESTY_PCRE_VERSION}.tar.gz \
    && curl -fSL https://openresty.org/download/openresty-${RESTY_VERSION}.tar.gz -o openresty-${RESTY_VERSION}.tar.gz \
    && tar xzf openresty-${RESTY_VERSION}.tar.gz \
    && cd /tmp/openresty-${RESTY_VERSION} \
    && ./configure -j${RESTY_J} ${_RESTY_CONFIG_DEPS} ${RESTY_CONFIG_OPTIONS} ${RESTY_CONFIG_OPTIONS_MORE} \
    && make -j${RESTY_J} \
    && make -j${RESTY_J} install \
    && curl -fSL http://www.over-yonder.net/~fullermd/projects/libcidr/libcidr-1.2.3.tar.xz -o /tmp/libcidr-1.2.3.tar.xz \
    && xz -d /tmp/libcidr-1.2.3.tar.xz && tar -xvf /tmp/libcidr-1.2.3.tar \
    #&& cd libcidr-1.2.3 && make && mv libcidr.so /usr/local/openresty/lualib/libcidr.so && cd /tmp \
    && cd libcidr-1.2.3 && make && make install && cd /tmp \
    && cd /tmp \
    && rm -rf \
        libressl-${RESTY_LIBRESSL_VERSION}.tar.gz libressl-${RESTY_LIBRESSL_VERSION} \
        openresty-${RESTY_VERSION}.tar.gz openresty-${RESTY_VERSION} \
        pcre-${RESTY_PCRE_VERSION}.tar.gz pcre-${RESTY_PCRE_VERSION} \
        libcidr-1.2.3.tar libcidr-1.2.3.tar.xz libcidr-1.2.3 \
    && apk del .build-deps \
    && ln -sf /dev/stdout /usr/local/openresty/nginx/logs/access.log \
    && ln -sf /dev/stderr /usr/local/openresty/nginx/logs/error.log

ENV PATH=$PATH:/usr/local/openresty/luajit/bin:/usr/local/openresty/nginx/sbin:/usr/local/openresty/bin
RUN rm -rf /usr/src/boringssl/build
RUN opm get bungle/lua-resty-template ledgetech/lua-resty-http GUI/lua-libcidr-ffi
CMD ["/usr/local/openresty/bin/openresty", "-g", "daemon off;"]
