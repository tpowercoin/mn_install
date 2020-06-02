#!/bin/bash

# Copyright (c) 2018-2020 The GOSSIP developers
# Copyright (c) 2020-2020 The TPWR developers

REPO='https://github.com/tpowercoin/tpwr-core/releases/download/v1.0.0/tpwr-1.0.0-x86_64-linux-gnu.zip'
ARCHIVE='tpwr-1.0.0-x86_64-linux-gnu.zip'
FOLDER='tpwr-1.0.0-x86_64-linux-gnu'
NODEIP=$(curl -s4 icanhazip.com)

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BLINK='\e[5m'
NBLINK='\e[0m'
NC='\033[0m'

function start_setup() {
  echo -e "${BLUE}"
  echo -e ""
  echo -e " _______ _______          _______   "
  echo -e "|__   __|  __ \ \        / /  __ \  "
  echo -e "   | |  | |__) \ \  /\  / /| |__) | "
  echo -e "   | |  |  ___/ \ \/  \/ / |  _  /  "
  echo -e "   | |  | |      \  /\  /  | | \ \  "
  echo -e "   |_|  |_|       \/  \/   |_|  \_\ "
  echo -e ""
  echo -e "${NC}"
  echo -e "${BLUE}Welcome to the TPWR masternode installation${NC}"
  echo -e ""
  echo -e "${RED}Do you want to install TPWR masternode?${NC}"
  echo -e ""
  
  PS3='Please enter your choice: '
  options=("Install" "Exit")
  select opt in "${options[@]}"
  do
      case $opt in
          "Install")
              break
              ;;
          #"Update")
          #    update_node
          #    ;;
          "Exit")
              exit 0
              ;;
          *) echo "Invalid option $REPLY";;
      esac
  done
}
 
function delete_old_installation() {
  echo -e "Searching and removing old ${RED}TPWR files and configurations${NC}"
  systemctl stop tpwr-core.service >/dev/null 2>&1
  sleep 10 >/dev/null 2>&1
  killall -9 tpwrd >/dev/null 2>&1
  rm -rf /root/tpwr* >/dev/null 2>&1 && rm -rf /root/.tpwr* >/dev/null 2>&1 && rm -rf /usr/local/bin/tpwr* >/dev/null 2>&1 && rm /etc/systemd/system/tpwr-core.service >/dev/null 2>&1
  echo -e "${GREEN}done...${NC}";
  clear
}

function download_node() {
  echo -e "Download ${YELLOW}TPWR Wallet${NC}"
  cd /root/ >/dev/null 2>&1
  wget -c $REPO >/dev/null 2>&1
  unzip -j $ARCHIVE >/dev/null 2>&1
  cp tpwrd /usr/local/bin/ && cp tpwr-cli /usr/local/bin/ >/dev/null 2>&1
  rm -rf tpwr* >/dev/null 2>&1
  cp /usr/local/bin/tpwr-cli /root/ >/dev/null 2>&1
  echo -e "${GREEN}done...${NC}";
  clear
}

function update_daemon() {
  echo -e "Download and update ${YELLOW}TPWR Wallet${NC}"
  cd /root >/dev/null 2>&1
  wget -c $REPO >/dev/null 2>&1
  unzip $ARCHIVE >/dev/null 2>&1
  cd /root/$FOLDER/ >/dev/null 2>&1
  cp tpwrd /usr/local/bin/ >/dev/null 2>&1 &&  cp tpwr-cli /usr/local/bin/ >/dev/null 2>&1
  cd -  >/dev/null 2>&1
  rm -rf tpwr-* >/dev/null 2>&1
  cp /usr/local/bin/tpwr-cli .
  clear
  echo -e "----------------------------------"
  echo -e "${GREEN}Update successfull!${NC}";
}

function configure_systemd() {
  cat << EOF > /etc/systemd/system/tpwr-core.service
[Unit]
Description=tpwr-core service
After=network.target

[Service]
User=root
Group=root

Type=forking

ExecStart=/usr/local/bin/tpwrd -daemon -conf=/root/.tpwr/tpwr.conf -datadir=/root/.tpwr
ExecStop=/usr/local/bin/tpwr-cli -conf=/root/.tpwr/tpwr.conf -datadir=/root/.tpwr stop

Restart=always
PrivateTmp=true
TimeoutStopSec=30s
TimeoutStartSec=10s
StartLimitInterval=60s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
EOF

  systemctl daemon-reload >/dev/null 2>&1
  sleep 4 >/dev/null 2>&1
  systemctl start tpwr-core.service >/dev/null 2>&1
  systemctl enable tpwr-core.service >/dev/null 2>&1

  if [[ -z "$(ps axo cmd:100 | egrep tpwrd)" ]]; then
    echo -e "-----------------------------------------------------------------------------------------------------------------"
    echo -e "${RED}tpwr-core is not running${NC}, please investigate. You should start by running the following commands:"
    echo -e "Start: systemctl start tpwr-core"
    echo -e "Status: systemctl status tpwr-core"
    echo -e "Logfile: less /var/log/syslog"
    echo -e "-----------------------------------------------------------------------------------------------------------------"
    exit 1
  fi
}

function create_key() {
  echo -e "Enter your ${RED}Masternode Private Key${NC} and press Enter:"
  read -e COINKEY
clear
}

function create_config() {
  mkdir /root/.tpwr >/dev/null 2>&1
  echo -e "-----------------------------------------------------------------------------------------"
  echo -e "Enter your ${RED}RPC Username${NC} which you set in your coin wallet and press Enter:"
  echo -e "-----------------------------------------------------------------------------------------"
  read -e RPCUSER
  clear
  echo -e "-----------------------------------------------------------------------------------------"
  echo -e "Enter your ${RED}RPC Password${NC} which you set in your coin wallet and press Enter:"
  echo -e "-----------------------------------------------------------------------------------------"
  read -e RPCPASS
  clear

cat << EOF > /root/.tpwr/tpwr.conf
rpcuser=$RPCUSER
rpcpassword=$RPCPASS
rpcbind=127.0.0.1
rpcallowip=127.0.0.1
logintimestamps=1
maxconnections=224
listen=1
server=1
daemon=0
staking=0
externalip=$NODEIP:55555
masternode=1
masternodeprivkey=$COINKEY
EOF
}

function update_config() {

cat << 'EOF' >> /root/.tpwr/tpwr.conf
rpcbind=127.0.0.1
EOF
}

function enable_firewall() {
  echo -e "----------------------"
  echo -e "Setting up firewall"
  echo -e "----------------------"
  ufw allow 55555/tcp comment "TPWR Core MN port" >/dev/null
  ufw allow ssh comment "SSH" >/dev/null 2>&1
  ufw limit ssh/tcp comment "Limit SSH" >/dev/null 2>&1
  ufw default allow outgoing >/dev/null 2>&1
  ufw logging on >/dev/null 2>&1
  echo "y" | ufw enable >/dev/null 2>&1
  echo -e "${GREEN}done...${NC}";
clear
}

function checks() {
  if [[ $(lsb_release -d) == *16.04* || *18.04* || *18.10* || *19.04* || *19.10* || *20.04* ]]; then
    UBUNTU_VERSION=OK
    else
      echo -e "------------------------------------------------------------------------------------------"
      echo -e "${RED}You are not running Ubuntu 16.x, 18.x, 19.x, 20.x Why? Installation is now cancelled.${NC}"
      echo -e "------------------------------------------------------------------------------------------"
    exit 1
  fi

  if [[ $EUID -ne 0 ]]; then
    echo -e "------------------------------------------------------------------"
    echo -e "${RED}$0 must be run as root.${NC}"
    echo -e "------------------------------------------------------------------"
    exit 1
  fi
}

function prepare_system() {
  echo -e "-----------------------------------------------------------------------"
  echo -e "Prepare the system to install the ${BLUE}TPWR${NC} masternode..."
  echo -e ""
  echo -e "Installing tools and tune your swap..."
  echo -e ""
  echo -e "${RED}${BLINK}Please be patient and wait a moment...${NBLINK}"
  echo -e "-----------------------------------------------------------------------"
  sysctl vm.swappiness=10 >/dev/null 2>&1
  echo -e  "vm.swappiness=10" >> /etc/sysctl.conf >/dev/null 2>&1
  sysctl vm.vfs_cache_pressure=50 >/dev/null 2>&1
  echo -e "vm.vfs_cache_pressure = 50" >> /etc/sysctl.conf >/dev/null 2>&1
  sysctl -p >/dev/null 2>&1
  apt-get update >/dev/null 2>&1
  DEBIAN_FRONTEND=noninteractive apt-get update >/dev/null 2>&1
  apt-get install -y -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" wget ufw fail2ban nano htop zip unzip >/dev/null 2>&1
  export LC_ALL="en_US.UTF-8" >/dev/null 2>&1
  export LC_CTYPE="en_US.UTF-8" >/dev/null 2>&1
  locale-gen --purge >/dev/null 2>&1
  apt clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* && apt autoremove -y --purge >/dev/null 2>&1
  if [ "$?" -gt "0" ];
    then
      echo -e "----------------------------------------------------------------------------------------------------------------------------------"
      echo -e "${RED}Not all required packages were installed properly.${NC} Try to install them manually by running the following commands:"
      echo -e "apt-get update && apt -y install wget ufw fail2ban nano htop zip unzip"
      echo -e "----------------------------------------------------------------------------------------------------------------------------------"
    exit 1
  fi
  clear
}

function wallet_active() {
  if [ -n "$(pidof tpwrd)" ] || [ -e "tpwrd" ] ; then
    echo -e "--------------------------------------------"
    echo -e "${GREEN}TPWR wallet daemon is up and running!${NC}"
    echo -e "--------------------------------------------"
  else
    echo -e "-----------------------------------------------------------------------------------------"
    echo -e "${RED}TPWR wallet daemon is not running!${NC} Try to start manually: systemctl start tpwr-core"
    echo -e "-----------------------------------------------------------------------------------------"
    exit 1
  fi
}

function check_connections() {
  echo -e "-----------------------------------------------------------------------"
  echo -e "Waiting at least ${RED}4 connections${NC} to sync the blockchain..."
  echo -e "-----------------------------------------------------------------------"
  sleep 30 >/dev/null 2>&1
  connections=$(/usr/local/bin/tpwr-cli -conf=/root/.tpwr/tpwr.conf getconnectioncount)
    while [ $connections -lt "4" ]; do
	connections=$(/usr/local/bin/tpwr-cli -conf=/root/.tpwr/tpwr.conf getconnectioncount)
      echo -e "We have only ${RED}$connections${NC} connections to other nodes..."
      echo -e "I will try to find other nodes in the network..."
      sleep 5
    if [[ "$connections" -gt "4" ]]; then
      break
    fi
    done
  echo -e "We have more than ${GREEN}4${NC} network connections, let's go."
  clear
}

function sync_node() {
  echo -e "-----------------------------------------------------------------------"
  echo -e "${RED}${BLINK}TPWR Blockchain synchronization in progress...${NBLINK}"
  echo -e "-----------------------------------------------------------------------"
  sleep 5 >/dev/null 2>&1
  tpwrblocks=$(curl -s https://chain.t-powercoin.com/api/getblockcount)
  walletblocks=$(/usr/local/bin/tpwr-cli -conf=/root/.tpwr/tpwr.conf getblockcount)
  echo "Blockcount on your node: $walletblocks"
  echo "Blockcount on the TPWR Blockchain: $tpwrblocks"
  echo -n ' '
    while [ "$walletblocks" -lt "$tpwrblocks" ]; do
      walletblocks=$(/usr/local/bin/tpwr-cli -conf=/root/.tpwr/tpwr.conf getblockcount)
      echo -e "$walletblocks from $tpwrblocks synced..."
      sleep 3
    if [[ "$walletblocks" == "$tpwrblocks" ]]; then
      break
    fi
  done
  echo -e "${GREEN}Your node is in sync!${NC}"
  clear
}

function important_information() {
  rm /root/tpwr-mnsetup.sh >/dev/null 2>&1
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -e "${GREEN}This installation was successfull! Good job!${NC}"
  echo -e "${BLUE}Your TPWR Masternode is up and running, you have enough connections and the blockchain is synced.${NC}"
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -e "MASTERNODE PRIVATEKEY is: $COINKEY"
  echo -e "Your IP and Port: $NODEIP:55555"
  echo -e "Masternode configuration: /root/.tpwr/tpwr.conf"
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -e "${GREEN}Now you can start your Masternode from your coin wallet${NC}"
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
  echo -e "${RED} After the start from the coin wallet do a double check here to see if your node is started!${NC}"
  echo -e "${RED} It can take a few minutes if the wallet shows enabled${NC}"
  echo -e "${RED} You can check the masternode status with: sudo ./tpwr-cli masternode status -f${NC}"
  echo -e "++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++"
}

function update_cleanup() {
  echo -e "Removing the prevoius installation, purging old wallet files. ${RED}${BLINK}Please be patient a moment...${NBLINK}"
  systemctl stop tpwr-core.service >/dev/null 2>&1
  sleep 20 >/dev/null 2>&1
  killall -9 tpwrd >/dev/null 2>&1
  rm /usr/local/bin/tpwr-cli >/dev/null 2>&1 && rm /usr/local/bin/tpwrd >/dev/null 2>&1
  rm -rf /root/.tpwr/sporks >/dev/null 2>&1 && rm -rf /root/.tpwr/backups >/dev/null 2>&1 && rm -rf /root/.tpwr/banlist.dat >/dev/null 2>&1 
  rm /root/.tpwr/debug.log >/dev/null 2>&1 && rm /root/.tpwr/wallet.dat >/dev/null 2>&1 && rm /root/.tpwr/tpwrd >/dev/null 2>&1 && rm /root/.tpwr/tpwr-cli >/dev/null 2>&1
  rm /etc/systemd/system/tpwr-core.service
  apt autoremove -y --purge >/dev/null 2>&1
  echo -e "${GREEN}Cleaned all old stuff...${NC}";
  clear
}

function tune_memory() {
  echo -e "We will tune your swap memory..."
  echo -e  "vm.swappiness=10" >> /etc/sysctl.conf
  sysctl vm.vfs_cache_pressure=50 
  echo -e "vm.vfs_cache_pressure = 50" >> /etc/sysctl.conf
  sysctl -p 
  clear
}

function update_node() {
  clear
  update_cleanup
  tune_memory
  update_daemon
  configure_systemd
  #update_config
  check_connections
  wallet_active
  exit 0
}

function setup_node() {
  create_key
  create_config
  configure_systemd
  enable_firewall
  wallet_active
  check_connections
  sync_node
  important_information
}

##### Main #####
clear
checks
start_setup
delete_old_installation
prepare_system
tune_memory
download_node
setup_node
