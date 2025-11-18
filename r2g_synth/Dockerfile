FROM ubuntu:22.04

ENV TZ=Asia/Shanghai
ENV DEBIAN_FRONTEND=noninteractive

RUN ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime && \
    sed -i -e 's@//archive.ubuntu.com@//mirrors.tuna.tsinghua.edu.cn@g' \
    -e 's@//security.ubuntu.com@//mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list && \
    apt-get update && apt-get install -y wget

ARG OSS_CAD_SUITE_VERSION_1=2025-10-29
ARG OSS_CAD_SUITE_VERSION_2=20251029
ARG OSS_CAD_SUITE_URL=https://gh-proxy.com/https://github.com/YosysHQ/oss-cad-suite-build/releases/download/${OSS_CAD_SUITE_VERSION_1}/oss-cad-suite-linux-x64-${OSS_CAD_SUITE_VERSION_2}.tgz

RUN wget --no-check-certificate ${OSS_CAD_SUITE_URL} -O /tmp/oss-cad-suite.tar.gz && \
    tar -xzf /tmp/oss-cad-suite.tar.gz -C /opt

ENV PATH="/opt/oss-cad-suite/bin:$PATH"

ADD . /workdir
WORKDIR /workdir
