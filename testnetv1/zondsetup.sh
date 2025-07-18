#!/bin/bash

# Color definitions
GREEN="\e[32m"
RESET="\e[0m"

# Session name for screen/tmux
SESSION_NAME="zond-build"

# Setup logging directory
LOG_DIR="$(pwd)/logs"
mkdir -p "$LOG_DIR"

# Initialize LOG_FILE only if not already set
if [[ -z "$LOG_FILE" ]]; then
    LOG_FILE="$LOG_DIR/zondsetup_$(date +%Y%m%d_%H%M%S).log"
    touch "$LOG_FILE"
fi

# Function to log messages
log_message() {
    mkdir -p "$LOG_DIR"  # Ensure directory exists
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" | tee -a "$LOG_FILE"
}

# Function to echo in green and log
green_echo() {
    mkdir -p "$LOG_DIR"  # Ensure directory exists
    echo -e "${GREEN}$1${RESET}" | tee -a "$LOG_FILE"
    # Also log without color codes for clean logs
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}

# Function to check if running in screen or tmux
in_multiplexer() {
    [[ -n "$STY" || -n "$TMUX" ]]
}

# Function to start in screen
start_in_screen() {
    if ! command -v screen &>/dev/null; then
        sudo apt-get install -y screen
    fi
    # Create logs directory before starting screen
    mkdir -p "$LOG_DIR"
    # Start new screen session with our script and logging, passing the log file path
    screen -L -Logfile "$LOG_FILE" -dmS $SESSION_NAME bash -c "cd $(pwd) && LOG_FILE=\"$LOG_FILE\" INSIDE_MULTIPLEXER=true ./testnetv1/zondsetup.sh --inside-screen"
    green_echo "[+] Build started in screen session '$SESSION_NAME'"
    green_echo "[+] To attach to the session, run: screen -r $SESSION_NAME"
    green_echo "[+] All output is being logged to: $LOG_FILE"
    exit 0
}

# Function to start in tmux
start_in_tmux() {
    if ! command -v tmux &>/dev/null; then
        sudo apt-get install -y tmux
    fi
    # Create logs directory before starting tmux
    mkdir -p "$LOG_DIR"
    # Start new tmux session with our script and logging, passing the log file path
    tmux new-session -d -s $SESSION_NAME "cd $(pwd) && LOG_FILE=\"$LOG_FILE\" INSIDE_MULTIPLEXER=true ./testnetv1/zondsetup.sh --inside-tmux 2>&1 | tee -a \"$LOG_FILE\""
    green_echo "[+] Build started in tmux session '$SESSION_NAME'"
    green_echo "[+] To attach to the session, run: tmux attach -t $SESSION_NAME"
    green_echo "[+] All output is being logged to: $LOG_FILE"
    exit 0
}

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        if [[ "$ID" == "ubuntu" ]]; then
            if grep -qi microsoft /proc/version; then
                echo "wsl"
            else
                echo "ubuntu"
            fi
        else
            echo "unsupported"
        fi
    else
        echo "unsupported"
    fi
}

# Function to check Ubuntu version
check_ubuntu_version() {
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        # Convert version strings to integers for comparison (e.g., 22.04 -> 2204)
        local current_version=$(echo "$VERSION_ID" | sed 's/\.//g')
        
        # Check for supported versions (22.04 -> 2204 and 24.04 -> 2404)
        if [[ "$current_version" == "2204" ]] || [[ "$current_version" == "2404" ]]; then
            return 0
        fi
        
        green_echo "[!] Warning: You are using Ubuntu $VERSION_ID. While Ubuntu 22.04 and 24.04 are tested versions,"
        green_echo "[!] we'll proceed with the installation. If you encounter issues, please consider using Ubuntu 22.04 or 24.04."
        # Allow installation but warn user
        return 0
    fi
    return 1
}

# Function to setup WSL prerequisites
setup_wsl_prerequisites() {
    green_echo "[+] Setting up WSL prerequisites..."

    # Install build essentials
    sudo apt-get update && sudo apt-get install -y build-essential
    
    # Install Docker from official repository for WSL
    green_echo "[+] Installing Docker from official repository..."
    
    # Remove snap docker if installed
    sudo snap remove docker 2>/dev/null || true
    
    # Install Docker from official repo
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl gnupg
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Install yq separately
    sudo snap install yq
    
    # Setup docker permissions
    sudo groupadd docker 2>/dev/null || true
    sudo usermod -aG docker $USER
    
    # Start Docker service
    sudo service docker start || true

    green_echo "[+] WSL prerequisites setup completed"
    green_echo "[!] NOTE: You may need to restart your WSL instance for docker permissions to take effect"
    green_echo "[!] To restart WSL, exit this shell and run 'wsl --shutdown' in PowerShell, then restart WSL"
}

# Function to install prerequisites on Ubuntu/WSL
install_prerequisites_ubuntu() {
    green_echo "[+] Installing prerequisites for Ubuntu/WSL..."

    # For WSL, setup additional prerequisites
    if [[ "$1" == "wsl" ]]; then
        setup_wsl_prerequisites
    else
        # Install Docker using official Docker repository (not snap)
        green_echo "[+] Installing Docker from official repository..."
        
        # Remove snap docker if installed
        sudo snap remove docker 2>/dev/null || true
        
        # Install Docker from official repo
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
          
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        # Install yq separately
        sudo snap install yq
        
        # Setup docker permissions
        sudo groupadd docker 2>/dev/null || true
        sudo usermod -aG docker $USER
        
        # Start Docker service
        sudo systemctl start docker
        sudo systemctl enable docker
        
        green_echo "[!] NOTE: You may need to log out and back in for docker group membership to take effect"
    fi

    # Install Bazel
    sudo apt install apt-transport-https curl gnupg -y
    curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor >bazel-archive-keyring.gpg
    sudo mv bazel-archive-keyring.gpg /usr/share/keyrings
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list
    sudo apt update
    sudo apt-get install -y bazel-6.3.2

    # Create bazel symlink if it doesn't exist
    if ! command -v bazel &>/dev/null; then
        green_echo "[+] Creating bazel symlink..."
        sudo ln -sf /usr/bin/bazel-6.3.2 /usr/bin/bazel
    fi

    # Verify bazel installation
    if ! command -v bazel &>/dev/null; then
        green_echo "[!] Error: Bazel installation failed. Please install manually:"
        green_echo "    sudo apt install bazel-6.3.2"
        green_echo "    sudo ln -s /usr/bin/bazel-6.3.2 /usr/bin/bazel"
        exit 1
    fi

    # Install Kurtosis
    echo "deb [trusted=yes] https://apt.fury.io/kurtosis-tech/ /" | sudo tee /etc/apt/sources.list.d/kurtosis.list
    sudo apt update
    sudo apt install -y kurtosis-cli

    green_echo "[+] Prerequisites installation completed"
}

# Function to install prerequisites on MacOS
install_prerequisites_macos() {
    green_echo "[+] Installing prerequisites for MacOS..."

    # Install prerequisites using brew
    brew install bazel@7 kurtosis-tech/tap/kurtosis-cli jq yq

    # Detect shell and add bazel to PATH
    SHELL_RC="$HOME/.zshrc"
    if [[ "$SHELL" == *"bash"* ]]; then
        SHELL_RC="$HOME/.bashrc"
    fi
    
    if ! grep -q "bazel@7/bin" "$SHELL_RC"; then
        echo 'export PATH="/opt/homebrew/opt/bazel@7/bin:$PATH"' >> "$SHELL_RC"
        source "$SHELL_RC"
    fi

    green_echo "[+] Prerequisites installation completed for MacOS"
}

# Function to setup local testnet
setup_local_testnet() {
    green_echo "[+] Setting up local testnet..."
    cd testnetv1

    # Clone qrysm repository
    if [ ! -d "qrysm" ]; then
        git clone https://github.com/theQRL/qrysm -b dev
    fi
    cd qrysm

    # For MacOS, update bazel version
    if [[ "$1" == "macos" ]]; then
        echo '7.5.0' > .bazelversion
    fi

    # Prompt to edit network parameters
    green_echo "[+] Before starting the build, you may want to edit the network parameters"
    green_echo "[+] This includes setting up pre-funded accounts and other network configurations"
    echo
    read -p "Would you like to edit network parameters now? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v nano &>/dev/null; then
            nano scripts/local_testnet/network_params.yaml
        elif command -v vim &>/dev/null; then
            vim scripts/local_testnet/network_params.yaml
        else
            green_echo "[!] No editor found. Installing nano..."
            sudo apt-get install -y nano
            nano scripts/local_testnet/network_params.yaml
        fi
        
        # Confirm to proceed
        echo
        read -p "Ready to start the build? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            green_echo "[!] Build cancelled by user"
            exit 1
        fi
    fi

    # Let bazel handle its own workspace
    green_echo "[+] Building and starting local testnet..."
    
    # Check if user is in docker group
    if ! groups | grep -q docker; then
        green_echo "[!] Warning: User is not in docker group. This may cause permission issues."
        green_echo "[!] Consider running: sudo usermod -aG docker $USER && newgrp docker"
    fi
    
    # Proactively fix permissions for bazel-bin if it exists
    if [ -d "bazel-bin" ]; then
        green_echo "[+] Ensuring bazel-bin has proper permissions..."
        find bazel-bin -type f -name "*.tar" -exec chmod a+r {} \; 2>/dev/null || true
        find bazel-bin -type d -exec chmod a+rx {} \; 2>/dev/null || true
    fi
    
    # Check Docker is running
    if ! docker ps &>/dev/null; then
        green_echo "[!] Docker is not running. Starting Docker service..."
        sudo systemctl start docker || sudo service docker start || true
        sleep 2
    fi
    
    # First attempt - run the script
    green_echo "[+] Running local testnet script..."
    OUTPUT=$(bash ./scripts/local_testnet/start_local_testnet.sh 2>&1)
    EXIT_CODE=$?
    echo "$OUTPUT"
    
    # If it failed with permission denied, fix and retry
    if [ $EXIT_CODE -ne 0 ] && echo "$OUTPUT" | grep -q "permission denied"; then
        green_echo "[!] Permission denied error detected. Fixing permissions..."
        
        # More aggressive permission fix
        green_echo "[+] Running comprehensive permission fix..."
        chmod -R a+r bazel-bin/ 2>/dev/null || sudo chmod -R a+r bazel-bin/ 2>/dev/null || true
        
        # Also ensure Docker can access the entire qrysm directory
        chmod -R o+rx . 2>/dev/null || true
        
        # Retry
        green_echo "[+] Retrying testnet startup with fixed permissions..."
        if ! bash ./scripts/local_testnet/start_local_testnet.sh; then
            green_echo "[!] Still failing after permission fix."
            green_echo "[!] This might be a snap Docker issue. Try:"
            green_echo "    sudo snap connect docker:home"
            green_echo "    cd $(pwd)"
            green_echo "    sudo chmod -R 755 bazel-bin/"
            green_echo "    bash ./scripts/local_testnet/start_local_testnet.sh"
            exit 1
        fi
    elif [ $EXIT_CODE -ne 0 ]; then
        green_echo "[!] Error: Failed to start local testnet"
        green_echo "[!] Please check:"
        green_echo "    1. Docker status: docker ps"
        green_echo "    2. Bazel version: bazel --version"
        exit 1
    fi

    # Verify containers are running
    if [ "$(docker ps -q)" == "" ]; then
        green_echo "[!] Error: No Docker containers are running"
        green_echo "[!] Checking Docker logs..."
        docker logs $(docker ps -a -q | head -n1) 2>/dev/null || true
        exit 1
    fi

    green_echo "[+] Local testnet setup completed"
    green_echo "[+] Running containers:"
    docker ps
    
    # Get the actual mapped port
    local PORT=$(docker ps --format '{{.Ports}}' | grep 8545 | sed 's/0.0.0.0://g' | cut -d'-' -f1)
    if [ -n "$PORT" ]; then
        green_echo "[+] Found mapped port: $PORT"
        green_echo "[+] To test the network, use:"
        green_echo "    curl http://127.0.0.1:$PORT/ -X POST -H \"Content-Type: application/json\" \\"
        green_echo "      --data '{\"method\":\"zond_getBlockByNumber\",\"params\":[\"latest\", false],\"id\":1,\"jsonrpc\":\"2.0\"}' | jq -e"
    else
        green_echo "[!] Warning: Could not find mapped port for 8545"
    fi

    # Return to original directory
    cd ../..
}

# Print Windows WSL setup instructions if not in WSL
print_windows_instructions() {
    green_echo "[!] For Windows users, please follow these steps before running this script:"
    green_echo "1. Install WSL by running 'wsl --install' in PowerShell"
    green_echo "2. Restart your system if WSL was just installed"
    green_echo "3. Install Ubuntu 22.04 by running 'wsl --install Ubuntu-22.04' in PowerShell"
    green_echo "4. Start Ubuntu by running 'wsl -d Ubuntu-22.04'"
    green_echo "5. Then run this script again inside the Ubuntu WSL environment"
    exit 1
}

# Parse command line arguments
INSIDE_SCREEN=false
INSIDE_TMUX=false
USE_SCREEN=false
USE_TMUX=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --screen)
            USE_SCREEN=true
            shift
            ;;
        --tmux)
            USE_TMUX=true
            shift
            ;;
        --inside-screen)
            INSIDE_SCREEN=true
            shift
            ;;
        --inside-tmux)
            INSIDE_TMUX=true
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Check if we should start in a multiplexer
if [[ "$USE_SCREEN" == "true" && "$INSIDE_SCREEN" == "false" ]]; then
    start_in_screen
elif [[ "$USE_TMUX" == "true" && "$INSIDE_TMUX" == "false" ]]; then
    start_in_tmux
fi

# If we're not in a multiplexer and not explicitly running inside one, ask the user
if ! in_multiplexer && [[ "$INSIDE_SCREEN" == "false" && "$INSIDE_TMUX" == "false" ]]; then
    green_echo "[!] Running this script directly may be risky on smaller servers or unstable connections."
    green_echo "[!] It's recommended to run it in screen or tmux to prevent build interruption."
    echo
    read -p "Do you want to run in screen or tmux? (s/t/n): " -n 1 -r
    echo
    case $REPLY in
        s|S)
            start_in_screen
            ;;
        t|T)
            start_in_tmux
            ;;
        *)
            green_echo "[!] Continuing without screen/tmux..."
            ;;
    esac
fi

# Main script execution
if [[ -n "$INSIDE_MULTIPLEXER" ]]; then
    # We're running inside screen/tmux with a passed LOG_FILE
    green_echo "[+] Continuing Zond Testnet #BUIDL Preview Setup in multiplexer"
    green_echo "[+] Using log file: $LOG_FILE"
else
    # This is the first run of the script
    green_echo "[+] Welcome to the Zond Testnet #BUIDL Preview Setup Script"
    green_echo "[+] Log file: $LOG_FILE"
fi

# Detect OS
OS_TYPE=$(detect_os)

case $OS_TYPE in
    "ubuntu")
        if ! check_ubuntu_version; then
            green_echo "[!] Error: Ubuntu version not supported. Please use Ubuntu 22.04 or 24.04"
            exit 1
        fi
        green_echo "[+] Detected Ubuntu $(source /etc/os-release && echo $VERSION_ID)"
        install_prerequisites_ubuntu "ubuntu"
        setup_local_testnet "ubuntu"
        ;;
    "wsl")
        if ! check_ubuntu_version; then
            green_echo "[!] Error: Ubuntu version not supported. Please use Ubuntu 22.04 or 24.04"
            exit 1
        fi
        green_echo "[+] Detected Windows WSL (Ubuntu $(source /etc/os-release && echo $VERSION_ID))"
        install_prerequisites_ubuntu "wsl"
        setup_local_testnet "ubuntu"
        ;;
    "macos")
        green_echo "[+] Detected MacOS"
        install_prerequisites_macos
        setup_local_testnet "macos"
        ;;
    *)
        print_windows_instructions
        ;;
esac
green_echo "[+] Setup complete!"
green_echo "[+] To add pre-mined coins or fund accounts at genesis:"
green_echo "    1. Edit qrysm/scripts/local_testnet/network_params.yaml!"
green_echo "    2. Add your Zond address under prefunded_accounts"
green_echo "    3. Stop/Start the network using the qrysm/scripts/local_testnet/(stop/start)_local_testnet.sh scripts"
green_echo "    4. Restart the network using the qrysm/scripts/local_testnet/start_local_testnet.sh script with -b false flag to avoid rebuilding qrysm"
green_echo ""
green_echo "[+] To view all running services:"
green_echo "    kurtosis enclave inspect local-testnet"
green_echo ""
green_echo "[+] To view the logs:"
green_echo "    kurtosis service logs -f local-testnet or \$SERVICE_NAME"
green_echo ""
green_echo "[+] Complete setup log is available at: $LOG_FILE"