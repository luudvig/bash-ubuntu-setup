#!/usr/bin/env bash

set -e -o pipefail -u -x

runAsRoot() {
  if [ $EUID -ne 0 ]; then
    sudo "${@}"
  else
    "${@}"
  fi
}

############################################################
# UPGRADE
############################################################
if ! grep -Pz "Start-Date: $(date +%F) .*\nCommandline: apt -y upgrade" /var/log/apt/history.log > /dev/null; then
  runAsRoot apt update
  runAsRoot DEBIAN_FRONTEND=noninteractive apt -y upgrade
  runAsRoot snap refresh
  runAsRoot reboot
fi

############################################################
# BASH
############################################################
sed -i '/^\s\+PS1=/s/01;32m/01;31m/' $HOME/.bashrc
install -m $(stat -c '%a' $HOME/.bashrc) /dev/null $HOME/.bash_aliases

############################################################
# DOCKER
############################################################
cd $(mktemp -d)
curl -fsSL https://get.docker.com -o get-docker.sh
runAsRoot sh get-docker.sh
runAsRoot usermod -aG docker $USER

############################################################
# MULLVAD
############################################################
cd $(mktemp -d)
until wget https://mullvad.net/media/mullvad-code-signing.asc; do :; done
until wget --trust-server-names https://mullvad.net/download/app/deb/latest; do :; done
until wget --trust-server-names https://mullvad.net/download/app/deb/latest/signature; do :; done
gpg --import mullvad-code-signing.asc
gpg --verify MullvadVPN-*.deb.asc
runAsRoot DEBIAN_FRONTEND=noninteractive apt -y install ./MullvadVPN-*.deb
mullvad lan set allow
echo "alias mullvad-status='mullvad status && curl https://am.i.mullvad.net/connected'" >> $HOME/.bash_aliases

############################################################
# SVTPLAY-DL
############################################################
echo "alias svtplay-dl='docker run -it --rm -u \$(id -u):\$(id -g) -v \"\$(pwd):/data\" --pull always spaam/svtplay-dl'" >> $HOME/.bash_aliases

############################################################
# TRANSMISSION
############################################################
mkdir $HOME/transmission
cat << EOF > $HOME/transmission/compose.yaml
services:
  transmission:
    image: linuxserver/transmission
    environment:
      - PUID=$(id -u)
      - PGID=$(id -g)
      - TZ=Etc/UTC
    volumes:
      - ./downloads:/downloads
    ports:
      - 9091:9091
      - 51413:51413
      - 51413:51413/udp
    pull_policy: always
EOF
chmod a-w $HOME/transmission/compose.yaml

############################################################
# YT-DLP
############################################################
echo "alias yt-dlp='docker run -it --rm -v \"\$(pwd):/data\" --pull always --entrypoint sh spaam/svtplay-dl -c \"wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp && chmod a+rx /usr/local/bin/yt-dlp && sh\"'" >> $HOME/.bash_aliases

runAsRoot poweroff
