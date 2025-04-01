#!/bin/bash

# Get the first non-empty IP address
SERVER_IP=$(hostname -I | awk '{print $1}')

# Check if SERVER_IP is empty
if [[ -z "$SERVER_IP" ]]; then
    echo "Error: Unable to retrieve server IP." >&2
    exit 1
else
    echo "$SERVER_IP"
fi