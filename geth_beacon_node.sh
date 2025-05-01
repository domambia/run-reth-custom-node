#!/bin/bash

# =============================
# Geth + Lighthouse Quick Setup
# =============================

# Geth Config
GETH_DATA_DIR="/root/geth"
GETH_LOG_DIR="/root/geth-logs"
GETH_CHAIN="mainnet"
GETH_NODE_TYPE="full"
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
LOG_LEVEL="3"
DISCOVERY_PORT="30303"
MAX_PEERS="50"

# Lighthouse Config
LIGHTHOUSE_BIN="/root/.cargo/bin/lighthouse"
LIGHTHOUSE_DATA_DIR="/root/lighthouse"
LIGHTHOUSE_LOG_DIR="/root/lighthouse-logs"

# Create directories
mkdir -p "$GETH_DATA_DIR/$GETH_CHAIN" "$GETH_LOG_DIR" "$LIGHTHOUSE_DATA_DIR" "$LIGHTHOUSE_LOG_DIR"

# Generate JWT if missing
if [ ! -f "$JWT_SECRET" ]; then
  echo "Generating JWT secret..."
  openssl rand -hex 32 > "$JWT_SECRET"
  chmod 600 "$JWT_SECRET"
fi

# Start Geth
GETH_CMD=(
  geth
  --datadir "$GETH_DATA_DIR"
  --networkid 1
  --port "$DISCOVERY_PORT"
  --maxpeers "$MAX_PEERS"
  --verbosity "$LOG_LEVEL"
  --authrpc.addr "$AUTH_ADDR"
  --authrpc.port "$AUTH_PORT"
  --authrpc.jwtsecret "$JWT_SECRET"
  --syncmode=snap
  --gcmode=full
)

if [ "$ENABLE_HTTP" = "true" ]; then
  GETH_CMD+=(--http --http.addr "$HTTP_ADDR" --http.port "$HTTP_PORT" --http.api "$HTTP_API")
  [ -n "$HTTP_CORSDOMAIN" ] && GETH_CMD+=(--http.corsdomain "$HTTP_CORSDOMAIN")
fi

if [ "$ENABLE_WS" = "true" ]; then
  GETH_CMD+=(--ws --ws.addr "$WS_ADDR" --ws.port "$WS_PORT" --ws.api "$WS_API")
  [ -n "$WS_ORIGINS" ] && GETH_CMD+=(--ws.origins "$WS_ORIGINS")
fi

echo "Starting Geth..."
nohup "${GETH_CMD[@]}" >> "$GETH_LOG_DIR/geth.log" 2>&1 &
echo "Geth started. Logs: $GETH_LOG_DIR/geth.log"

# Start Lighthouse
LIGHTHOUSE_CMD=(
  "$LIGHTHOUSE_BIN" beacon_node
  --network mainnet
  --datadir "$LIGHTHOUSE_DATA_DIR"
  --execution-endpoint "http://$AUTH_ADDR:$AUTH_PORT"
  --execution-jwt "$JWT_SECRET"
  --checkpoint-sync-url https://mainnet.checkpoint.sigp.io
  --metrics
  --validator-monitor-auto
)

echo "Starting Lighthouse..."
nohup "${LIGHTHOUSE_CMD[@]}" >> "$LIGHTHOUSE_LOG_DIR/lighthouse.log" 2>&1 &
echo "Lighthouse started. Logs: $LIGHTHOUSE_LOG_DIR/lighthouse.log"

# Done
echo "=========================================================="
echo " Both Geth (Execution) and Lighthouse (Consensus) started"
echo " Beacon Chain architecture is now active on mainnet"
echo "=========================================================="
