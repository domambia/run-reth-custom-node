#!/bin/bash

# ======================================================================
# Geth Ethereum Node and Lighthouse Consensus Client Runner Script
# ======================================================================
# This script runs a Geth node on Ethereum mainnet and a Lighthouse consensus client.
# Customize the parameters below as needed.
# ======================================================================

# Configuration Variables - Customize these as needed
# ======================================================================

# Geth Configuration
GETH_DATA_DIR="/home/pexilabs/externals/nodes-apps/run-geth-custom-node/geth"
GETH_LOG_DIR="/home/pexilabs/externals/nodes-apps/run-geth-custom-node/geth-logs"
GETH_CHAIN="mainnet"
GETH_NODE_TYPE="full"  # Options: full, archive

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
JWT_SECRET="$GETH_DATA_DIR/$GETH_CHAIN/jwt.hex"

LOG_LEVEL="3"  # 0 = panic, 1 = fatal, 2 = error, 3 = warn, 4 = info, 5 = debug, 6 = detail, 7 = trace

DISCOVERY_PORT="30303"
MAX_PEERS="50"

# Lighthouse Configuration
LIGHTHOUSE_DATA_DIR="/home/pexilabs/externals/nodes-apps/run-lighthouse-custom-node/lighthouse"
LIGHTHOUSE_LOG_DIR="/home/pexilabs/externals/nodes-apps/run-lighthouse-custom-node/lighthouse-logs"

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

create_systemd_service() {
    local service_name="geth-node"
    local user=$(whoami)
    local script_path=$(readlink -f "$0")
    local script_dir=$(dirname "$script_path")

    cat > "${script_dir}/${service_name}.service" <<EOL
[Unit]
Description=Geth Ethereum Node
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

    cat > "${script_dir}/${service_name}.service" <<EOL
[Unit]
Description=Lighthouse Ethereum Consensus Client
After=network.target geth-node.service
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

    echo "Consensus service created: ${script_dir}/${service_name}.service"
}

# ======================================================================
# Script Logic
# ======================================================================

if [ "$1" = "--create-service" ]; then
    create_systemd_service
    exit 0
elif [ "$1" = "--create-consensus-service" ]; then
    create_consensus_service
    exit 0
elif [ "$1" = "--help" ]; then
    echo "Usage: $0 [OPTION]"
    echo "  --create-service          Create systemd service file for Geth node"
    echo "  --create-consensus-service Create systemd service for Lighthouse"
    echo "  --help                    Show this help message"
    exit 0
fi

mkdir -p "$GETH_DATA_DIR/$GETH_CHAIN"
generate_jwt_secret

if ! command -v geth &> /dev/null; then
    echo "Error: geth not installed or not in PATH"
    exit 1
fi

CMD="geth --datadir \"$GETH_DATA_DIR\" --networkid 1"

# Add sync mode
if [ "$GETH_NODE_TYPE" = "archive" ]; then
    CMD="$CMD --syncmode=snap --gcmode=archive"
else
    CMD="$CMD --syncmode=snap --gcmode=full"
fi

# Add RPC options
if [ "$ENABLE_HTTP" = "true" ]; then
    CMD="$CMD --http --http.addr \"$HTTP_ADDR\" --http.port \"$HTTP_PORT\" --http.api \"$HTTP_API\""
    [ -n "$HTTP_CORSDOMAIN" ] && CMD="$CMD --http.corsdomain \"$HTTP_CORSDOMAIN\""
fi

if [ "$ENABLE_WS" = "true" ]; then
    CMD="$CMD --ws --ws.addr \"$WS_ADDR\" --ws.port \"$WS_PORT\" --ws.api \"$WS_API\""
    [ -n "$WS_ORIGINS" ] && CMD="$CMD --ws.origins \"$WS_ORIGINS\""
fi

# Auth RPC for consensus
CMD="$CMD --authrpc.addr \"$AUTH_ADDR\" --authrpc.port \"$AUTH_PORT\" --authrpc.jwtsecret \"$JWT_SECRET\""

# P2P config
CMD="$CMD --port \"$DISCOVERY_PORT\" --maxpeers \"$MAX_PEERS\""

# Logging level
CMD="$CMD --verbosity $LOG_LEVEL"

# Start node
echo "==================================================================="
echo "Starting Geth $GETH_CHAIN node in $GETH_NODE_TYPE mode"
echo "==================================================================="
echo "Data directory: $GETH_DATA_DIR"
echo "JWT Secret: $JWT_SECRET"
[ "$ENABLE_HTTP" = "true" ] && echo "HTTP RPC: http://$HTTP_ADDR:$HTTP_PORT"
[ "$ENABLE_WS" = "true" ] && echo "WebSocket: ws://$WS_ADDR:$WS_PORT"
echo "Engine API: http://$AUTH_ADDR:$AUTH_PORT"
echo "Discovery Port: $DISCOVERY_PORT"
echo "Log Level: $LOG_LEVEL"
echo "==================================================================="
echo "Reminder: Run a consensus client (e.g., Lighthouse) alongside Geth"
echo "==================================================================="

eval $CMD


# Run Lighthouse
# Ensure Lighthouse systemd service is created and started properly
# Ensure the JWT file is accessible for both Geth and Lighthouse

# Run RETH: ./run_reth_node.sh --create-service
# Run Lighthouse (consensus client) ./run_reth_node.sh --create-consensus-service

# sudo journalctl -u geth-node.service -n 100
# sudo journalctl -u lighthouse-node.service -n 100

# Run RETH: ./run_reth_node.sh --create-service
# Run Lighthouse (consensus client) ./run_reth_node.sh --create-consensus-service

# sudo journalctl -u reth-node.service -n 100
# sudo journalctl -u lighthouse-node.service -n 100
