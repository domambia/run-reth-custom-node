#!/bin/bash

# ======================================================================
# Log Pruning Script for Reth and Lighthouse
# ======================================================================
# Deletes log files older than 30 minutes in the Reth and Lighthouse log directories.
#
# Usage:
#   ./prune_logs.sh
#
# To run every 30 minutes via cron, add this line to your crontab:
#   */30 * * * * /path/to/prune_logs.sh
#
# You can override the log directories by setting the environment variables:
#   RETH_LOG_DIR or LIGHTHOUSE_LOG_DIR
# ======================================================================

# Default log directories
RETH_LOG_DIR="${RETH_LOG_DIR:-$HOME/.local/share/reth/logs}"
LIGHTHOUSE_LOG_DIR="${LIGHTHOUSE_LOG_DIR:-$HOME/.local/share/lighthouse/logs}"

# Find and delete log files older than 30 minutes
find_and_prune() {
  local dir="$1"
  if [ -d "$dir" ]; then
    echo "Pruning logs in $dir ..."
    find "$dir" -type f -name "*.log" -mmin +30 -print -delete
  else
    echo "Log directory $dir does not exist, skipping."
  fi
}

find_and_prune "$RETH_LOG_DIR"
find_and_prune "$LIGHTHOUSE_LOG_DIR"

echo "Log pruning complete." 