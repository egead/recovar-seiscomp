FROM --platform=linux/amd64 ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV SEISCOMP_ROOT=/root/seiscomp
ENV PATH=/usr/bin:/root/seiscomp/bin:/root/recovar-seiscomp/bin:$PATH
ENV LD_LIBRARY_PATH=/root/seiscomp/lib
ENV PYTHONPATH=/root/seiscomp/lib/python:/root/recovar:/root/recovar/seiscomp_integration

RUN apt-get update && apt-get install -y \
        python3.10 python3.10-venv python3.10-dev \
        libboost-program-options1.74.0 \
        libboost-iostreams1.74.0 \
        libboost-filesystem1.74.0 \
        libboost-thread1.74.0 \
        libboost-system1.74.0 \
        libboost-regex1.74.0 \
        libboost-date-time1.74.0 \
        libxml2 libpython3.10 \
        mariadb-server mariadb-client \
        python3-pip \
        openssh-server \
        curl ca-certificates procps net-tools \
    && rm -rf /var/lib/apt/lists/*

# SSH access (local dev container): root login with password "recovar".
RUN mkdir -p /run/sshd \
    && echo 'root:recovar' | chpasswd \
    && sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

RUN python3.10 -m pip install "numpy==1.26.0" \
    && python3.10 -c "import numpy; print('system numpy', numpy.__version__)"

COPY seiscomp-7.*-ubuntu22.04-x86_64.* /tmp/seiscomp.archive
RUN tar xaf /tmp/seiscomp.archive -C /root/ && rm /tmp/seiscomp.archive

RUN python3.10 -m venv /root/recovar-seiscomp \
    && /root/recovar-seiscomp/bin/pip install --quiet --upgrade pip \
    && /root/recovar-seiscomp/bin/pip install --quiet \
        tensorflow==2.14.0 numpy==1.26.0 scipy obspy pymysql matplotlib

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 22

ENTRYPOINT ["/entrypoint.sh"]
