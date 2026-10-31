FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf automake build-essential ca-certificates clang cmake curl \
    gettext git libclang-dev libssl-dev libtool libva-dev libx11-dev \
    libxext-dev libxfixes-dev llvm-dev nasm ninja-build \
    openjdk-17-jdk-headless openssl patch perl pkg-config python3 unzip \
    wget xz-utils zip \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/gadesk/build/source
ENTRYPOINT ["bash", "/opt/gadesk/build/source/deploy/gadesk/build-android.sh"]
