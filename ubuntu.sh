#!/bin/bash
# Initial script for install GVM 21 to Ubuntu 20
#
# Relates:
#   - https://greenbone.github.io/docs/gvm-21.04/index.html#starting-services-with-systemd
#   - https://www.libellux.com/
#
# Created by Yevgeniy Goncharov, https://sys-adm.in
# -------------------------------------------------------------------------------------------\

# Sys env / paths / etc
# -------------------------------------------------------------------------------------------\

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
SCRIPT_NAME="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"
cd $SCRIPT_PATH; if [[ ! -d "$SCRIPT_PATH/tmp" ]]; then mkdir $SCRIPT_PATH/tmp; fi

# Variables
# -------------------------------------------------------------------------------------------\

SERVER_IP=$(hostname -I | cut -d' ' -f1)

# Functions
# -------------------------------------------------------------------------------------------\

function enable_sd() {
    echo "Starting: $1 ..."
    sudo systemctl enable $1
    sudo systemctl start $1
    sleep 10
}

function sync_data() {
    sudo -u gvm greenbone-feed-sync --type $1
    sleep 5
}

# Install depieces
# -------------------------------------------------------------------------------------------\

sudo apt-get update && \
sudo apt-get -y upgrade && \
sudo apt-get install -y build-essential && \
sudo apt-get install -y cmake pkg-config gcc-mingw-w64 \
gnutls-bin libgnutls28-dev libxml2-dev libssh-dev libssl-dev libunistring-dev \
libldap2-dev libgcrypt-dev libpcap-dev libgpgme-dev libradcli-dev libglib2.0-dev \
libksba-dev libical-dev libpq-dev libopenvas-dev libpopt-dev libnet1-dev \
libmicrohttpd-dev redis-server libhiredis-dev doxygen xsltproc uuid-dev \
graphviz bison postgresql postgresql-contrib postgresql-server-dev-all \
heimdal-dev xmltoman nmap npm nodejs virtualenv gnupg rsync yarnpkg \
python3-paramiko python3-lxml python3-defusedxml python3-pip python3-psutil \
python3-setuptools python3-packaging python3-wrapt python3-cffi python3-redis \
xmlstarlet texlive-fonts-recommended texlive-latex-extra perl-base expect

# Install yarn
# -------------------------------------------------------------------------------------------\

sudo npm install -g yarn

# Add user
# -------------------------------------------------------------------------------------------\

sudo useradd -r -M -U -G sudo -s /usr/sbin/nologin gvm && \
sudo usermod -aG gvm $USER # && su $USER

# Initial dirs
# -------------------------------------------------------------------------------------------\

export PATH=$PATH:/usr/local/sbin && export INSTALL_PREFIX=/usr/local && \
export SOURCE_DIR=$HOME/source && mkdir -p $SOURCE_DIR && \
export BUILD_DIR=$HOME/build && mkdir -p $BUILD_DIR && \
export INSTALL_DIR=$HOME/install && mkdir -p $INSTALL_DIR

# Import GVM key and set to trust
# -------------------------------------------------------------------------------------------\

curl -O https://www.greenbone.net/GBCommunitySigningKey.asc && \
gpg --import GBCommunitySigningKey.asc

# Set Greenbone key to trust
./gpg-trust.exp 9823FAA60ED1E580

# Build libraries
# -------------------------------------------------------------------------------------------\

export GVM_VERSION=21.4.4 && \
export GVM_LIBS_VERSION=21.4.3

curl -f -L https://github.com/greenbone/gvm-libs/archive/refs/tags/v$GVM_LIBS_VERSION.tar.gz -o $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz && \
curl -f -L https://github.com/greenbone/gvm-libs/releases/download/v$GVM_LIBS_VERSION/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc -o $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc && \
gpg --verify $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz.asc $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz

# Install GVM libraries
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION.tar.gz && \
mkdir -p $BUILD_DIR/gvm-libs && cd $BUILD_DIR/gvm-libs && \
cmake $SOURCE_DIR/gvm-libs-$GVM_LIBS_VERSION \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
  -DCMAKE_BUILD_TYPE=Release \
  -DSYSCONFDIR=/etc \
  -DLOCALSTATEDIR=/var \
  -DGVM_PID_DIR=/run/gvm && \
make DESTDIR=$INSTALL_DIR install && \
sudo cp -rv $INSTALL_DIR/* / && \
rm -rf $INSTALL_DIR/*

# Build GVM
export GVMD_VERSION=21.4.4 && \
curl -f -L https://github.com/greenbone/gvmd/archive/refs/tags/v$GVMD_VERSION.tar.gz -o $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz && \
curl -f -L https://github.com/greenbone/gvmd/releases/download/v$GVMD_VERSION/gvmd-$GVMD_VERSION.tar.gz.asc -o $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz.asc && \
gpg --verify $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz.asc $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz

tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gvmd-$GVMD_VERSION.tar.gz && \
mkdir -p $BUILD_DIR/gvmd && cd $BUILD_DIR/gvmd && \
cmake $SOURCE_DIR/gvmd-$GVMD_VERSION \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
  -DCMAKE_BUILD_TYPE=Release \
  -DLOCALSTATEDIR=/var \
  -DSYSCONFDIR=/etc \
  -DGVM_DATA_DIR=/var \
  -DGVM_RUN_DIR=/run/gvm \
  -DOPENVAS_DEFAULT_SOCKET=/run/ospd/ospd-openvas.sock \
  -DGVM_FEED_LOCK_PATH=/var/lib/gvm/feed-update.lock \
  -DSYSTEMD_SERVICE_DIR=/lib/systemd/system \
  -DDEFAULT_CONFIG_DIR=/etc/default \
  -DLOGROTATE_DIR=/etc/logrotate.d && \
make DESTDIR=$INSTALL_DIR install && \
sudo cp -rv $INSTALL_DIR/* / && \
rm -rf $INSTALL_DIR/*

# GSA
export GSA_VERSION=21.4.3 && \
curl -f -L https://github.com/greenbone/gsa/archive/refs/tags/v$GSA_VERSION.tar.gz -o $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz && \
curl -f -L https://github.com/greenbone/gsa/releases/download/v$GSA_VERSION/gsa-$GSA_VERSION.tar.gz.asc -o $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz.asc && \
gpg --verify $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz.asc $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz

tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/gsa-$GSA_VERSION.tar.gz && \
mkdir -p $BUILD_DIR/gsa && cd $BUILD_DIR/gsa && \
cmake $SOURCE_DIR/gsa-$GSA_VERSION \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
  -DCMAKE_BUILD_TYPE=Release \
  -DSYSCONFDIR=/etc \
  -DLOCALSTATEDIR=/var \
  -DGVM_RUN_DIR=/run/gvm \
  -DGSAD_PID_DIR=/run/gvm \
  -DLOGROTATE_DIR=/etc/logrotate.d && \
make DESTDIR=$INSTALL_DIR install && \
sudo cp -rv $INSTALL_DIR/* / && \
rm -rf $INSTALL_DIR/*

# Samba Module
export OPENVAS_SMB_VERSION=21.4.0 && \
curl -f -L https://github.com/greenbone/openvas-smb/archive/refs/tags/v$OPENVAS_SMB_VERSION.tar.gz -o $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz && \
curl -f -L https://github.com/greenbone/openvas-smb/releases/download/v$OPENVAS_SMB_VERSION/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz.asc -o $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz.asc && \
gpg --verify $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz.asc $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz

tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION.tar.gz && \
mkdir -p $BUILD_DIR/openvas-smb && cd $BUILD_DIR/openvas-smb && \
cmake $SOURCE_DIR/openvas-smb-$OPENVAS_SMB_VERSION \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
  -DCMAKE_BUILD_TYPE=Release && \
make DESTDIR=$INSTALL_DIR install && \
sudo cp -rv $INSTALL_DIR/* / && \
rm -rf $INSTALL_DIR/*

# Scanner
export OPENVAS_SCANNER_VERSION=21.4.3 && \
curl -f -L https://github.com/greenbone/openvas-scanner/archive/refs/tags/v$OPENVAS_SCANNER_VERSION.tar.gz -o $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz && \
curl -f -L https://github.com/greenbone/openvas-scanner/releases/download/v$OPENVAS_SCANNER_VERSION/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz.asc -o $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz.asc && \
gpg --verify $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz.asc $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz

tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION.tar.gz && \
mkdir -p $BUILD_DIR/openvas-scanner && cd $BUILD_DIR/openvas-scanner && \
cmake $SOURCE_DIR/openvas-scanner-$OPENVAS_SCANNER_VERSION \
  -DCMAKE_INSTALL_PREFIX=$INSTALL_PREFIX \
  -DCMAKE_BUILD_TYPE=Release \
  -DSYSCONFDIR=/etc \
  -DLOCALSTATEDIR=/var \
  -DOPENVAS_FEED_LOCK_PATH=/var/lib/openvas/feed-update.lock \
  -DOPENVAS_RUN_DIR=/run/ospd && \
make DESTDIR=$INSTALL_DIR install && \
sudo cp -rv $INSTALL_DIR/* / && \
rm -rf $INSTALL_DIR/*

# OSPD
export OSPD_VERSION=21.4.4 && export OSPD_OPENVAS_VERSION=21.4.3 && \
curl -f -L https://github.com/greenbone/ospd/archive/refs/tags/v$OSPD_VERSION.tar.gz -o $SOURCE_DIR/ospd-$OSPD_VERSION.tar.gz && \
curl -f -L https://github.com/greenbone/ospd/releases/download/v$OSPD_VERSION/ospd-$OSPD_VERSION.tar.gz.asc -o $SOURCE_DIR/ospd-$OSPD_VERSION.tar.gz.asc && \
curl -f -L https://github.com/greenbone/ospd-openvas/archive/refs/tags/v$OSPD_OPENVAS_VERSION.tar.gz -o $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz && \
curl -f -L https://github.com/greenbone/ospd-openvas/releases/download/v$OSPD_OPENVAS_VERSION/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz.asc -o $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz.asc && \
gpg --verify $SOURCE_DIR/ospd-$OSPD_VERSION.tar.gz.asc $SOURCE_DIR/ospd-$OSPD_VERSION.tar.gz && \
gpg --verify $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz.asc $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz

tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/ospd-$OSPD_VERSION.tar.gz && \
tar -C $SOURCE_DIR -xvzf $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION.tar.gz && \
cd $SOURCE_DIR/ospd-$OSPD_VERSION && \
python3 -m pip install . --prefix=$INSTALL_PREFIX --root=$INSTALL_DIR

pip install --upgrade psutil==5.5.1 && \
cd $SOURCE_DIR/ospd-openvas-$OSPD_OPENVAS_VERSION && \
python3 -m pip install . --prefix=$INSTALL_PREFIX --root=$INSTALL_DIR --no-warn-script-location && \
python3 -m pip install --user gvm-tools && \
sudo cp -rv $INSTALL_DIR/* / && \
rm -rf $INSTALL_DIR/*


# Redis
sudo cp $SOURCE_DIR/openvas-scanner-21.4.3/config/redis-openvas.conf /etc/redis/ && \
sudo chown redis:redis /etc/redis/redis-openvas.conf && \
sudo echo "db_address = /run/redis-openvas/redis.sock" | sudo tee -a /etc/openvas/openvas.conf

sudo systemctl start redis-server@openvas.service && \
sudo systemctl enable redis-server@openvas.service

sudo usermod -aG redis gvm && \
sudo chown -R gvm:gvm /var/lib/gvm && \
sudo chown -R gvm:gvm /var/lib/openvas && \
sudo chown -R gvm:gvm /var/log/gvm && \
sudo chown -R gvm:gvm /run/gvm && \
sudo chmod -R g+srw /var/lib/gvm && \
sudo chmod -R g+srw /var/lib/openvas && \
sudo chmod -R g+srw /var/log/gvm && \
sudo chown gvm:gvm /usr/local/sbin/gvmd && \
sudo chmod 6750 /usr/local/sbin/gvmd

# Sync
# -------------------------------------------------------------------------------------------\

sudo chown gvm:gvm /usr/local/bin/greenbone-nvt-sync && \
sudo chmod 740 /usr/local/sbin/greenbone-feed-sync && \
sudo chown gvm:gvm /usr/local/sbin/greenbone-*-sync && \
sudo chmod 740 /usr/local/sbin/greenbone-*-sync

# Allow GVM user use OpenVAS
# -------------------------------------------------------------------------------------------\

echo "%gvm ALL = NOPASSWD: /usr/local/sbin/openvas" >> /etc/sudoers

# PostgreSQL
# -------------------------------------------------------------------------------------------\

systemctl start postgresql@12-main.service

sudo -Hiu postgres createuser gvm
sudo -Hiu postgres createdb -O gvm gvmd
sudo -Hiu postgres psql -c 'create role dba with superuser noinherit;' gvmd
sudo -Hiu postgres psql -c 'grant dba to gvm;' gvmd
sudo -Hiu postgres psql -c 'create extension "uuid-ossp";' gvmd
sudo -Hiu postgres psql -c 'create extension "pgcrypto";' gvmd
systemctl restart postgresql@12-main.service
systemctl enable postgresql@12-main.service

# GVM admin creation
# -------------------------------------------------------------------------------------------\

sudo ldconfig
sudo /usr/local/sbin/gvmd --create-user=admin --password=admin

# Feed import fixing
_gvmduid=`sudo gvmd --get-users --verbose | awk '{print $2}'`
# admin 9792da0c-c48c-4ac2-a10b-65834aaa4a33


sudo gvmd --modify-setting 78eceaec-3385-11ea-b237-28d24461215b --value $_gvmduid

# Update NVT (network vuln tests)
# -------------------------------------------------------------------------------------------\

sudo -u gvm greenbone-nvt-sync; sleep 10
sync_data GVMD_DATA; sync_data SCAP; sync_data CERT

# Gen certs
# -------------------------------------------------------------------------------------------\

sudo -u gvm gvm-manage-certs -a

# Gen systemd units
# -------------------------------------------------------------------------------------------\

cat << EOF > $BUILD_DIR/gvmd.service
[Unit]
Description=Greenbone Vulnerability Manager daemon (gvmd)
After=network.target networking.service postgresql.service ospd-openvas.service
Wants=postgresql.service ospd-openvas.service
Documentation=man:gvmd(8)
ConditionKernelCommandLine=!recovery

[Service]
Type=forking
User=gvm
Group=gvm
PIDFile=/run/gvm/gvmd.pid
RuntimeDirectory=gvm
RuntimeDirectoryMode=2775
ExecStart=/usr/local/sbin/gvmd --osp-vt-update=/run/ospd/ospd-openvas.sock --listen-group=gvm
Restart=always
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo cp $BUILD_DIR/gvmd.service /etc/systemd/system/

cat << EOF > $BUILD_DIR/gsad.service
[Unit]
Description=Greenbone Security Assistant daemon (gsad)
Documentation=man:gsad(8) https://www.greenbone.net
After=network.target gvmd.service
Wants=gvmd.service

[Service]
Type=forking
User=gvm
Group=gvm
PIDFile=/run/gvm/gsad.pid
ExecStart=/usr/local/sbin/gsad --listen=${SERVER_IP} --port=9392
Restart=always
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
Alias=greenbone-security-assistant.service
EOF

sudo cp $BUILD_DIR/gsad.service /etc/systemd/system/

cat << EOF > $BUILD_DIR/ospd-openvas.service
[Unit]
Description=OSPd Wrapper for the OpenVAS Scanner (ospd-openvas)
Documentation=man:ospd-openvas(8) man:openvas(8)
After=network.target networking.service redis-server@openvas.service
Wants=redis-server@openvas.service
ConditionKernelCommandLine=!recovery

[Service]
Type=forking
User=gvm
Group=gvm
RuntimeDirectory=ospd
RuntimeDirectoryMode=2775
PIDFile=/run/ospd/ospd-openvas.pid
ExecStart=/usr/local/bin/ospd-openvas --unix-socket /run/ospd/ospd-openvas.sock --pid-file /run/ospd/ospd-openvas.pid --log-file /var/log/gvm/ospd-openvas.log --lock-file-dir /var/lib/openvas --socket-mode 0o770
SuccessExitStatus=SIGKILL
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

sudo cp $BUILD_DIR/ospd-openvas.service /etc/systemd/system/

# Applying new units
# -------------------------------------------------------------------------------------------\

sudo systemctl daemon-reload
enable_sd ospd-openvas; enable_sd gvmd; enable_sd gsad

# Countdown
echo "GSAD service can be long run... Please wait ~5-10 minutes"
git clone https://github.com/m0zgen/countdown.git
./countdown/countdown.sh -f 1 -c 300

# Final checking
# -------------------------------------------------------------------------------------------\

if netstat -tulpn | grep 9392;then

    _listen=`netstat -tulpn | grep 9392 | awk '{print $4}'`
    echo "You can login in to GVM panel from address: http://$_listen"
    echo "With credentials: admin / admin"
    exit 1

else

    echo -e "GVM still starting.
    You can check GVM log - /var/log/gvm/gvmd.log
    You can check port 9392 on listen status.
    User credentials: admin / admin
    Exit
    "
    exit 1

fi


