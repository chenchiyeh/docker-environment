# syntax=docker/dockerfile:1

# Requirement 1 - Minimal Ubuntu Base image
FROM ubuntu:26.04 AS base

# Requirement 2 - Environment settings in Base image
ENV TZ=Asia/Taipei
ENV DEBIAN_FRONTEND=noninteractive

# Install timezone 
RUN apt-get update && apt-get install -y --no-install-recommends tzdata \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime \
    && echo $TZ > /etc/timezone

# Create non-root user 
ARG UID=2414
ARG GID=2414

RUN groupadd -g $GID customgroup \
    && useradd -m -u $UID -g customgroup customuser

#Requirement 3 - Multistage
# Stage common_pkg_provider 
FROM base AS common_pkg_provider

# Install core packages 
RUN apt-get update && apt-get install -y --no-install-recommends \
    vim \
    git \
    curl \
    wget \
    ca-certificates \
    build-essential \
    python3 \
    python3-pip

RUN ln -s /usr/bin/python3 /usr/bin/python || true

# Stage verilator_provider
FROM common_pkg_provider AS verilator_provider

RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    flex \
    bison \
    libfl-dev \
    help2man \
    perl

RUN git clone https://github.com/verilator/verilator.git /opt/verilator

#config and install
WORKDIR /opt/verilator
RUN autoconf && \
    ./configure && \
    make -j$(nproc) && \
    make install


# Stage systemc_provider
FROM verilator_provider AS systemc_provider

RUN apt-get update && apt-get install -y --no-install-recommends \
    tar \
    cmake \
    make

WORKDIR /opt

RUN wget -O systemc-2.3.4.tar.gz \
    https://github.com/accellera-official/systemc/archive/refs/tags/2.3.4.tar.gz
RUN tar -xzf systemc-2.3.4.tar.gz && \
    mv systemc-2.3.4 systemc

WORKDIR /opt/systemc

RUN mkdir build

WORKDIR /opt/systemc/build

# Configure the build 
RUN cmake .. \
    -DCMAKE_INSTALL_PREFIX=/opt/systemc \
    -DCMAKE_CXX_STANDARD=17 \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5

# Build and install
RUN make -j$(nproc)
RUN make install

ENV SYSTEMC_HOME=/opt/systemc
ENV LD_LIBRARY_PATH=/opt/systemc/lib:$LD_LIBRARY_PATH
ENV SYSTEMC_CXXFLAGS="-I$SYSTEMC_HOME/include"
ENV SYSTEMC_LDFLAGS="-L$SYSTEMC_HOME/lib -lsystemc"

USER customuser

# Stage release
FROM ubuntu:26.04 AS release

RUN apt-get update && apt-get install -y --no-install-recommends \
    perl \
    libfindbin-libs-perl \
    ca-certificates \
    libstdc++6 \
    g++ \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

COPY --from=systemc_provider /opt/systemc /opt/systemc
COPY --from=verilator_provider /usr/local /usr/local

# Environment setup
ENV SYSTEMC_HOME=/opt/systemc
ENV PATH=/usr/local/bin:$PATH

ENV LD_LIBRARY_PATH=/opt/systemc/lib:/opt/systemc/lib-linux64:$LD_LIBRARY_PATH

ENV SYSTEMC_CXXFLAGS="-I/opt/systemc/include"
ENV SYSTEMC_LDFLAGS="-L/opt/systemc/lib -lsystemc"

ARG UID=2414
ARG GID=2414

RUN groupadd -g $GID customgroup \
    && useradd -m -u $UID -g customgroup customuser

USER customuser
WORKDIR /home/customuser