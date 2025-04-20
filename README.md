# Reth Ethereum Node Runner

This repository contains a bash script to run a [Reth](https://reth.rs/) Ethereum node with HTTP RPC and WebSocket support, optimized for Ubuntu/Linux systems.

## Prerequisites

- Reth installed on your system (see [installation instructions](https://reth.rs/installation/installation.html))
- A consensus client (like Lighthouse) for post-merge Ethereum networks
- Enough disk space for the blockchain data (varies by network and node type)

## Usage

1. Clone this repository or download the `run_reth_node.sh` script
2. Make the script executable:
   ```
   chmod +x run_reth_node.sh
   ```
3. Edit the configuration variables at the top of the script to customize your node
4. Run the script:
   ```
   ./run_reth_node.sh
   ```

## Features

- Automatic JWT secret generation for consensus client authentication
- Systemd service creation for running as a background service
- Support for both HTTP RPC and WebSocket RPC
- Configurable API endpoints and CORS settings
- Support for running in full or archive node mode

## Command Line Options

The script supports several command-line options:

```
./run_reth_node.sh [OPTION]
  --create-service          Create systemd service file for Reth node
  --create-consensus-service Create systemd service file for consensus client
  --help                    Display help message
```

## Running as a Systemd Service

To set up the Reth node as a systemd service on Ubuntu/Linux:

1. Create the service file:

   ```
   ./run_reth_node.sh --create-service
   ```

2. Follow the on-screen instructions to install the service:

   ```
   sudo cp /path/to/reth-node.service /etc/systemd/system/
   sudo systemctl daemon-reload
   sudo systemctl enable reth-node.service
   sudo systemctl start reth-node.service
   ```

3. Monitor the service:
   ```
   sudo systemctl status reth-node.service
   sudo journalctl -u reth-node.service -f
   ```

## Setting up a Consensus Client Service

Similarly, you can create a systemd service for the Lighthouse consensus client:

1. Create the service file:

   ```
   ./run_reth_node.sh --create-consensus-service
   ```

2. Follow the on-screen instructions to install the service.

## Configuration Options

The script includes several configuration variables that you can modify:

### Node Configuration

- `DATA_DIR`: Directory to store blockchain data
- `CHAIN`: The Ethereum network to connect to (mainnet, sepolia, holesky, etc.)
- `NODE_TYPE`: Either "archive" (full history) or "full" (pruned storage)

### RPC Configuration

- `ENABLE_HTTP`: Whether to enable HTTP RPC
- `HTTP_ADDR` and `HTTP_PORT`: Address and port for HTTP RPC
- `HTTP_API`: Comma-separated list of enabled APIs
- `HTTP_CORSDOMAIN`: CORS domains for HTTP RPC

### WebSocket Configuration

- `ENABLE_WS`: Whether to enable WebSocket RPC
- `WS_ADDR` and `WS_PORT`: Address and port for WebSocket RPC
- `WS_API`: Comma-separated list of enabled APIs
- `WS_ORIGINS`: Allowed origins for WebSocket connections

### Additional Options

- `AUTH_ADDR` and `AUTH_PORT`: Address and port for Engine API (consensus client connection)
- `JWT_SECRET`: Path to JWT secret file for consensus client authentication
- `LOG_LEVEL`: Verbosity level for logging
- `DISCOVERY_PORT`: Port for peer discovery
- `MAX_PEERS`: Maximum number of peers to connect to

## JWT Secret Generation

The script automatically generates a JWT secret file at the specified location if one doesn't exist. This secret is required for secure communication between the execution client (Reth) and the consensus client (e.g., Lighthouse).

## Running a Consensus Client

After Ethereum's switch to Proof of Stake, you must run a consensus client alongside Reth. For example, to run Lighthouse:

```bash
lighthouse bn \
    --checkpoint-sync-url https://mainnet.checkpoint.sigp.io \
    --execution-endpoint http://127.0.0.1:8551 \
    --execution-jwt /path/to/jwt.hex
```

The JWT secret is automatically generated in your data directory.

## Security Considerations

- By default, the RPC interfaces only listen on localhost (`127.0.0.1`). To allow external connections, change the address to `0.0.0.0`, but be aware of the security implications.
- Be cautious when enabling APIs like "debug" or "admin" which can expose sensitive functionality.
- Consider setting up a firewall to restrict access to your node's ports.
- The generated JWT secret file has permissions set to 600 (readable only by the owner) for security.

## Customization

Feel free to modify the script to add more configuration options or adjust existing ones. The script is designed to be easy to understand and customize.

## License

This script is provided under the MIT License.
