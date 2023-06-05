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
# Upgrade
############################################################
if ! grep -Pz "Start-Date: $(date +%F) .*\nCommandline: apt -y upgrade" /var/log/apt/history.log > /dev/null; then
  runAsRoot apt update
  runAsRoot DEBIAN_FRONTEND=noninteractive apt -y upgrade
  runAsRoot snap refresh
  runAsRoot reboot
fi

############################################################
# Docker
############################################################
cd $(mktemp -d)
curl -fsSL https://get.docker.com -o get-docker.sh
runAsRoot sh get-docker.sh
runAsRoot usermod -aG docker $USER

############################################################
# Mullvad
############################################################
cd $(mktemp -d)
wget https://mullvad.net/media/mullvad-code-signing.asc
wget --trust-server-names https://mullvad.net/download/app/deb/latest
wget --trust-server-names https://mullvad.net/download/app/deb/latest/signature
gpg --import mullvad-code-signing.asc
gpg --verify MullvadVPN-*.deb.asc
runAsRoot DEBIAN_FRONTEND=noninteractive apt -y install ./MullvadVPN-*.deb
mullvad lan set allow

############################################################
# Bash
############################################################
sed -i '/^\s\+PS1=/s/01;32m/01;31m/' $HOME/.bashrc
cp $HOME/.bashrc $HOME/.bash_aliases
cat << EOF > $HOME/.bash_aliases
alias mullvad-status='mullvad status && curl https://am.i.mullvad.net/connected'
alias svtplay-dl='docker run -it --rm -u \$(id -u):\$(id -g) -v "\$(pwd):/data" --pull always spaam/svtplay-dl'
alias yt-dlp='docker run -it --rm -v "\$(pwd):/data" --pull always --entrypoint sh spaam/svtplay-dl -c "wget https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -O /usr/local/bin/yt-dlp && chmod a+rx /usr/local/bin/yt-dlp && sh"'
EOF

############################################################
# Transmission
############################################################
mkdir $HOME/transmission
cat << EOF > $HOME/transmission/compose.yaml
services:
  transmission:
    image: lscr.io/linuxserver/transmission:latest
    container_name: transmission
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

runAsRoot poweroff
