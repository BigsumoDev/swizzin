#!/bin/bash
#
# swizzin install headphones
#
# swizzin Copyright (C) 2020 swizzin.ltd
# Licensed under GNU General Public License v3.0 GPL-3 (in short)
#
#   You may copy, distribute and modify the software as long as you track
#   changes/dates in source files. Any modifications to our software
#   including (via compiler) GPL-licensed code must also be made available
#   under the GPL along with build & install instructions.
#
#

if [[ -f /tmp/.install.lock ]]; then
    log="/root/logs/install.log"
else
    log="/root/logs/swizzin.log"
fi

user=$(cut -d: -f1 < /root/.master.info)
password=$(cut -d: -f2 < /root/.master.info)
codename=$(lsb_release -cs)



if [[ $codename =~ ("xenial"|"stretch"|"buster"|"bionic") ]]; then
    LIST='git python2-dev virtualenv python-pip'
else
    LIST='git python2-dev'
fi

for depend in $LIST; do
  apt-get -qq -y install $depend >>"${log}" 2>&1 || { echo "ERROR: APT-GET could not install a required package: ${depend}. That's probably not good..."; }
done

if [[ ! $codename =~ ("xenial"|"stretch"|"buster"|"bionic") ]]; then
  . /etc/swizzin/sources/functions/pyenv
  python_getpip
  pip install -m virtualenv >>"${log}" 2>&1
fi

echo "Setting up the headphones venv ..."
mkdir -p /home/${user}/.venv
chown ${user}: /home/${user}/.venv
python2 -m virtualenv /home/${user}/.venv/headphones >>"${log}" 2>&1

PIP='wheel cheetah asn1'
/home/${user}/.venv/headphones/bin/pip install $PIP >>"${log}" 2>&1
chown -R ${user}: /home/${user}/.venv/headphones

git clone https://github.com/rembo10/headphones.git /home/${user}/headphones >>"${log}" 2>&1

chown -R $user: /home/${user}/headphones


cat > /etc/systemd/system/headphones.service <<HEADSD
[Unit]
Description=Headphones
Wants=network.target network-online.target
After=network.target network-online.target

[Service]
Type=forking
User=${user}
Group=${user}
ExecStart=/home/${user}/.venv/headphones/bin/python2 /home/${user}/headphones/Headphones.py -d --pidfile /run/${user}/headphones.pid --datadir /home/${user}/headphones --nolaunch --config /home/${user}/headphones/config.ini --port 8004
PIDFile=/run/USER/headphones.pid


[Install]
WantedBy=multi-user.target
HEADSD

systemctl enable --now headphones >> ${log} 2>&1
sleep 10

if [[ -f /install/.nginx.lock ]]; then
  bash /usr/local/bin/swizzin/nginx/headphones.sh
  systemctl reload nginx
  echo "Install complete! Please note headphones access url is: https://$(ip route get 1 | sed -n 's/^.*src \([0-9.]*\) .*$/\1/p')/headphones/home"
fi

touch /install/.headphones.lock
