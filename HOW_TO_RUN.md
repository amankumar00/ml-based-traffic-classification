# How to Run the ML-SDN Project

This guide will walk you through running the complete ML-based SDN traffic classification system.

## Prerequisites Setup (First Time Only)

### Step 1: Setup Python 3.8 Environment

```bash
cd /home/hello/Desktop/ML_SDN
./scripts/setup_python38.sh
```

This installs everything you need. **You only need to do this once.**

---

## Running the System

The system has **3 main components** that run in **3 separate terminals**:

### 🔷 Terminal 1: Ryu SDN Controller

The controller monitors network traffic and captures packets.

```bash
cd /home/hello/Desktop/ML_SDN

# Activate virtual environment
source venv/bin/activate

# Start Ryu controller
ryu-manager src/controller/sdn_controller.py --verbose
```

**What you'll see:**
```
loading app src/controller/sdn_controller.py
instantiating app src/controller/sdn_controller.py
BRICK TrafficMonitorController
  ...
```

**Keep this running!** The controller will:
- Listen for switch connections on port 6653
- Capture network packets
- Save data to `data/raw/captured_packets_*.json`

---

### 🔷 Terminal 2: Mininet Network Simulation

This creates a virtual network with switches and hosts.

```bash
cd /home/hello/Desktop/ML_SDN

# Start Mininet with custom topology
sudo python topology/custom_topo.py --topology custom
```

**What you'll see:**
```
*** Creating network
*** Starting network
*** Network started successfully
Switch connected: 0000000000000001
Switch connected: 0000000000000002
Switch connected: 0000000000000003
```

You'll enter the **Mininet CLI** where you can generate traffic:

```bash
mininet> pingall          # Test connectivity between all hosts
mininet> h1 ping -c 50 h2 # ICMP traffic from h1 to h2
mininet> iperf h1 h2      # TCP bandwidth test
```

**To exit Mininet:**
```bash
mininet> exit
```

---

### 🔷 Terminal 3: Process and Classify Traffic

After generating traffic, extract features and classify.

```bash
cd /home/hello/Desktop/ML_SDN

# Activate virtual environment
source venv/bin/activate

# Extract features from captured packets
python src/traffic_monitor/feature_extractor.py \
    data/raw/captured_packets_*.json \
    data/processed/features.csv

# Classify the traffic using trained model
python src/ml_models/classifier.py \
    data/models/ \
    data/processed/features.csv
```

**What you'll see:**
```
Extracted 45 flows
Features saved to data/processed/features.csv

Loading random_forest model...
Classified 45 flows:
  Flow 1: HTTP (Confidence: 0.92)
  Flow 2: SSH (Confidence: 0.88)
  ...
```

---

## Quick Example Workflow

Here's a complete example from start to finish:

### Terminal 1 - Start Controller
```bash
cd /home/hello/Desktop/ML_SDN
source venv/bin/activate
ryu-manager src/controller/sdn_controller.py --verbose
```
*Leave this running*

### Terminal 2 - Generate Traffic
```bash
cd /home/hello/Desktop/ML_SDN
sudo python topology/custom_topo.py --topology custom

# In Mininet CLI:
mininet> pingall
mininet> h1 ping -c 100 h2
mininet> iperf h1 h2
mininet> exit
```

### Terminal 3 - Analyze Traffic
```bash
cd /home/hello/Desktop/ML_SDN
source venv/bin/activate

# Extract features
python src/traffic_monitor/feature_extractor.py \
    data/raw/captured_packets_*.json \
    data/processed/test_features.csv

# Classify
python src/ml_models/classifier.py \
    data/models/ \
    data/processed/test_features.csv
```

---

## Traffic Generation Options

### Option 1: Manual Traffic in Mininet CLI

```bash
mininet> pingall                    # Ping all hosts
mininet> h1 ping -c 50 h2          # 50 ICMP packets
mininet> iperf h1 h2               # TCP bandwidth test
mininet> iperfudp h1 h2            # UDP test

# HTTP traffic
mininet> h1 python3 -m http.server 8000 &
mininet> h2 wget -O /dev/null http://10.0.1.1:8000/

# Check host IPs
mininet> net
```

### Option 2: Automatic Traffic Generation

```bash
# Generate mixed traffic automatically for 60 seconds
sudo python topology/custom_topo.py \
    --topology custom \
    --traffic mixed \
    --duration 60
```

Traffic types:
- `--traffic icmp`: Ping traffic
- `--traffic http`: Web traffic
- `--traffic iperf`: Bandwidth tests
- `--traffic mixed`: All types

---

## Different Network Topologies

### Custom Topology (Default)
3 switches, 9 hosts (3 hosts per switch)
```bash
sudo python topology/custom_topo.py --topology custom
```

### Linear Topology
Simple chain: h1 -- s1 -- s2 -- s3 -- h2
```bash
sudo python topology/custom_topo.py --topology linear
```

### Star Topology
6 hosts connected to 1 central switch
```bash
sudo python topology/custom_topo.py --topology star
```

---

## Training Your Own Model

If you want to train a new model with your own data:

```bash
# Activate virtual environment
source venv/bin/activate

# Train Random Forest (fast, good accuracy)
python src/ml_models/train.py \
    data/processed/labeled_data.csv \
    random_forest \
    data/models/

# Or train SVM (slower, high accuracy)
python src/ml_models/train.py \
    data/processed/labeled_data.csv \
    svm \
    data/models/svm/

# Or train Neural Network
python src/ml_models/train.py \
    data/processed/labeled_data.csv \
    neural_network \
    data/models/nn/
```

**Note:** Your CSV must have a `traffic_type` column with labels (HTTP, FTP, SSH, ICMP, VIDEO, etc.)

---

## Monitoring and Logs

### Check Captured Data
```bash
# View captured packets
ls -lh data/raw/

# View extracted features
head data/processed/features.csv
```

### View Logs
```bash
# Ryu controller logs
tail -f logs/ml_sdn.log

# Check if packets are being captured
watch -n 1 'ls -lh data/raw/'
```

---

## Troubleshooting

### Controller won't start
```bash
# Check if port 6653 is in use
sudo netstat -tulpn | grep 6653

# Kill existing process
sudo kill -9 $(lsof -t -i:6653)
```

### Mininet won't connect to controller
```bash
# Clean up old Mininet sessions
sudo mn -c

# Make sure controller is running first
ps aux | grep ryu
```

### No packets captured
1. Verify controller is running: `ps aux | grep ryu`
2. Check switches connected: Look for "Register datapath" in controller output
3. Generate traffic in Mininet: `pingall` or `iperf`
4. Check data directory: `ls data/raw/`

### "No such file or directory" errors
```bash
# Make sure you activated the virtual environment
source venv/bin/activate

# Check Python version
python --version  # Should be 3.8.x
```

---

## Complete Test Run

Run this complete test to verify everything works:

```bash
# Terminal 1
cd /home/hello/Desktop/ML_SDN
source venv/bin/activate
ryu-manager src/controller/sdn_controller.py --verbose
```

```bash
# Terminal 2
cd /home/hello/Desktop/ML_SDN
sudo python topology/custom_topo.py --topology star --traffic mixed --duration 30
# This will automatically generate traffic for 30 seconds and exit
```

```bash
# Terminal 3
cd /home/hello/Desktop/ML_SDN
source venv/bin/activate

# Wait for traffic generation to complete, then:
python src/traffic_monitor/feature_extractor.py \
    data/raw/captured_packets_*.json \
    data/processed/test_run.csv

python src/ml_models/classifier.py \
    data/models/ \
    data/processed/test_run.csv
```

---

## Stopping the System

### Stop Mininet
```bash
mininet> exit
# Or Ctrl+C if running with auto-traffic

# Clean up
sudo mn -c
```

### Stop Ryu Controller
```bash
# In controller terminal, press Ctrl+C
```

### Deactivate Virtual Environment
```bash
deactivate
```

---

## Summary of Commands

**First time setup:**
```bash
./scripts/setup_python38.sh
```

**Every time you run:**
```bash
# Terminal 1
source venv/bin/activate
ryu-manager src/controller/sdn_controller.py --verbose

# Terminal 2
sudo python topology/custom_topo.py --topology custom

# Terminal 3 (after generating traffic)
source venv/bin/activate
python src/traffic_monitor/feature_extractor.py data/raw/*.json data/processed/features.csv
python src/ml_models/classifier.py data/models/ data/processed/features.csv
```

---

## Next Steps

1. ✅ **Setup**: Run `./scripts/setup_python38.sh`
2. ✅ **Test**: Follow "Complete Test Run" above
3. 📚 **Learn**: Experiment with different topologies and traffic
4. 🎯 **Customize**: Train models with your own labeled data
5. 📊 **Analyze**: Study classification results and improve accuracy

For more details, see:
- [QUICKSTART.md](QUICKSTART.md) - Quick reference
- [README.md](README.md) - Full documentation
- [PYTHON38_SETUP.md](PYTHON38_SETUP.md) - Python setup details
