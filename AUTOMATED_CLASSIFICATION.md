# Automated Traffic Classification

## Quick Start

Run the entire pipeline with a single command:

```bash
cd /home/hello/Desktop/ML_SDN
./scripts/automated_traffic_classification.sh
```

## What It Does

This script automates the entire workflow:

1. **Cleans** old data files
2. **Cleans** Mininet (before starting controller)
3. **Starts** Ryu controller in background
4. **Generates** network traffic for 90 seconds (NO ICMP)
   - HTTP flows (ports 80, 8080)
   - FTP flows (port 21)
   - SSH flows (ports 22, 2222)
   - VIDEO UDP flows (ports 5004, 5006)
5. **Stops** controller
6. **Extracts** flow features
7. **Classifies** flows using ML models
8. **Generates** host-to-host CSV file

## Output Files

After completion, you'll find:

- **`data/processed/host_to_host_flows.csv`** - Main output with host-to-host traffic
  - Columns: flow_id, src_host, dst_host, src_ip, dst_ip, src_port, dst_port, protocol, traffic_type, confidence, total_packets, total_bytes, flow_duration, packets_per_second

- **`data/processed/flow_classification.csv`** - Full classification (includes IPv6 traffic)

- **`data/processed/features.csv`** - Extracted flow features

- **`/tmp/ryu_controller.log`** - Controller debug log

## Example Output

```
Total host-to-host flows: 272

Traffic Type Distribution:
  FTP       :  258 flows ( 94.9%)
  HTTP      :   14 flows (  5.1%)

Flows Grouped by Host Pairs:
Source   Dest     Type          Flows
--------------------------------------------
h1       h3       FTP              88
h1       h3       HTTP              2
h1       h5       FTP              41
h1       h5       HTTP              4
h2       h4       FTP              87
h2       h4       HTTP              3
h2       h6       FTP              42
h2       h6       HTTP              3
```

## Requirements

- Conda environment `ml-sdn` must be activated
- Trained models in `data/models/` (already present)
- Run with sudo privileges (for Mininet)

## Troubleshooting

If the script fails:

1. **Check controller log**: `cat /tmp/ryu_controller.log`
2. **Ensure conda environment exists**: `conda env list`
3. **Clean Mininet manually**: `sudo mn -c`
4. **Check for running processes**: `ps aux | grep ryu`

## Manual Step-by-Step (if needed)

If you prefer to run steps manually:

```bash
# Terminal 1 - Controller
conda activate ml-sdn
cd /home/hello/Desktop/ML_SDN
ryu-manager src/controller/sdn_controller.py --verbose

# Terminal 2 - Traffic generation
cd /home/hello/Desktop/ML_SDN
./scripts/no_icmp_traffic.sh

# Terminal 3 - After traffic completes, classify
conda activate ml-sdn
cd /home/hello/Desktop/ML_SDN
python src/traffic_monitor/feature_extractor.py data/raw/captured_packets_*.json data/processed/features.csv
python src/ml_models/classify_and_export.py data/models/ data/processed/features.csv data/processed/flow_classification.csv
(head -1 data/processed/flow_classification.csv; grep '^[0-9]*,h[0-9]' data/processed/flow_classification.csv) > data/processed/host_to_host_flows.csv
```

## Model Information

The ML models (Random Forest, SVM, Neural Network) were trained on 800 samples:
- FTP: 200 samples
- HTTP: 200 samples
- SSH: 200 samples
- VIDEO: 200 samples

**Note**: ICMP was removed from the models since we're generating NO ICMP traffic.

All models achieved 100% accuracy on test data.
