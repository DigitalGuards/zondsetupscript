#!/bin/bash

# Color definitions
GREEN="\e[32m"
RESET="\e[0m"

# Function to echo in green
green_echo() {
    echo -e "${GREEN}$1${RESET}"
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
    
    # Install Docker and yq
    sudo snap install docker yq
    
    # Setup docker permissions
    sudo addgroup docker 2>/dev/null || true
    sudo usermod -aG docker $USER
    sudo usermod -aG docker root
    sudo chown root:docker /var/run/docker.sock

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
        # Install Docker and yq for native Ubuntu
        sudo snap install docker yq
        
        # Setup docker permissions for native Ubuntu
        sudo addgroup docker 2>/dev/null || true
        sudo usermod -aG docker $USER
        sudo usermod -aG docker root
        sudo chown root:docker /var/run/docker.sock
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

    # Add bazel to PATH
    if ! grep -q "bazel@7/bin" ~/.zshrc; then
        echo 'export PATH="/opt/homebrew/opt/bazel@7/bin:$PATH"' >> ~/.zshrc
        source ~/.zshrc
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

    # Let bazel handle its own workspace
    green_echo "[+] Building and starting local testnet..."
    
    # Ensure the user owns their home directory files
    sudo chown -R $USER:$USER "$HOME/.cache" || true
    
    # Run the testnet script
    if ! bash ./scripts/local_testnet/start_local_testnet.sh; then
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

# Main script execution
green_echo "[+] Welcome to the Zond Testnet #BUIDL Preview Setup Script"

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
green_echo "    kurtosis service logs -f local-testnet or $SERVICE_NAME"