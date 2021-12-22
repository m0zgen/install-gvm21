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

SCRIPT_TMP=$SCRIPT_PATH/tmp

# Functions
# -------------------------------------------------------------------------------------------\

function enable_sd() {
    echo "Starting: $1 ..."
    sudo systemctl enable $1
    sudo systemctl start $1
    sleep 10
}

function stop_sd() {
    echo "Stopping: $1 ..."
    sudo systemctl stop $1
    sleep 10
}

function sync_data() {
    sudo -u gvm greenbone-feed-sync --type $1
    sleep 5
}

# Unit patching

SOCK_CATALOG=/opt/gvm/var/run/
SOCK_NAME=ospd.sock
SOCK_FILE=/opt/gvm/var/run/ospd.sock

mkdir -p $SOCK_CATALOG
sudo chown -R gvm:gvm $SOCK_CATALOG


# # Gen systemd units
# # -------------------------------------------------------------------------------------------\

stop_sd ospd-openvas; stop_sd gvmd; stop_sd gsad

cat << EOF > $SCRIPT_TMP/gvmd.service
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
ExecStart=/usr/local/sbin/gvmd --osp-vt-update=${SOCK_FILE} --listen-group=gvm
Restart=always
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo cp $SCRIPT_TMP/gvmd.service /etc/systemd/system/

cat << EOF > $SCRIPT_TMP/gsad.service
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
# ExecStart=/usr/local/sbin/gsad --listen=${SERVER_IP} --port=9392
ExecStart=/usr/local/sbin/gsad --listen=0.0.0.0 --port=9392
Restart=always
TimeoutStopSec=10

[Install]
WantedBy=multi-user.target
Alias=greenbone-security-assistant.service
EOF

sudo cp $SCRIPT_TMP/gsad.service /etc/systemd/system/

cat << EOF > $SCRIPT_TMP/ospd-openvas.service
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
ExecStart=/usr/local/bin/ospd-openvas --unix-socket ${SOCK_FILE} --pid-file /run/ospd/ospd-openvas.pid --log-file /var/log/gvm/ospd-openvas.log --lock-file-dir /var/lib/openvas --socket-mode 0o770
SuccessExitStatus=SIGKILL
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

sudo cp $SCRIPT_TMP/ospd-openvas.service /etc/systemd/system/

sudo systemctl daemon-reload
enable_sd ospd-openvas; enable_sd gvmd; enable_sd gsad
