#!/bin/bash
GREEN="\e[32m"
RESET="\e[0m"
green_echo() {
  echo -e "${GREEN}$1${RESET}"
}

green_echo "[+] Welcome to the Zond Setup Script an effort by @DigitalGuards"
green_echo "[+] This script will install the Zond Execution Engine and Qrysm Consensus Engine"
green_echo "[+] This currently assumes Go is already installed on the system"

# Install required packages
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get install -y build-essential screen tmux curl wget git
green_echo "[+] Installed build essentials and required tools"

# Check for gobrew installation and install if needed
if ! command -v gobrew &>/dev/null; then
    green_echo "[+] gobrew not found, installing..."
    wget -O - https://git.io/gobrew | sh
    # Add to current session
    export PATH="$HOME/.gobrew/bin:$PATH"
    export PATH="$HOME/.gobrew/current/go/bin:$PATH"
    # Add to bashrc if not already present
    if ! grep -q "/.gobrew/bin" ~/.bashrc; then
        echo 'export PATH="$HOME/.gobrew/bin:$PATH"' >> ~/.bashrc
    fi
    if ! grep -q "/.gobrew/current/go/bin" ~/.bashrc; then
        echo 'export PATH="$HOME/.gobrew/current/go/bin:$PATH"' >> ~/.bashrc
    fi
    green_echo "[+] gobrew installed successfully"
else
    green_echo "[+] gobrew is already installed"
fi

# Verify gobrew is working
if ! gobrew --version &>/dev/null; then
    green_echo "[!] Error: gobrew installation failed or PATH not set correctly"
    green_echo "[!] Please restart your terminal and run the script again"
    exit 1
fi

# Install Node.js and pm2 if not already installed
if ! command -v node &>/dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
    sudo npm install -g pm2
    green_echo "[+] Installed Node.js and pm2"
fi

# Function to choose process manager
choose_process_manager() {
    echo "Please choose your preferred process manager:"
    echo "1) screen (default)"
    echo "2) tmux"
    echo "3) pm2"
    read -p "Enter your choice (1-3): " choice
    
    case $choice in
        2) echo "tmux";;
        3) echo "pm2";;
        *) echo "screen";;
    esac
}

# Get user's preferred process manager
PROCESS_MANAGER=$(choose_process_manager)
green_echo "[+] Using $PROCESS_MANAGER as process manager"

# Check if ~/theQRL directory exists
if [ -d "$HOME/theQRL" ]; then
    echo "Directory ~/theQRL already exists. Removing it to start fresh."
    rm -rf "$HOME/theQRL"
    case $PROCESS_MANAGER in
        "screen")
            screen -X -S crysm quit
            screen -X -S zond quit
            ;;
        "tmux")
            tmux kill-session -t crysm 2>/dev/null
            tmux kill-session -t zond 2>/dev/null
            ;;
        "pm2")
            pm2 delete crysm 2>/dev/null
            pm2 delete zond 2>/dev/null
            ;;
    esac
fi

mkdir -p ~/theQRL
cd ~/theQRL

command -v wget &>/dev/null && echo "wget is already installed, continuing..." || { echo "wget not found, installing..."; sudo apt-get install -y wget; }
command -v gobrew &>/dev/null && echo "gobrew is already installed." || { echo "gobrew is not installed. Installing now."; wget -O - https://git.io/gobrew | sh; }
echo 'export PATH="$HOME/.gobrew/bin:$PATH"' >> ~/.bashrc
echo 'export PATH="$HOME/.gobrew/current/go/bin:$PATH' >> ~/.bashrc
export PATH="$HOME/.gobrew/bin:$PATH"
export PATH="$HOME/.gobrew/current/go/bin:$PATH"

gobrew install 1.21.5
gobrew install 1.20.12
green_echo "[+] Finished installing gobrew"

command -v git &>/dev/null && echo "git is already installed, continuing..." || { echo "git not found, installing..."; sudo apt-get install -y git; }
git clone https://github.com/theQRL/go-zond.git
git clone https://github.com/theQRL/qrysm.git
green_echo "[+] Cloned latest version of zond"

gobrew use 1.21.5
cd go-zond/
make gzond
cp build/bin/gzond ../
cd ..
green_echo "[+] Finished building the go-zond Execution Engine"

cd qrysm/
gobrew use 1.20.12
go build -o=../qrysmctl ./cmd/qrysmctl
go build -o=../beacon-chain ./cmd/beacon-chain
go build -o=../validator ./cmd/validator
cd ..
green_echo "[+] Finished building the Qrysm Consensus Engine"

green_echo "[+] Pulling zond Config Files"
wget https://github.com/theQRL/go-zond-metadata/raw/main/testnet/betanet/config.yml -P ~/theQRL
wget https://github.com/theQRL/go-zond-metadata/raw/main/testnet/betanet/genesis.ssz -P ~/theQRL

green_echo "[+] Zond node starting in $PROCESS_MANAGER session."
case $PROCESS_MANAGER in
    "screen")
        screen -dmS zond ./gzond \
            --log.file gozond.log \
            --nat=extip:0.0.0.0 \
            --betanet \
            --http \
            --http.api "web3,net,personal,zond,engine" \
            --datadir=gzonddata \
            --syncmode=full \
            --snapshot=false
        ;;
    "tmux")
        tmux new-session -d -s zond "./gzond \
            --log.file gozond.log \
            --nat=extip:0.0.0.0 \
            --betanet \
            --http \
            --http.api 'web3,net,personal,zond,engine' \
            --datadir=gzonddata \
            --syncmode=full \
            --snapshot=false"
        ;;
    "pm2")
        pm2 start ./gzond --name zond -- \
            --log.file gozond.log \
            --nat=extip:0.0.0.0 \
            --betanet \
            --http \
            --http.api "web3,net,personal,zond,engine" \
            --datadir=gzonddata \
            --syncmode=full \
            --snapshot=false
        ;;
esac
green_echo "[+] Zond started"

green_echo "[+] Sleep for 10 seconds and launch ze crysm"
for i in {1000..1}; do
    printf "\r%.2f" $(bc <<< "scale=2; $i/100")
    sleep 0.01
done
green_echo "[+] Crysm consensus engine now starting"

case $PROCESS_MANAGER in
    "screen")
        screen -dmS crysm ./beacon-chain \
            --log-file crysm.log --log-format text \
            --datadir=beacondata \
            --min-sync-peers=1 \
            --genesis-state=genesis.ssz \
            --chain-config-file=config.yml \
            --config-file=config.yml \
            --chain-id=32382 \
            --execution-endpoint=http://localhost:8551 \
            --accept-terms-of-use \
            --jwt-secret=gzonddata/gzond/jwtsecret \
            --contract-deployment-block=0 \
            --minimum-peers-per-subnet=0 \
            --p2p-static-id \
            --bootstrap-node "enr:-MK4QB1-CQAEPXFwD0D_tS08YXWPsKuaWdCzentML2JhAJnvXUR4lSPHCRXHCjudviKciwBmbPirHjyL_kmI0T1ti6qGAY0sF6hgh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC1MJ0KJc2VjcDI1NmsxoQN_5eo8D8pFGWUX1SMAT7kMbY2a9Ryb6Bu2oAW8s28kyYhzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A" \
            --bootstrap-node "enr:-MK4QOiaZeOWRnUyxfJv0lTbvjh-Re4zfDBW7vNWl9wIW7n8OWzMmxhy8IVHgRF7QZrkm7OGShDogEYUtdg8Bt1nIqaGAY0sFwP7h2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC0g6p2Jc2VjcDI1NmsxoQK6I2IsSSRwnOtpsnzhgACTRfYZqUQ1aTsw-K4qMR_2BohzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A"
        ;;
    "tmux")
        tmux new-session -d -s crysm "./beacon-chain \
            --log-file crysm.log --log-format text \
            --datadir=beacondata \
            --min-sync-peers=1 \
            --genesis-state=genesis.ssz \
            --chain-config-file=config.yml \
            --config-file=config.yml \
            --chain-id=32382 \
            --execution-endpoint=http://localhost:8551 \
            --accept-terms-of-use \
            --jwt-secret=gzonddata/gzond/jwtsecret \
            --contract-deployment-block=0 \
            --minimum-peers-per-subnet=0 \
            --p2p-static-id \
            --bootstrap-node 'enr:-MK4QB1-CQAEPXFwD0D_tS08YXWPsKuaWdCzentML2JhAJnvXUR4lSPHCRXHCjudviKciwBmbPirHjyL_kmI0T1ti6qGAY0sF6hgh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC1MJ0KJc2VjcDI1NmsxoQN_5eo8D8pFGWUX1SMAT7kMbY2a9Ryb6Bu2oAW8s28kyYhzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A' \
            --bootstrap-node 'enr:-MK4QOiaZeOWRnUyxfJv0lTbvjh-Re4zfDBW7vNWl9wIW7n8OWzMmxhy8IVHgRF7QZrkm7OGShDogEYUtdg8Bt1nIqaGAY0sFwP7h2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC0g6p2Jc2VjcDI1NmsxoQK6I2IsSSRwnOtpsnzhgACTRfYZqUQ1aTsw-K4qMR_2BohzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A'"
        ;;
    "pm2")
        pm2 start ./beacon-chain --name crysm -- \
            --log-file crysm.log --log-format text \
            --datadir=beacondata \
            --min-sync-peers=1 \
            --genesis-state=genesis.ssz \
            --chain-config-file=config.yml \
            --config-file=config.yml \
            --chain-id=32382 \
            --execution-endpoint=http://localhost:8551 \
            --accept-terms-of-use \
            --jwt-secret=gzonddata/gzond/jwtsecret \
            --contract-deployment-block=0 \
            --minimum-peers-per-subnet=0 \
            --p2p-static-id \
            --bootstrap-node "enr:-MK4QB1-CQAEPXFwD0D_tS08YXWPsKuaWdCzentML2JhAJnvXUR4lSPHCRXHCjudviKciwBmbPirHjyL_kmI0T1ti6qGAY0sF6hgh2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC1MJ0KJc2VjcDI1NmsxoQN_5eo8D8pFGWUX1SMAT7kMbY2a9Ryb6Bu2oAW8s28kyYhzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A" \
            --bootstrap-node "enr:-MK4QOiaZeOWRnUyxfJv0lTbvjh-Re4zfDBW7vNWl9wIW7n8OWzMmxhy8IVHgRF7QZrkm7OGShDogEYUtdg8Bt1nIqaGAY0sFwP7h2F0dG5ldHOIAAAAAAAAAACEZXRoMpDeYa1-IAAAk___________gmlkgnY0gmlwhC0g6p2Jc2VjcDI1NmsxoQK6I2IsSSRwnOtpsnzhgACTRfYZqUQ1aTsw-K4qMR_2BohzeW5jbmV0cwCDdGNwgjLIg3VkcIIu4A"
        ;;
esac

green_echo "[+] Setup complete with $PROCESS_MANAGER running, exiting script."