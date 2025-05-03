#!/bin/bash

# ======================================================================
# Reth + Lighthouse Node Runner Script (Low Storage Edition)
# ======================================================================
# This script configures Reth (execution) and Lighthouse (consensus) clients
# for Ethereum mainnet, optimized for machines with limited storage (~200GB).
#
# - Runs Reth as a full node (no archive/history, minimal storage usage)
# - Lighthouse syncs from a recent checkpoint (not from genesis)
# - Suitable for non-validator, non-archive use
# - Monitor disk usage and prune logs regularly
# ======================================================================


# Configuration Variables - Customize these as needed
# ======================================================================

# Node Configuration
RETH_DATA_DIR="$HOME/.local/share/reth" # TODO: change this as per your system directory structure
CHAIN="mainnet"  # Options: mainnet, sepolia, holesky, hoodi, dev
RETH_NODE_TYPE="full"  # Options: archive, full. Use 'full' for minimal storage (default)

# RPC Configuration
ENABLE_HTTP="true"
HTTP_ADDR="127.0.0.1"
HTTP_PORT="8545"
HTTP_API="eth,net,web3,txpool,debug"
HTTP_CORSDOMAIN="*"

ENABLE_WS="true"
WS_ADDR="127.0.0.1"
WS_PORT="8546"
WS_API="eth,net,web3,txpool"
WS_ORIGINS="*"

AUTH_ADDR="127.0.0.1"
AUTH_PORT="8551"
JWT_SECRET="$RETH_DATA_DIR/$CHAIN/jwt.hex"

LOG_LEVEL="info"  # Reth log levels: error, warn, info, debug, trace
DISCOVERY_PORT="30303"
MAX_PEERS="50"

# Ensure Reth is installed, or install it if missing
if ! command -v reth &> /dev/null; then
    echo "'reth' not found. Installing dependencies and building Reth from source..."
    # Detect OS
    OS="$(uname -s)"
    if [ "$OS" = "Darwin" ]; then
        echo "Detected macOS. Installing dependencies with Homebrew..."
        if ! command -v brew &> /dev/null; then
            echo "Homebrew not found. Please install Homebrew first: https://brew.sh/"
            exit 1
        fi
        brew install llvm pkg-config
    elif [ "$OS" = "Linux" ]; then
        if [ -f "/etc/lsb-release" ] || [ -f "/etc/debian_version" ]; then
            echo "Detected Ubuntu/Debian. Installing dependencies with apt-get..."
            sudo apt-get update
            sudo apt-get install -y libclang-dev pkg-config build-essential
        else
            echo "Unsupported Linux distribution. Please install libclang-dev, pkg-config, and build-essential manually."
            exit 1
        fi
    else
        echo "Unsupported OS: $OS. Please install Reth manually."
        exit 1
    fi
    # Install Rust
    if ! command -v cargo &> /dev/null; then
        echo "Installing Rust using rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env"
    fi
    # Ensure Rust is up to date
    rustup update
    # Clone and build Reth
    if [ ! -d "$HOME/reth" ]; then
        echo "Cloning Reth repository..."
        git clone https://github.com/paradigmxyz/reth "$HOME/reth"
    fi
    cd "$HOME/reth"
    echo "Building and installing Reth... (this may take several minutes)"
    cargo install --locked --path bin/reth --bin reth
    cd -
    if ! command -v reth &> /dev/null; then
        echo "Reth installation failed. Please check the output above for errors."
        exit 1
    fi
    echo "Reth installed successfully!"
fi

# Ensure Lighthouse is installed, or install it if missing
if ! command -v lighthouse &> /dev/null; then
    echo "'lighthouse' not found. Installing Lighthouse pre-built binary..."
    # Detect OS and architecture
    OS="$(uname -s)"
    ARCH="$(uname -m)"
    LH_VERSION="v4.0.1" # You can update this to the latest version as needed
    if [ "$OS" = "Darwin" ]; then
        if [ "$ARCH" = "x86_64" ]; then
            echo "Detected macOS x86_64. Downloading Lighthouse..."
            cd ~
            curl -LO https://github.com/sigp/lighthouse/releases/download/${LH_VERSION}/lighthouse-${LH_VERSION}-x86_64-apple-darwin.tar.gz
            tar -xvf lighthouse-${LH_VERSION}-x86_64-apple-darwin.tar.gz
            sudo cp lighthouse /usr/local/bin/
            rm -f lighthouse-${LH_VERSION}-x86_64-apple-darwin.tar.gz
            echo "Lighthouse installed to /usr/local/bin/lighthouse"
        else
            echo "Unsupported macOS architecture: $ARCH. Please install Lighthouse manually."
            exit 1
        fi
    elif [ "$OS" = "Linux" ]; then
        if [ "$ARCH" = "x86_64" ]; then
            echo "Detected Linux x86_64. Downloading Lighthouse..."
            cd ~
            curl -LO https://github.com/sigp/lighthouse/releases/download/${LH_VERSION}/lighthouse-${LH_VERSION}-x86_64-unknown-linux-gnu.tar.gz
            tar -xvf lighthouse-${LH_VERSION}-x86_64-unknown-linux-gnu.tar.gz
            sudo cp lighthouse /usr/local/bin/
            rm -f lighthouse-${LH_VERSION}-x86_64-unknown-linux-gnu.tar.gz
            echo "Lighthouse installed to /usr/local/bin/lighthouse"
        else
            echo "Unsupported Linux architecture: $ARCH. Please install Lighthouse manually."
            exit 1
        fi
    else
        echo "Unsupported OS: $OS. Please install Lighthouse manually."
        exit 1
    fi
    if ! command -v lighthouse &> /dev/null; then
        echo "Lighthouse installation failed. Please check the output above for errors."
        exit 1
    fi
    echo "Lighthouse installed successfully!"
fi



# ======================================================================
# Functions
# ======================================================================

generate_jwt_secret() {
    if [ ! -f "$JWT_SECRET" ]; then
        echo "Generating JWT secret at $JWT_SECRET"
        mkdir -p "$(dirname "$JWT_SECRET")"
        if command -v openssl &> /dev/null; then
            openssl rand -hex 32 > "$JWT_SECRET"
        else
            head -c 32 /dev/urandom | xxd -p -c 32 > "$JWT_SECRET"
        fi
        chmod 600 "$JWT_SECRET"
        echo "JWT secret generated successfully"
    fi
}

create_reth_service() {
    local service_name="reth-node"
    local user=$(whoami)
    local script_dir=$(dirname $(readlink -f "$0"))
    local reth_bin=$(command -v reth || echo "/usr/local/bin/reth")

    cat > "${script_dir}/${service_name}.service" <<EOL
[Unit]
Description=Reth Ethereum Execution Client
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=${user}
ExecStart=${reth_bin} node \\
    --datadir ${RETH_DATA_DIR} \\
    --chain ${CHAIN} \\
    --port ${DISCOVERY_PORT} \\
    --maxpeers ${MAX_PEERS} \\
    --authrpc.addr ${AUTH_ADDR} \\
    --authrpc.port ${AUTH_PORT} \\
    --authrpc.jwtsecret ${JWT_SECRET} \\
    $( [ "$RETH_NODE_TYPE" = "full" ] && echo "--full" ) \\
    $( [ "$ENABLE_HTTP" = "true" ] && echo "--http --http.addr ${HTTP_ADDR} --http.port ${HTTP_PORT} --http.api ${HTTP_API} --http.corsdomain ${HTTP_CORSDOMAIN}" ) \\
    $( [ "$ENABLE_WS" = "true" ] && echo "--ws --ws.addr ${WS_ADDR} --ws.port ${WS_PORT} --ws.api ${WS_API} --ws.origins ${WS_ORIGINS}" ) \\
    --log.level ${LOG_LEVEL}
Restart=on-failure
RestartSec=10
LimitNOFILE=1000000
WorkingDirectory=${script_dir}

[Install]
WantedBy=multi-user.target
EOL

    echo "Systemd service created: ${script_dir}/${service_name}.service"
    echo "To enable it:"
    echo "  sudo cp ${script_dir}/${service_name}.service /etc/systemd/system/"
    echo "  sudo systemctl daemon-reload"
    echo "  sudo systemctl enable ${service_name}.service"
    echo "  sudo systemctl start ${service_name}.service"
}

create_consensus_service() {
    local service_name="lighthouse-node"
    local user=$(whoami)
    local script_dir=$(dirname $(readlink -f "$0"))
    local lighthouse_bin=$(command -v lighthouse || echo "/usr/local/bin/lighthouse")

    cat > "${script_dir}/${service_name}.service" <<EOL
[Unit]
Description=Lighthouse Ethereum Consensus Client
After=network.target reth-node.service
Wants=network-online.target

[Service]
Type=simple
User=${user}
ExecStart=${lighthouse_bin} bn \\
    --checkpoint-sync-url https://mainnet.checkpoint.sigp.io \\
    --execution-endpoint http://${AUTH_ADDR}:${AUTH_PORT} \\
    --execution-jwt ${JWT_SECRET} \\
    --metrics \\
    --validator-monitor-auto \\
    --prune-payloads true \\
    --slots-per-restore-point 8192
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOL
    
    echo "========================================================================"
    echo "Lighthouse consensus client service file created at ${script_dir}/${service_name}.service"
    echo ""
    echo "To install the service, run:"
    echo "  sudo cp ${script_dir}/${service_name}.service /etc/systemd/system/"
    echo "  sudo systemctl daemon-reload"
    echo "  sudo systemctl enable ${service_name}.service"
    echo "  sudo systemctl start ${service_name}.service"
    echo "========================================================================"
}

# ======================================================================
# Script Logic
# ======================================================================

if [ "$1" = "--create-service" ]; then
    create_reth_service
    exit 0
elif [ "$1" = "--create-consensus-service" ]; then
    create_consensus_service
    exit 0
elif [ "$1" = "--help" ]; then
    echo "Usage: $0 [OPTION]"
    echo "  --create-service          Create systemd service file for Reth node"
    echo "  --create-consensus-service Create systemd service for Lighthouse"
    echo "  --help                    Show this help message"
    exit 0
fi

mkdir -p "$RETH_DATA_DIR/$CHAIN"
generate_jwt_secret

echo "==================================================================="
echo "Reminder: Use the systemd service files to run Reth and Lighthouse as background services."
echo "To create them, run:"
echo "  $0 --create-service"
echo "  $0 --create-consensus-service"
echo "==================================================================="

echo "You can also run Reth manually with:"
echo "reth node --datadir $RETH_DATA_DIR --chain $CHAIN $( [ "$RETH_NODE_TYPE" = "full" ] && echo "--full" ) --authrpc.jwtsecret $JWT_SECRET --authrpc.addr $AUTH_ADDR --authrpc.port $AUTH_PORT $( [ "$ENABLE_HTTP" = "true" ] && echo "--http --http.addr $HTTP_ADDR --http.port $HTTP_PORT --http.api $HTTP_API --http.corsdomain $HTTP_CORSDOMAIN" ) $( [ "$ENABLE_WS" = "true" ] && echo "--ws --ws.addr $WS_ADDR --ws.port $WS_PORT --ws.api $WS_API --ws.origins $WS_ORIGINS" ) --log.level $LOG_LEVEL"
echo "===================================================================" 