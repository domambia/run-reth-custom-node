#!/bin/bash

# ======================================================================
# Reth Ethereum Node Runner Script
# ======================================================================
# This script runs a Reth node on Ethereum mainnet with HTTP RPC and
# WebSocket support. Customize the parameters below as needed.
# 
# By default, this runs as an archive node. To run as a full node
# (which saves disk space), uncomment the --full flag option.

# ======================================================================
# Configuration Variables - Customize these as needed
# ======================================================================

# Node Configuration
DATA_DIR="$HOME/.local/share/reth"
CHAIN="mainnet"  # Options: mainnet, sepolia, holesky, hoodi, dev
NODE_TYPE="archive"  # Options: archive, full

# RPC Configuration
ENABLE_HTTP="true"
HTTP_ADDR="127.0.0.1"  # Use 0.0.0.0 to allow external connections
HTTP_PORT="8545"
HTTP_API="eth,net,web3,txpool,debug"  # Available: admin, debug, eth, net, trace, txpool, web3, rpc, etc.
HTTP_CORSDOMAIN="*"  # Use "*" to allow all origins or a comma-separated list

# WebSocket Configuration
ENABLE_WS="true"
WS_ADDR="127.0.0.1"  # Use 0.0.0.0 to allow external connections
WS_PORT="8546"
WS_API="eth,net,web3,txpool"
WS_ORIGINS="*"  # Use "*" to allow all origins or a comma-separated list

# Auth RPC Configuration (for Consensus Layer connection)
AUTH_ADDR="127.0.0.1"
AUTH_PORT="8551"
JWT_SECRET="$DATA_DIR/$CHAIN/jwt.hex"

# Logging Configuration
LOG_LEVEL="info"  # Options: error, warn, info, debug, trace

# P2P Network Configuration
DISCOVERY_PORT="30303"
MAX_PEERS="50"  # Total peers will be split between inbound and outbound

# ======================================================================
# Functions
# ======================================================================

# Function to generate JWT secret if it doesn't exist
generate_jwt_secret() {
    if [ ! -f "$JWT_SECRET" ]; then
        echo "Generating JWT secret at $JWT_SECRET"
        mkdir -p "$(dirname "$JWT_SECRET")"
        
        if command -v openssl &> /dev/null; then
            # Generate 32 random bytes and convert to hex
            openssl rand -hex 32 > "$JWT_SECRET"
        else
            # Fallback method if openssl is not available
            head -c 32 /dev/urandom | xxd -p -c 32 > "$JWT_SECRET"
        fi
        
        # Set permissions to be readable only by owner
        chmod 600 "$JWT_SECRET"
        
        echo "JWT secret generated successfully"
    fi
}

# Function to create systemd service files
create_systemd_service() {
    local service_name="reth-node"
    local user=$(whoami)
    local script_path=$(readlink -f "$0")
    local script_dir=$(dirname "$script_path")
    
    # Create systemd service file
    cat > "${script_dir}/${service_name}.service" <<EOL
[Unit]
Description=Reth Ethereum Node
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=${user}
ExecStart=${script_path}
Restart=on-failure
RestartSec=10
LimitNOFILE=1000000
WorkingDirectory=${script_dir}

[Install]
WantedBy=multi-user.target
EOL
    
    echo "========================================================================"
    echo "Systemd service file created at ${script_dir}/${service_name}.service"
    echo ""
    echo "To install the service, run:"
    echo "  sudo cp ${script_dir}/${service_name}.service /etc/systemd/system/"
    echo "  sudo systemctl daemon-reload"
    echo "  sudo systemctl enable ${service_name}.service"
    echo "  sudo systemctl start ${service_name}.service"
    echo ""
    echo "To check service status:"
    echo "  sudo systemctl status ${service_name}.service"
    echo ""
    echo "To view logs:"
    echo "  sudo journalctl -u ${service_name}.service -f"
    echo "========================================================================"
}

# Function to create consensus client service
create_consensus_service() {
    local service_name="lighthouse-node"
    local user=$(whoami)
    local script_dir=$(dirname $(readlink -f "$0"))
    
    # Create systemd service file for Lighthouse
    cat > "${script_dir}/${service_name}.service" <<EOL
[Unit]
Description=Lighthouse Ethereum Consensus Client
After=network.target reth-node.service
Wants=network-online.target

[Service]
Type=simple
User=${user}
ExecStart=/usr/local/bin/lighthouse bn \\
    --checkpoint-sync-url https://mainnet.checkpoint.sigp.io \\
    --execution-endpoint http://${AUTH_ADDR}:${AUTH_PORT} \\
    --execution-jwt ${JWT_SECRET} \\
    --metrics \\
    --validator-monitor-auto
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
# Script Logic - You generally shouldn't need to modify below this line
# ======================================================================

# Process command line arguments
if [ "$1" = "--create-service" ]; then
    create_systemd_service
    exit 0
elif [ "$1" = "--create-consensus-service" ]; then
    create_consensus_service
    exit 0
elif [ "$1" = "--help" ]; then
    echo "Usage: $0 [OPTION]"
    echo "  --create-service          Create systemd service file for Reth node"
    echo "  --create-consensus-service Create systemd service file for consensus client"
    echo "  --help                    Display this help message"
    exit 0
fi

# Create the data directory if it doesn't exist
mkdir -p "$DATA_DIR/$CHAIN"

# Generate JWT secret if it doesn't exist
generate_jwt_secret

# Check if reth is installed
if ! command -v reth &> /dev/null; then
    echo "Error: reth is not installed or not in PATH"
    echo "Please install reth first: https://reth.rs/installation/installation.html"
    exit 1
fi

# Build command based on configuration
CMD="reth node --datadir \"$DATA_DIR\" --chain $CHAIN"

# Add HTTP RPC options if enabled
if [ "$ENABLE_HTTP" = "true" ]; then
    CMD="$CMD --http --http.addr \"$HTTP_ADDR\" --http.port \"$HTTP_PORT\" --http.api \"$HTTP_API\""
    
    if [ -n "$HTTP_CORSDOMAIN" ]; then
        CMD="$CMD --http.corsdomain \"$HTTP_CORSDOMAIN\""
    fi
fi

# Add WebSocket RPC options if enabled
if [ "$ENABLE_WS" = "true" ]; then
    CMD="$CMD --ws --ws.addr \"$WS_ADDR\" --ws.port \"$WS_PORT\" --ws.api \"$WS_API\""
    
    if [ -n "$WS_ORIGINS" ]; then
        CMD="$CMD --ws.origins \"$WS_ORIGINS\""
    fi
fi

# Add Auth RPC options for consensus layer connection
CMD="$CMD --authrpc.addr \"$AUTH_ADDR\" --authrpc.port \"$AUTH_PORT\" --authrpc.jwtsecret \"$JWT_SECRET\""

# Add logging options
CMD="$CMD --verbosity \"$LOG_LEVEL\""

# P2P networking options
CMD="$CMD --discovery.port \"$DISCOVERY_PORT\""

# Add node type
if [ "$NODE_TYPE" = "full" ]; then
    CMD="$CMD --full"
fi

# Print configuration summary
echo "==================================================================="
echo "Starting Reth $CHAIN node in $NODE_TYPE mode"
echo "==================================================================="
echo "Data directory: $DATA_DIR"
echo "JWT Secret: $JWT_SECRET"

if [ "$ENABLE_HTTP" = "true" ]; then
    echo "HTTP RPC: Enabled at http://$HTTP_ADDR:$HTTP_PORT"
    echo "HTTP APIs: $HTTP_API"
else
    echo "HTTP RPC: Disabled"
fi

if [ "$ENABLE_WS" = "true" ]; then
    echo "WebSocket: Enabled at ws://$WS_ADDR:$WS_PORT"
    echo "WS APIs: $WS_API"
else
    echo "WebSocket: Disabled"
fi

echo "Engine API: http://$AUTH_ADDR:$AUTH_PORT"
echo "Discovery Port: $DISCOVERY_PORT"
echo "Log Level: $LOG_LEVEL"
echo "==================================================================="
echo "Remember: You need to run a consensus client to sync with the network!"
echo "Example: lighthouse bn --checkpoint-sync-url https://mainnet.checkpoint.sigp.io \\"
echo "                       --execution-endpoint http://$AUTH_ADDR:$AUTH_PORT \\"
echo "                       --execution-jwt \"$JWT_SECRET\""
echo "==================================================================="
echo "TIP: Run with --create-service to create a systemd service file"
echo "TIP: Run with --create-consensus-service to create a consensus client service file"
echo "==================================================================="
echo "Starting node..."
echo "Press Ctrl+C to stop"
echo ""

# Execute the command
eval $CMD

# Note: The script will continue running until the node is terminated
# To stop, press Ctrl+C 