# Quick Test Guide - Fixed Controller

The controller has been updated to save packets every 30 seconds automatically!

## Terminal 1: Start Controller

```bash
conda activate ml-sdn
cd /home/hello/Desktop/ML_SDN
ryu-manager src/controller/sdn_controller.py --verbose
```

**What to watch for:**
- "Switch connected" message when Mininet starts
- "Periodic save completed" messages every 30 seconds (if packets captured)
- "Saved X packets to data/raw/captured_packets_*.json" messages

## Terminal 2: Generate Traffic

```bash
cd /home/hello/Desktop/ML_SDN
sudo -E env "PYTHONPATH=/usr/lib/python3/dist-packages:$PYTHONPATH" python3 topology/custom_topo.py --topology custom --traffic mixed --duration 60
```

**Or use the wrapper:**
```bash
./scripts/run_topology.sh --topology custom --traffic mixed --duration 60
```

**What happens:**
- Mininet creates a network with 3 switches and 9 hosts
- Generates mixed traffic (ICMP, HTTP, FTP) for 60 seconds
- Controller captures all packets
- Packets are automatically saved every 30 seconds

## Terminal 3: Analyze Traffic (After 30+ seconds)

```bash
conda activate ml-sdn
cd /home/hello/Desktop/ML_SDN

# Check captured files
ls -lh data/raw/

# Extract features
python src/traffic_monitor/feature_extractor.py data/raw/captured_packets_*.json data/processed/features.csv

# Classify traffic
python src/ml_models/classifier.py data/models/ data/processed/features.csv
```

## Expected Output

### After 30 seconds in Terminal 1:
```
Periodic save completed
Saved 237 packets to data/raw/captured_packets_1234567890.json
```

### In Terminal 3:
```
$ ls -lh data/raw/
-rw-r--r-- 1 user user 145K captured_packets_1234567890.json
-rw-r--r-- 1 user user 132K captured_packets_1234567920.json

$ python src/traffic_monitor/feature_extractor.py ...
Extracted 87 flows from 369 packets
Features saved to data/processed/features.csv

$ python src/ml_models/classifier.py ...
Loading random_forest model...
Classified 87 flows:
  Flow 1: HTTP (confidence: 0.89)
  Flow 2: ICMP (confidence: 0.95)
  ...
```

## Troubleshooting

### No packets captured?
1. Make sure controller is running BEFORE starting Mininet
2. Check controller output for "Switch connected" message
3. Try running traffic generation for longer (--duration 60 or more)

### "data/raw/ is empty"?
- Wait at least 30 seconds for periodic save
- Or generate enough traffic to hit 10,000 packet buffer limit

### Mininet errors?
```bash
# Clean up old Mininet sessions
sudo mn -c

# Try again
./scripts/run_topology.sh --topology custom --traffic mixed --duration 60
```
