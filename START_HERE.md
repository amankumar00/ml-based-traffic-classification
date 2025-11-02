# 🚀 START HERE - ML-SDN Quick Start

## Step 1: First Time Setup (5 minutes)

Run this **ONE COMMAND** to set everything up:

```bash
cd /home/hello/Desktop/ML_SDN
./scripts/setup_python38.sh
```

This will:
- ✅ Install Python 3.8 environment
- ✅ Install all dependencies (Ryu, ML libraries)
- ✅ Install Mininet for network simulation
- ✅ Generate sample training data
- ✅ Train an initial ML model

**You only need to do this once!**

---

## Step 2: Verify Setup

```bash
./scripts/test_system.sh
```

This checks that everything is installed correctly.

---

## Step 3: Run the System

Open **3 terminals** and run these commands:

### 📟 Terminal 1: Start SDN Controller
```bash
cd /home/hello/Desktop/ML_SDN
source venv/bin/activate
ryu-manager src/controller/sdn_controller.py --verbose
```
*Keep this running - it monitors network traffic*

### 🌐 Terminal 2: Start Network
```bash
cd /home/hello/Desktop/ML_SDN
sudo python topology/custom_topo.py --topology custom
```
*This creates a virtual network with 9 hosts*

In Mininet CLI, generate traffic:
```bash
mininet> pingall          # Test connectivity
mininet> h1 ping -c 50 h2 # Generate ICMP traffic
mininet> iperf h1 h2      # Generate TCP traffic
mininet> exit             # When done
```

### 📊 Terminal 3: Analyze Traffic
```bash
cd /home/hello/Desktop/ML_SDN
source venv/bin/activate

# Extract features from captured packets
python src/traffic_monitor/feature_extractor.py \
    data/raw/captured_packets_*.json \
    data/processed/features.csv

# Classify the traffic
python src/ml_models/classifier.py \
    data/models/ \
    data/processed/features.csv
```

---

## Quick Test (Automated)

Want to test quickly? Run this in Terminal 2 instead:

```bash
sudo python topology/custom_topo.py --topology custom --traffic mixed --duration 30
```

This automatically generates traffic for 30 seconds, then you can analyze it in Terminal 3.

---

## Project Overview

```
┌─────────────────────────────────────────────────────┐
│                  Ryu SDN Controller                 │
│         (Monitors & Captures Traffic)               │
└──────────────────┬──────────────────────────────────┘
                   │
         ┌─────────┴─────────┐
         │                   │
    ┌────▼────┐         ┌────▼────┐         ┌──────────┐
    │ Switch1 │─────────│ Switch2 │─────────│ Switch3  │
    └─┬──┬──┬─┘         └─┬──┬──┬─┘         └─┬──┬──┬──┘
      │  │  │             │  │  │             │  │  │
    h1 h2 h3           h4 h5 h6           h7 h8 h9

                   Traffic flows captured
                          ↓
              ┌───────────────────────┐
              │  Feature Extraction   │
              │  (28+ features)       │
              └───────────┬───────────┘
                          ↓
              ┌───────────────────────┐
              │   ML Classification   │
              │  (Random Forest/SVM)  │
              └───────────────────────┘
                          ↓
                HTTP, FTP, SSH, ICMP, VIDEO
```

---

## What Each Component Does

### 🎯 SDN Controller (Ryu)
- Monitors all network traffic
- Captures packet details (size, protocols, ports, timing)
- Saves data to `data/raw/`

### 🌐 Mininet Network
- Simulates a real network with virtual switches and hosts
- Creates traffic between nodes
- Connects to the controller via OpenFlow

### 🤖 ML Classifier
- Extracts features from captured packets
- Uses trained models to identify traffic types
- Reports classification results with confidence scores

---

## Traffic Types Classified

- **HTTP/HTTPS**: Web traffic
- **FTP**: File transfers
- **SSH**: Secure shell connections
- **ICMP**: Ping and diagnostics
- **VIDEO**: Streaming media

You can train models for additional traffic types!

---

## Folder Structure

```
ML_SDN/
├── src/
│   ├── controller/sdn_controller.py    ← Ryu controller
│   ├── traffic_monitor/feature_extractor.py  ← Extract features
│   └── ml_models/
│       ├── train.py                    ← Train models
│       └── classifier.py               ← Classify traffic
├── topology/custom_topo.py             ← Network topologies
├── data/
│   ├── raw/                            ← Captured packets
│   ├── processed/                      ← Extracted features
│   └── models/                         ← Trained ML models
└── scripts/                            ← Setup & utility scripts
```

---

## Common Commands

### Check if setup is complete
```bash
./scripts/check_python.sh     # Check Python versions
./scripts/test_system.sh      # Test all components
```

### Different topologies
```bash
--topology custom    # 3 switches, 9 hosts (default)
--topology linear    # Simple chain topology
--topology star      # 6 hosts, 1 switch
```

### Generate different traffic types
```bash
--traffic icmp      # Ping traffic
--traffic http      # Web traffic
--traffic iperf     # Bandwidth tests
--traffic mixed     # All types
```

### Train different models
```bash
python src/ml_models/train.py data.csv random_forest models/  # Fast
python src/ml_models/train.py data.csv svm models/           # Accurate
python src/ml_models/train.py data.csv neural_network models/ # Advanced
```

---

## Troubleshooting

### Setup failed?
```bash
./scripts/check_python.sh  # Check Python 3.8 is installed
```

### Controller won't start?
```bash
source venv/bin/activate   # Activate venv first
python --version           # Should be 3.8.x
```

### Mininet connection issues?
```bash
sudo mn -c                 # Clean up old sessions
```

### No packets captured?
1. Make sure controller is running (Terminal 1)
2. Generate traffic in Mininet (Terminal 2)
3. Check `ls data/raw/` for captured files

---

## Documentation

- **[HOW_TO_RUN.md](HOW_TO_RUN.md)** ← **Read this for detailed instructions**
- [QUICKSTART.md](QUICKSTART.md) - Quick reference guide
- [README.md](README.md) - Full project documentation
- [PYTHON38_SETUP.md](PYTHON38_SETUP.md) - Python setup details
- [INSTALL.md](INSTALL.md) - Installation troubleshooting

---

## Need Help?

1. **First time?** Run `./scripts/setup_python38.sh`
2. **Check status:** Run `./scripts/test_system.sh`
3. **Read guide:** Open [HOW_TO_RUN.md](HOW_TO_RUN.md)
4. **Check versions:** Run `./scripts/check_python.sh`

---

## Summary

```bash
# One-time setup
./scripts/setup_python38.sh

# Every time you run (3 terminals):
# Terminal 1: source venv/bin/activate && ryu-manager src/controller/sdn_controller.py --verbose
# Terminal 2: sudo python topology/custom_topo.py --topology custom
# Terminal 3: source venv/bin/activate && analyze traffic
```

**🎉 That's it! You're ready to classify network traffic with ML!**
