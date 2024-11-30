# Zond Setup Script

A comprehensive setup script for running the QRL's Zond Execution Engine and Qrysm Consensus Engine. This script automates the installation and configuration process, making it easy to get started with running a Zond node.

## Features

- Automated installation of all required dependencies
- Support for multiple process managers:
  - Screen (traditional terminal multiplexer)
  - Tmux (modern terminal multiplexer)
  - PM2 (Node.js process manager with monitoring)
- Automatic Go version management using gobrew
- Proper logging configuration
- Clean setup with automatic cleanup of existing installations

## Prerequisites

- Ubuntu/Debian-based Linux system
- Bash shell (not compatible with zsh)
- Internet connection
- Sudo privileges

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/theQRL/zond_setupscript.git
   cd zond_setupscript
   ```

2. Make the script executable:
   ```bash
   chmod +x zondsetup.sh
   ```

3. Run the script:
   ```bash
   bash zondsetup.sh
   ```

## What the Script Does

1. Installs required packages (build-essential, screen/tmux, curl, wget, git)
2. Sets up gobrew for Go version management
3. Installs and configures Node.js and PM2 (if selected as process manager)
4. Clones and builds the latest versions of:
   - [go-zond](https://github.com/theQRL/go-zond) (Execution Engine)
   - [qrysm](https://github.com/theQRL/qrysm) (Consensus Engine)
5. Downloads necessary configuration files
6. Launches both engines using your chosen process manager

## Process Manager Options

The script allows you to choose between three process managers:

1. **Screen**
   - Traditional terminal multiplexer
   - Simple and lightweight
   - Available by default on most systems

2. **Tmux**
   - Modern terminal multiplexer
   - Better session management
   - Split panes and windows

3. **PM2**
   - Process manager for Node.js
   - Built-in monitoring and logs
   - Auto-restart on failure

## Logging

The script configures logging for both engines:
- Zond logs: `gozond.log`
- Qrysm logs: `crysm.log`

## Troubleshooting

If you encounter issues:

1. Check the log files for errors
2. Ensure all prerequisites are met
3. Try cleaning up the existing installation:
   ```bash
   rm -rf ~/theQRL
   ```
4. Make sure your system has enough resources (CPU, RAM, storage)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## Links

- [go-zond Repository](https://github.com/theQRL/go-zond)
- [qrysm Repository](https://github.com/theQRL/qrysm)

## License

This project is licensed under the MIT License - see the LICENSE file for details.
