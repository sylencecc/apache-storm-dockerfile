ARG PHUSION_VERSION="bionic-1.0.0"
FROM phusion/baseimage:${PHUSION_VERSION}

LABEL description = "Apache Storm (all-in-one): zookeeper, nimbus, ui, supervisor"

# Args that can be changed from the command line
ARG GPG_KEY=79B03D059E628478FC9F1D8B152CAD0C46E87B61
ARG STORM_RELEASE=apache-storm-2.2.0

# Environment variables
ENV STORM_CONF_DIR=/conf \
    STORM_DATA_DIR=/data \
    STORM_LOG_DIR=/logs \
    PATH=$PATH:/opt/$STORM_RELEASE/bin

# Create directories
RUN set -ex; \
    mkdir -p "/etc/service/zookeeperd" "/etc/service/nimbus" "/etc/service/supervisor" "/etc/service/ui"; \
    mkdir -p "$STORM_CONF_DIR" "$STORM_DATA_DIR" "$STORM_LOG_DIR"; \
# Install dependencies
    apt-get -y update; \
    apt-get -y upgrade -o Dpkg::Options::="--force-confold"; \
    apt-get -y --no-install-recommends install openjdk-11-jre zookeeperd; \
# Set python3 as default interpreter
    update-alternatives --install /usr/bin/python python /usr/bin/python3 10; \
# Download Apache Storm, verify its PGP signature, untar and clean up
    curl -LSo "/tmp/$STORM_RELEASE.tar.gz" "https://downloads.apache.org/storm/$STORM_RELEASE/$STORM_RELEASE.tar.gz"; \
    curl -LSo "/tmp/$STORM_RELEASE.tar.gz.asc" "https://downloads.apache.org/storm/$STORM_RELEASE/$STORM_RELEASE.tar.gz.asc"; \
    export GNUPGHOME="$(mktemp -d)"; \
    # https://github.com/f-secure-foundry/usbarmory-debian-base_image/issues/9
    echo "disable-ipv6" >> ${GNUPGHOME}/dirmngr.conf; \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-key "$GPG_KEY" || \
    gpg --keyserver pgp.mit.edu --recv-key "$GPG_KEY" || \
    gpg --keyserver keyserver.pgp.com --recv-key "$GPG_KEY"; \
    gpg --batch --verify "/tmp/$STORM_RELEASE.tar.gz.asc" "/tmp/$STORM_RELEASE.tar.gz"; \
    tar -C /opt -xzf "/tmp/$STORM_RELEASE.tar.gz"; \
# Clean up
    rm -rf "$GNUPGHOME" "/tmp/$STORM_RELEASE.tar.gz" "/tmp/$STORM_RELEASE.tar.gz.asc"; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /opt/$STORM_RELEASE

# Copy service scripts
COPY run/zookeeperd.sh /etc/service/zookeeperd/run
COPY run/nimbus.sh /etc/service/nimbus/run
COPY run/supervisor.sh /etc/service/supervisor/run
COPY run/ui.sh /etc/service/ui/run
COPY run/logviewer.sh /etc/service/logviewer/run

# Copy configuration
COPY zookeeper/zoo.cfg /etc/zookeeper/conf/zoo.cfg
COPY storm/storm.yaml $STORM_CONF_DIR/storm.yaml

RUN set -ex; \
    sed -i "s!storm.log.dir:.*!storm.log.dir: $STORM_LOG_DIR!g" $STORM_CONF_DIR/storm.yaml; \
    sed -i "s!storm.local.dir:.*!storm.local.dir: $STORM_DATA_DIR!g" $STORM_CONF_DIR/storm.yaml;

# Ports
EXPOSE 8080 8000

# Volume
VOLUME ["/logs"]

# Init for phusion/baseimage
CMD ["/sbin/my_init"]
