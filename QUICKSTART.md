# ML-SDN Traffic Classification - Quick Start Guide

## Complete Commands from Beginning

### Step 1: One-Time Setup (if not done already)

```bash
# Navigate to project
cd /home/hello/Desktop/ML_SDN

# Create conda environment
conda env create -f environment.yml

# Activate environment
conda activate ml-sdn
```

### Step 2: Run Automated Traffic Classification

**This is the ONLY command you need to run each time:**

```bash
cd /home/hello/Desktop/ML_SDN
conda activate ml-sdn
./scripts/automated_traffic_classification.sh
```

This will automatically:
1. Clean old data
2. Start Ryu controller
3. Generate **balanced traffic** (2 flows of each type):
   - **HTTP** flows (h3→h1:80, h4→h2:8080)
   - **FTP** flows (h5→h3:21, h6→h4:21)
   - **SSH** flows (h1→h5:22, h2→h6:22) - Interactive, ~25 pkt/sec
   - **VIDEO** flows (h3→h1:5004, h4→h2:5006) - Streaming, ~120 pkt/sec, 1200-byte packets
4. Stop controller
5. Extract features
6. Classify flows
7. Generate CSV files

### Step 3: View Results

```bash
# View host-to-host traffic classification
cat data/processed/host_to_host_flows.csv

# Or open in spreadsheet
libreoffice data/processed/host_to_host_flows.csv
```

## Expected Output

The CSV file will contain:

**Expected Traffic Types:**
- HTTP: 2 flows
- FTP: 2 flows  
- SSH: 2 flows
- VIDEO: 2 flows

## Troubleshooting

```bash
# Check controller log
cat /tmp/ryu_controller.log

# Clean Mininet
sudo mn -c

# Kill stuck processes
sudo pkill -f ryu-manager
```

That's it!
