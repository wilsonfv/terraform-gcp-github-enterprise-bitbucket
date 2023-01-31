#!/bin/bash -x
#
# Install a Bitbucket trial
# https://confluence.atlassian.com/bitbucketserver0721/install-a-bitbucket-trial-1115666757.html
#

function is_bitbucket_installer_existed {
    if [[ -f /opt/${BITBUCKET_SERVER_INSTALLER} ]]; then
        echo -n "YES"
    else
        echo -n "NO"
    fi
}

function download_bitbucket_installer {
    curl -o /opt/${BITBUCKET_SERVER_INSTALLER} ${BITBUCKET_SERVER_INSTALLER_DOWNLOAD_URL}
}

function install_bitbucket_dependencies {
    yum install -y https://packages.endpointdev.com/rhel/7/os/x86_64/endpoint-repo.x86_64.rpm
    yum install -y git
    yum install -y java-11-openjdk-devel
}

function run_bitbucket_installer {
    chmod a+x /opt/${BITBUCKET_SERVER_INSTALLER}
    /opt/${BITBUCKET_SERVER_INSTALLER} -q
}

function generate_bitbucket_cert {
    mkdir -p $BITBUCKET_HOME/shared/config

    # https://confluence.atlassian.com/bitbucketserver0721/secure-bitbucket-with-tomcat-using-ssl-1115666584.html
    ${BITBUCKET_INSTALLATION_LOCATION}/jre/bin/keytool -genkey -alias tomcat -storetype PKCS12 \
        -keyalg RSA -sigalg SHA256withRSA -noprompt -keypass changeit -storepass changeit \
        -dname "CN=${BITBUCKET_SERVER_HOSTNAME}, OU=ID, O=IBM, L=Hursley, S=Hants, C=GB" \
        -keystore $BITBUCKET_HOME/shared/config/ssl-keystore

    chown atlbitbucket:atlbitbucket $BITBUCKET_HOME/shared/config/ssl-keystore
}

function set_bitbucket_properties {
    cat > ${BITBUCKET_HOME}/shared/bitbucket.properties <<EOF
server.port=8443
server.ssl.enabled=true
server.ssl.key-store=${BITBUCKET_HOME}/shared/config/ssl-keystore
server.ssl.key-store-password=changeit
server.ssl.key-password=changeit
EOF
}

function create_bitbucket_systemd_service {
    cat > /etc/systemd/system/bitbucket.service <<EOF
[Unit]
Description=Atlassian Bitbucket Server Service
After=syslog.target network.target

[Service]
Type=forking
User=atlbitbucket
ExecStart=${BITBUCKET_INSTALLATION_LOCATION}/bin/start-bitbucket.sh --no-search
ExecStop=${BITBUCKET_INSTALLATION_LOCATION}/bin/stop-bitbucket.sh

[Install]
WantedBy=multi-user.target
EOF

    systemctl enable bitbucket.service --now
}

function restart_bitbucket {
    systemctl stop bitbucket
    systemctl start bitbucket
    systemctl status -l bitbucket
}

#######################################################################
#
# Main flow
#
#######################################################################

BITBUCKET_SERVER_VERSION=7.21.4
BITBUCKET_INSTALLATION_LOCATION=/opt/atlassian/bitbucket/${BITBUCKET_SERVER_VERSION}
BITBUCKET_SERVER_INSTALLER=atlassian-bitbucket-${BITBUCKET_SERVER_VERSION}-x64.bin
BITBUCKET_SERVER_INSTALLER_DOWNLOAD_URL=https://product-downloads.atlassian.com/software/stash/downloads/${BITBUCKET_SERVER_INSTALLER}
BITBUCKET_HOME=/var/atlassian/application-data/bitbucket
BITBUCKET_SERVER_HOSTNAME=bitbucket.onprem

if [[ $(is_bitbucket_installer_existed) == "NO" ]]; then
    download_bitbucket_installer
    install_bitbucket_dependencies
    run_bitbucket_installer
fi

# On bitbucket VM ssh terminal, run as root account
if [[ "These need to be run as root account on VM manually after initial setup" == "YES" ]]; then
    create_bitbucket_systemd_service
    generate_bitbucket_cert
    set_bitbucket_properties
    restart_bitbucket
fi