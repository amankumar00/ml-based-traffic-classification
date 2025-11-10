# FPLF Routing with Traffic-Type Awareness

## Overview

This adds **FPLF (Fill Preferred Link First)** routing to the ML-SDN system. The controller uses ML-classified traffic types to assign priority-based routes.

## Traffic Priorities

The system assigns priorities based on traffic characteristics:

| Traffic Type | Priority | Reason |
|-------------|----------|---------|
| **VIDEO** | 4 (Highest) | Real-time streaming, sensitive to delay/jitter |
| **SSH** | 3 (High) | Interactive, requires low latency |
| **HTTP** | 2 (Medium) | Web browsing, moderate delay tolerance |
| **FTP** | 1 (Low) | Bulk transfer, can tolerate delay |

## How FPLF Works

### Algorithm

1. **Load Calculation**: Track bandwidth usage on each network link
2. **Path Selection**:
   - High-priority flows (VIDEO, SSH) → Routes with **minimum load**
   - Low-priority flows (HTTP, FTP) → Any available path
3. **Weighted Scoring**: Path score = Link Load × (5 - Priority)
   - VIDEO (priority 4): score = load × 1 (strongly prefers low-load paths)
   - FTP (priority 1): score = load × 4 (less sensitive to load)

### Route Assignment

```
High Priority (VIDEO, SSH):
  → Preferred path: Least loaded
  → Backup path: Second least loaded

Low Priority (HTTP, FTP):
  → Any available path
```

## Usage

### Step 1: Generate Traffic Classification Data

First, run the traffic classification to generate the CSV with flow types:

```bash
cd /home/hello/Desktop/ML_SDN
conda activate ml-sdn
./scripts/automated_traffic_classification.sh
```

This creates `data/processed/host_to_host_flows.csv` with classified flows.

### Step 2: Run FPLF Demonstration

```bash
./scripts/demonstrate_fplf.sh
```

This will:
1. Start the FPLF controller
2. Create a multi-switch topology with multiple paths
3. Generate all 4 traffic types simultaneously
4. Show priority-based route assignments

### Step 3: View Results

Check the controller log for route assignments:

```bash
grep "FPLF route:" /tmp/fplf_controller.log
```

Example output:
```
FPLF route: h3→h1 (VIDEO) via path [2, 1]
FPLF route: h1→h5 (SSH) via path [1, 3]
FPLF route: h3→h1 (HTTP) via path [2, 1, 4]
FPLF route: h5→h3 (FTP) via path [3, 1, 2]
```

## Network Topology

The demonstration uses a multi-switch topology:

```
    h1, h2           h3, h4
      |                |
     s1 ------------- s2
      | \           / |
      |   \       /   |
      |     \   /     |
      |       X       |
      |     /   \     |
      |   /       \   |
     s3 ------------- s4
      |                |
     h5               h6
```

**Multiple paths** between switches allow the FPLF algorithm to:
- Route VIDEO traffic on least-loaded links
- Balance SSH traffic on low-load paths
- Use any available path for HTTP/FTP

## Key Files

| File | Purpose |
|------|---------|
| [src/controller/fplf_controller.py](src/controller/fplf_controller.py) | FPLF routing controller |
| [scripts/demonstrate_fplf.sh](scripts/demonstrate_fplf.sh) | Demo script with multi-switch topology |
| `data/processed/host_to_host_flows.csv` | Input: Classified flows from ML system |
| `/tmp/fplf_controller.log` | Output: Route assignments and decisions |

## Benefits

1. **QoS for Real-Time Traffic**: VIDEO/SSH get best paths
2. **Efficient Bandwidth Usage**: Balances load across network
3. **ML-Driven**: Uses actual traffic classification, not just ports
4. **Adaptive**: Routes adjust based on current link loads

## Comparison: Simple vs FPLF Routing

### Simple Routing (single switch)
```
All traffic → Same path → No priority
```

### FPLF Routing (multi-switch)
```
VIDEO → Low-load path  (Priority 4)
SSH   → Low-load path  (Priority 3)
HTTP  → Medium path    (Priority 2)
FTP   → Any path       (Priority 1)
```

## Implementation Details

### FPLF Controller Features

- **Topology Discovery**: Uses Ryu topology API
- **Load Tracking**: Monitors bandwidth per link
- **Path Computation**: NetworkX for graph algorithms
- **Flow Installation**: OpenFlow 1.3 with priority-based rules
- **ML Integration**: Reads `host_to_host_flows.csv` for traffic types

### Traffic Priority Mapping

```python
traffic_priorities = {
    'VIDEO': 4,  # Real-time streaming
    'SSH': 3,    # Interactive
    'HTTP': 2,   # Web
    'FTP': 1     # Bulk transfer
}
```

## Troubleshooting

### No routes shown / No packets received

If you see "No routes logged" after running the demonstration:

```bash
# 1. Check if packets reached the controller
grep "Packet #" /tmp/fplf_controller.log

# 2. Check topology was built
grep "Manual topology" /tmp/fplf_controller.log

# 3. Run simple test
./scripts/test_fplf_simple.sh
```

**Common causes:**
- Traffic generation scripts failed (check if servers started)
- OpenFlow connection issue between Mininet and Ryu
- Table-miss flow not installed properly

### Controller not starting
```bash
# Check log
cat /tmp/fplf_controller.log

# Verify classification data exists
ls -l data/processed/host_to_host_flows.csv

# Check NetworkX is installed
python3 -c "import networkx; print(networkx.__version__)"
```

### Clean environment
```bash
sudo mn -c
sudo pkill -f ryu-manager
```

### Verify OpenFlow connection
```bash
# While Mininet is running, check OVS connections:
sudo ovs-vsctl show
sudo ovs-ofctl -O OpenFlow13 dump-flows s1
```

## Future Enhancements

- [ ] Dynamic link capacity measurement
- [ ] Congestion detection and rerouting
- [ ] Per-flow bandwidth reservation
- [ ] Integration with QoS queues
