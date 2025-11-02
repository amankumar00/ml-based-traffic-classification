#!/bin/bash
# Wrapper script to run topology with system Python and Mininet

# Add system packages to Python path for Mininet
export PYTHONPATH="/usr/lib/python3/dist-packages:$PYTHONPATH"

# Run with sudo using system Python3
sudo -E env "PATH=$PATH" "PYTHONPATH=$PYTHONPATH" python3 topology/custom_topo.py "$@"
