# Zond Testnet #BUIDL Preview Setup

This repository contains setup scripts for the Zond Testnet #BUIDL Preview. The script automatically detects your operating system and installs all necessary prerequisites for running a local Zond testnet.

## Supported Operating Systems

- Ubuntu 22.04 and 24.04
- macOS (with Apple Silicon or Intel)
- Windows (via WSL with Ubuntu 22.04/24.04)

## Prerequisites

### For Windows Users
1. Install WSL:
```powershell
wsl --install
```
2. Restart your system after WSL installation
3. Install Ubuntu:
```powershell
wsl --install Ubuntu-22.04
# or
wsl --install Ubuntu-24.04
```
4. Start Ubuntu:
```powershell
wsl -d Ubuntu
```

### For macOS Users
- Homebrew should be installed
- Terminal access

### For Ubuntu Users
- Terminal access
- Sudo privileges

## Installation

1. Clone this repository:
```bash
git clone https://github.com/DigitalGuards/zondsetupscript.git
cd zondsetupscript
```

2. Make the script executable:
```bash
chmod +x testnetv1/zondsetup.sh
```

3. Run the setup script:
```bash
# Run directly (will prompt for screen/tmux usage)
./testnetv1/zondsetup.sh

# Or run directly in screen
./testnetv1/zondsetup.sh --screen

# Or run directly in tmux
./testnetv1/zondsetup.sh --tmux
```

The script will:
- Detect your operating system
- Install required prerequisites:
  - Docker
  - Bazel (v6.3.2 for Ubuntu, v7.5.0 for macOS)
  - Kurtosis
  - Other necessary tools
- Clone the Qrysm repository
- Prompt to edit network parameters (pre-funded accounts, etc.)
- Start the local testnet build after configuration

### Network Configuration

During setup, you'll be prompted to edit the network parameters file. This is where you can:
- Add pre-funded accounts
- Configure network parameters
- Set up initial balances

The configuration file is located at:
```bash
qrysm/scripts/local_testnet/network_params.yaml
```

You can also edit this file later and restart the network with:
```bash
cd qrysm
bash ./scripts/local_testnet/start_local_testnet.sh -b false
```

### Running on Small Servers

When running on smaller servers or over unstable connections, it's recommended to use screen or tmux to prevent build interruption. The script will automatically:

1. Detect if you're running in screen/tmux
2. Prompt to start in screen/tmux if not
3. Install screen/tmux if needed

To attach to a running build:
```bash
# For screen
screen -r zond-build

# For tmux
tmux attach -t zond-build
```

## Post-Installation

### Testing the Network
To test if the network is running properly:

1. Find the mapped port:
```bash
docker ps --format '{{.Ports}}' | grep 8545 | sed 's/0.0.0.0://g'
```

2. Test the network (replace MAPPED_PORT with the port number from step 1):
```bash
curl http://127.0.0.1:MAPPED_PORT/ \
  -X POST \
  -H "Content-Type: application/json" \
  --data '{"method":"zond_getBlockByNumber","params":["latest", false],"id":1,"jsonrpc":"2.0"}' | jq -e
```

### Adding Pre-mined Coins
To add pre-mined coins or fund accounts at genesis:

1. Edit the network parameters:
```bash
nano qrysm/scripts/local_testnet/network_params.yaml
```

2. Add your Zond address under `prefunded_accounts`

3. Restart the network:
```bash
bash ./scripts/local_testnet/start_local_testnet.sh
```

### Checking Account Balance
To check the balance of a pre-funded account (replace MAPPED_PORT and YOUR_ADDRESS):
```bash
curl -H "Content-Type: application/json" \
  -X POST localhost:MAPPED_PORT \
  --data '{"jsonrpc":"2.0","method":"zond_getBalance","params":["YOUR_ADDRESS", "latest"],"id":1}'
```

## Troubleshooting

### Docker Permission Issues
If you encounter Docker permission issues:

1. Log out and log back in, or restart your system
2. For WSL users, run:
```powershell
wsl --shutdown
```
Then restart WSL.

### Bazel Version Issues
- Ubuntu: Make sure you're using Bazel 6.3.2
- macOS: Make sure you're using Bazel 7.5.0

## Support

For issues and support:
- Open an issue in this repository
- Join the QRL Discord server
- Visit the QRL Forum

## License

This project is licensed under the MIT License - see the LICENSE file for details.
