#!/usr/bin/env bash

set -e

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print usage information
print_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Install Task on macOS or WSL"
  echo ""
  echo "Options:"
  echo "  -p, --platform <mac|wsl>    Specify platform (required)"
  echo "  -b, --bin-dir <directory>   Specify installation directory (optional)"
  echo "  -v, --version <version>     Specify Task version (optional)"
  echo "  -h, --help                  Display this help message"
  echo ""
  echo "Example:"
  echo "  $0 --platform mac           # Install latest Task on macOS"
  echo "  $0 -p wsl -b ~/.local/bin   # Install latest Task on WSL in ~/.local/bin"
  echo "  $0 -p mac -v v3.43.3        # Install Task v3.43.3 on macOS"
}

# Default values
PLATFORM=""
BIN_DIR=""
VERSION=""

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--platform)
      PLATFORM="$2"
      shift 2
      ;;
    -b|--bin-dir)
      BIN_DIR="$2"
      shift 2
      ;;
    -v|--version)
      VERSION="$2"
      shift 2
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unknown option $1${NC}"
      print_usage
      exit 1
      ;;
  esac
done

# Check if platform is specified
if [ -z "$PLATFORM" ]; then
  echo -e "${RED}Error: Platform is required${NC}"
  print_usage
  exit 1
fi

# Validate platform
if [ "$PLATFORM" != "mac" ] && [ "$PLATFORM" != "wsl" ]; then
  echo -e "${RED}Error: Platform must be 'mac' or 'wsl'${NC}"
  print_usage
  exit 1
fi

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to check if we're actually in WSL
is_wsl() {
  if [ -f /proc/version ]; then
    if grep -qi microsoft /proc/version; then
      return 0
    fi
  fi
  return 1
}

# Function to detect architecture
detect_arch() {
  ARCH=$(uname -m)
  case $ARCH in
    x86_64)
      echo "amd64"
      ;;
    arm64|aarch64)
      echo "arm64"
      ;;
    *)
      echo -e "${RED}Error: Unsupported architecture: $ARCH${NC}"
      exit 1
      ;;
  esac
}

# Install Task using the official script
install_task() {
  local install_cmd="sh -c \"$(curl --location https://taskfile.dev/install.sh)\""
  local params="-- -d"
  
  if [ -n "$BIN_DIR" ]; then
    params="$params -b $BIN_DIR"
  fi
  
  if [ -n "$VERSION" ]; then
    params="$params $VERSION"
  fi
  
  echo -e "${YELLOW}Installing Task...${NC}"
  eval "$install_cmd $params"
}

# Install Task via Homebrew on macOS
install_task_homebrew() {
  echo -e "${YELLOW}Installing Task via Homebrew...${NC}"
  brew install go-task/tap/go-task
}

# Install Task on macOS
install_task_mac() {
  if command_exists brew; then
    install_task_homebrew
  else
    echo -e "${YELLOW}Homebrew not found, using official install script...${NC}"
    install_task
  fi
  
  # Check if installation was successful
  if command_exists task; then
    echo -e "${GREEN}Task installed successfully!${NC}"
    task --version
  else
    # Check if bin directory is in PATH
    if [ -n "$BIN_DIR" ]; then
      if ! echo "$PATH" | grep -q "$BIN_DIR"; then
        echo -e "${YELLOW}Warning: $BIN_DIR is not in your PATH.${NC}"
        echo -e "You may need to add it to your PATH by adding this line to your ~/.zshrc or ~/.bash_profile:"
        echo -e "  export PATH=\"$BIN_DIR:\$PATH\""
      fi
    fi
    
    echo -e "${RED}Task installation may have failed or is not in your PATH.${NC}"
    exit 1
  fi
}

# Install Task on WSL
install_task_wsl() {
  # Check if we're actually in WSL
  if ! is_wsl; then
    echo -e "${RED}Error: This doesn't appear to be a WSL environment.${NC}"
    exit 1
  fi
  
  # Use the official install script
  install_task
  
  # Check if installation was successful
  if command_exists task; then
    echo -e "${GREEN}Task installed successfully!${NC}"
    task --version
  else
    # Check if bin directory is in PATH
    if [ -n "$BIN_DIR" ]; then
      if ! echo "$PATH" | grep -q "$BIN_DIR"; then
        echo -e "${YELLOW}Warning: $BIN_DIR is not in your PATH.${NC}"
        echo -e "You may need to add it to your PATH by adding this line to your ~/.bashrc:"
        echo -e "  export PATH=\"$BIN_DIR:\$PATH\""
      fi
    fi
    
    echo -e "${RED}Task installation may have failed or is not in your PATH.${NC}"
    exit 1
  fi
}

# Main installation process
echo -e "${GREEN}=== Task Installer ===${NC}"
echo -e "${YELLOW}Platform: ${NC}$PLATFORM"

if [ -n "$BIN_DIR" ]; then
  echo -e "${YELLOW}Installation directory: ${NC}$BIN_DIR"
fi

if [ -n "$VERSION" ]; then
  echo -e "${YELLOW}Version: ${NC}$VERSION"
else
  echo -e "${YELLOW}Version: ${NC}latest"
fi

# Check if Task is already installed
if command_exists task; then
  current_version=$(task --version)
  echo -e "${YELLOW}Task is already installed: ${NC}$current_version"
  echo -n -e "${YELLOW}Do you want to continue with installation? [y/N] ${NC}"
  read -r answer
  if [[ ! "$answer" =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Installation cancelled.${NC}"
    exit 0
  fi
fi

# Install based on platform
case $PLATFORM in
  mac)
    install_task_mac
    ;;
  wsl)
    install_task_wsl
    ;;
esac

echo -e "${GREEN}Installation complete!${NC}"
echo -e "Run ${YELLOW}task --help${NC} to get started." 