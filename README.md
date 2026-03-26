# LTK (Linux Tools Kit)

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell_Script-100%25-89E051?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)

A collection of shell scripts and tools for automating development environment setup and system configuration on Unix-like systems (macOS, Linux).

## 📋 Overview

This repository contains a set of utility scripts designed to streamline the setup and management of development environments. The tools are primarily written in Shell (Bash/Zsh) and aim to automate repetitive tasks such as terminal customization, SSH key management, and system diagnostics.

## 🚀 Key Features

* 🔧 One-click Environment Setup: Automated installation and configuration of Oh My Zsh and its popular plugins.
* 🔐 SSH/GPG Key Management: Securely generate and diagnose SSH/GPG keys, simplifying server authentication.
* 🐳 Container & System Diagnostics: Quick checks for system port usage, Docker container status, and network configuration.
* 🤖 CI/CD Integration Tools: Includes a Gitea Act Runner manager for self-hosted CI environments.
* 🛡️ Built-in Quality Gates: Provides out-of-the-box Git hooks and GitHub Actions workflows to ensure script quality.


## 📁 Project Structure

```
ltk/
├── scripts/                   # Core utility scripts
│   ├── install_omz.sh         # Installs Oh My Zsh
│   ├── omz_plugin_setup.zsh   # Configures Zsh plugins and themes
│   ├── setup_ssh_key_auth.zsh # Sets up SSH key authentication
│   ├── diagnose-gpg.sh        # GPG key diagnostic tool
│   ├── act_runner_manager.zsh # Gitea Act Runner manager
│   ├── ports.sh               # Checks system port usage
│   └── docker_ports.sh        # Checks Docker container ports
├── .gitignore                 # Git ignore rules
├── .editorconfig              # Editor style unification
├── .shellcheckrc              # ShellCheck static analysis config (Recommended)
├── LICENSE                    # MIT License
└── README.md                  # This document
```

## ⚙️ Installation & Usage

### Prerequisites

- **Shell**: Bash or Zsh
- **Git**: For cloning the repository
- **sudo privileges**: Required for system-level installations (e.g., Oh My Zsh)

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/persiliao/ltk.git
   cd ltk
   ```

2. **Make scripts executable**:
   ```bash
   chmod +x *.sh
   ```

3. **Run the desired script**:
   - **Install Oh My Zsh**:
     ```bash
     ./install_omz.sh
     ```
   - **Set up Oh My Zsh plugins**:
     ```bash
     ./omz_plugin_setup.sh
     ```
   - **Set up SSH key authentication**:
     ```bash
     ./setup_ssh_key_auth.sh
     ```
   - **Check system ports**:
     ```bash
     ./ports.sh
     ```
   - **Check Docker ports**:
     ```bash
     ./docker_ports.sh
     ```

## 📜 Script Details

### `install_omz.sh`
Installs https://ohmyz.sh/ and sets up a custom Zsh configuration. This script will change your default shell to Zsh.

### `omz_plugin_setup.sh`
Configures specific Oh My Zsh plugins and themes. Modify this script to add your preferred plugins (e.g., git, zsh-autosuggestions, zsh-syntax-highlighting).

### `setup_ssh_key_auth.sh`
Generates an SSH key pair (RSA/Ed25519) and provides instructions to add the public key to your remote server for password-less authentication.

### `ports.sh`
Lists all listening ports on the system along with the associated process names.

### `docker_ports.sh`
Lists all running Docker containers and their exposed ports.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository.
2. Create a feature branch (`git checkout -b feature/amazing-feature`).
3. Commit your changes (`git commit -m 'Add some amazing feature'`).
4. Push to the branch (`git push origin feature/amazing-feature`).
5. Open a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👤 Author

**XiangChu Liao**

- GitHub: https://github.com/persiliao
- Website: https://persiliao.com