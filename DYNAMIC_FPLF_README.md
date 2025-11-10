# Dynamic FPLF (Flow Path Load Feedback) Implementation

## Overview

This implementation provides a **Dynamic FPLF routing controller** for Software-Defined Networks (SDN) using the Ryu controller framework. The FPLF algorithm uses Dijkstra's shortest path with dynamic weight adjustments based on real-time link utilization monitoring.

**Key Features:**
- Real-time port statistics monitoring
- Dynamic link weight updates based on utilization
- Dijkstra-based path computation with adaptive routing
- CSV export of link utilization and routing decisions
- Compatible with custom Mininet topologies

## Architecture

```
┌─────────────────────────────────────────────────────┐
│         Dynamic FPLF Controller (Ryu)              │
│                                                     │
│  ┌──────────────┐      ┌──────────────────────┐   │
│  │  Topology    │      │  Port Stats Monitor  │   │
│  │  Discovery   │◄────►│  (1 second polling)  │   │
│  └──────────────┘      └──────────────────────┘   │
│         │                        │                 │
│         ▼                        ▼                 │
│  ┌──────────────────────────────────────────┐     │
│  │    Graph with Dynamic Weights            │     │
│  │    (NetworkX + Dijkstra)                 │     │
│  └──────────────────────────────────────────┘     │
│         │                                          │
│         ▼                                          │
│  ┌──────────────────────────────────────────┐     │
│  │    Flow Installation & Path Setup         │     │
│  └──────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────┘
                    │
                    ▼
         ┌─────────────────────┐
         │   Mininet Network   │
         │   (Custom Topology) │
         └─────────────────────┘
```

## FPLF Algorithm

### Weight Formula

The FPLF algorithm dynamically adjusts link weights based on utilization:

```python
if utilization == 0:
    weight = 500            # Idle link (initial state)
elif 0 < utilization < 0.9:
    weight = 499 - (0.9 - utilization)  # Active link
else:  # utilization >= 0.9
    weight = 1000           # Congested link (avoid)
```

### How It Works

1. **Port Statistics Collection**: Controller polls switches every 1 second for port statistics (tx_bytes, rx_bytes)

2. **Utilization Calculation**:
   ```
   bytes_diff = current_bytes - last_bytes
   utilization_mbps = (bytes_diff * 8) / (1024 * 1024)
   utilization_percent = utilization_mbps / link_capacity
   ```

3. **Weight Update**: Graph edge weights are updated based on the formula above

4. **Path Computation**: When a new flow arrives, Dijkstra's algorithm finds the lowest-weight path

5. **Flow Installation**: OpenFlow rules are installed along the computed path (bidirectional)

### Benefits

- **Load Balancing**: Automatically routes new flows away from congested links
- **Adaptive**: Responds to changing network conditions in real-time
- **Fair**: Lower-utilized links get lower weights, distributing traffic evenly
- **Simple**: Uses standard Dijkstra's algorithm with dynamic weights

## File Structure

```
ML_SDN/
├── src/
│   └── controller/
│       ├── dynamic_fplf_controller.py   # Main FPLF controller
│       ├── fplf_controller.py           # Static FPLF (priority-based)
│       ├── simple_fplf.py               # POX example (reference)
│       └── sdn_controller.py            # Basic SDN controller
├── config/
│   └── host_map.txt                     # Host-to-switch mapping
├── topology/
│   └── custom_topo.py                   # Mininet topology definitions
├── scripts/
│   ├── run_dynamic_fplf.sh             # Run controller only
│   └── demo_fplf_with_traffic.sh       # Full demo (controller + topology)
└── data/
    └── fplf_monitoring/                 # Output directory
        ├── link_utilization.csv         # Link usage over time
        ├── fplf_routes.csv              # Routing decisions
        ├── graph_weights.csv            # Graph edge weights
        └── controller.log               # Controller logs
```

## Installation

### Prerequisites

```bash
# Install Python dependencies
pip install ryu networkx

# Install Mininet (if not already installed)
sudo apt-get install mininet

# Or install from source:
git clone https://github.com/mininet/mininet
cd mininet
sudo ./util/install.sh -a
```

### Verify Installation

```bash
# Check Ryu
ryu-manager --version

# Check Mininet
sudo mn --version

# Check Python packages
python3 -c "import ryu; import networkx; print('OK')"
```

## Usage

### Method 1: Controller Only

Start just the FPLF controller (you'll need to start topology separately):

```bash
cd /home/hello/Desktop/ML_SDN
./scripts/run_dynamic_fplf.sh
```

Then in another terminal, start Mininet:

```bash
sudo python3 topology/custom_topo.py --topology custom
```

### Method 2: Complete Demo (Recommended)

Run both controller and topology with automated traffic generation:

```bash
cd /home/hello/Desktop/ML_SDN
sudo ./scripts/demo_fplf_with_traffic.sh
```

This will:
1. Start the Dynamic FPLF controller
2. Launch Mininet with custom topology (3 switches, 9 hosts)
3. Generate mixed traffic (ICMP, HTTP, FTP, SSH, iPerf) for 120 seconds
4. Save monitoring data to `data/fplf_monitoring/`

### Method 3: Mesh Topology Test (See Route Changes!)

**Use this to see `route_changed=YES` in CSV:**

```bash
cd /home/hello/Desktop/ML_SDN
sudo ./scripts/test_fplf_mesh.sh
```

This will:
1. Start controller
2. Create **mesh topology** with 3 alternate paths
3. Generate mixed traffic
4. Show route changes in CSV

After 60 seconds, check:
```bash
grep "YES" data/fplf_monitoring/fplf_routes.csv
```

### Method 4: Interactive Mode

For manual testing:

```bash
# Terminal 1: Start controller
cd /home/hello/Desktop/ML_SDN
ryu-manager --verbose --observe-links src/controller/dynamic_fplf_controller.py

# Terminal 2: Start mesh topology (multiple paths)
sudo python3 topology/fplf_topo.py --topology mesh

# Or linear topology (single path)
sudo python3 topology/fplf_topo.py --topology custom

# In Mininet CLI, test connectivity:
mininet> pingall
mininet> h1 ping h4
mininet> iperf h1 h9
```

## Configuration

### Host Mapping (`config/host_map.txt`)

Maps each host's MAC address to its switch and port:

```
# Format: MAC_ADDRESS SWITCH_DPID PORT_NUMBER
00:00:00:00:00:01 1 1   # h1 on s1 port 1
00:00:00:00:00:02 1 2   # h2 on s1 port 2
00:00:00:00:00:03 1 3   # h3 on s1 port 3
00:00:00:00:00:04 2 1   # h4 on s2 port 1
...
```

### Topology Options

The system supports multiple topologies to demonstrate different FPLF behaviors:

#### 1. Linear Topology (`--topology custom`, default)

```
     h1 h2 h3           h4 h5 h6           h7 h8 h9
        |  |  |             |  |  |             |  |  |
     [  s1  ] ─────── [  s2  ] ─────── [  s3  ]
```

**Use case**: Basic routing, single path between switches
**Route changes**: ❌ NO - Only one path exists, baseline = FPLF
**Best for**: Testing basic connectivity, understanding FPLF weights

#### 2. Mesh Topology (`--topology mesh`, **recommended for demo**)

```
         h1 h2 h3
            |  |  |
     h4 h5 h6 ─ s1 ────── s2 ─ h7 h8 h9
                 \        /
                  \      /
                   \    /
                    \  /
                     s3
```

**Use case**: Multiple paths, load balancing, congestion avoidance
**Route changes**: ✅ YES - FPLF can choose alternate paths!
**Example paths**:
- s1 → s3: Direct (`s1 -> s3`) OR via s2 (`s1 -> s2 -> s3`)
- If s2 is congested, VIDEO traffic uses direct path

**Best for**: Demonstrating FPLF optimization and route changes

## Monitoring & Analysis

### CSV Output Files

#### `link_utilization.csv`
Tracks link usage over time:
```csv
timestamp,link,utilization_percent,weight
2024-11-06 10:15:23,s1-s2,15.32,484.68
2024-11-06 10:15:24,s1-s2,23.45,476.55
2024-11-06 10:15:25,s2-s3,8.12,491.88
```

#### `fplf_routes.csv`
Records routing decisions with baseline comparison:
```csv
timestamp,src_dpid,dst_dpid,baseline_path,fplf_path,traffic_type,priority,base_weights,adjusted_weights,route_changed
2024-11-06 10:15:23,1,3,s1 -> s2 -> s3,s1 -> s3,VIDEO,4,[500, 498.5],[125.0, 124.6],YES
2024-11-06 10:15:24,2,1,s2 -> s1,s2 -> s1,FTP,1,[498.1],[498.1],NO
```

**Columns:**
- `baseline_path`: Traditional shortest path (hop count, no FPLF)
- `fplf_path`: FPLF-optimized path (with dynamic weights & priority)
- `route_changed`: YES if FPLF chose a different path than baseline
- `base_weights`: Link weights based on utilization
- `adjusted_weights`: Weights after priority adjustment

#### `graph_weights.csv`
Snapshot of graph edge weights:
```csv
timestamp,edge,weight,utilization
2024-11-06 10:15:23,s1-s2,484.68,0.1532
2024-11-06 10:15:23,s2-s3,491.88,0.0812
```

### Analyzing Results

You can use Python/Pandas to analyze the CSV files:

```python
import pandas as pd
import matplotlib.pyplot as plt

# Load utilization data
df = pd.read_csv('data/fplf_monitoring/link_utilization.csv')

# Plot link utilization over time
for link in df['link'].unique():
    link_data = df[df['link'] == link]
    plt.plot(link_data['timestamp'], link_data['utilization_percent'], label=link)

plt.xlabel('Time')
plt.ylabel('Utilization (%)')
plt.legend()
plt.title('FPLF Link Utilization Over Time')
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig('link_utilization.png')
```

## Comparison with Other Controllers

| Feature | Dynamic FPLF | Static FPLF | Basic SDN |
|---------|--------------|-------------|-----------|
| Path computation | Dijkstra with dynamic weights | Dijkstra with priority weights | Shortest path |
| Adapts to load | ✅ Yes (real-time) | ❌ No | ❌ No |
| Traffic priority | ❌ No | ✅ Yes | ❌ No |
| Monitoring | Port stats every 1s | Periodic flow stats | Basic |
| Load balancing | Automatic | Manual (via priority) | None |

## Important Notes

### Static ARP Environment

The `fplf_topo.py` topology uses `autoStaticArp=True`, which means Mininet pre-populates ARP tables and hosts don't send ARP packets. This improves performance but creates a challenge: **the controller can't learn MAC locations from packet traffic**.

**Solution**: The controller pre-populates MAC learning tables from `config/host_map.txt` at startup. This file maps each host's MAC address to its switch and port:

```
00:00:00:00:00:01 1 1   # h1 on s1 port 1
00:00:00:00:00:05 2 2   # h5 on s2 port 2
...
```

This ensures inter-switch routing works immediately without requiring ARP traffic. The host_map is automatically generated if it doesn't exist.

### Route Comparison: Baseline vs FPLF

The controller logs **two paths** for each flow to demonstrate FPLF's benefits:

**Baseline Path**: Traditional shortest-path routing (hop count only)
- Algorithm: `nx.shortest_path()` with uniform weights
- Represents what traditional routers would choose
- Ignores link utilization and traffic priority

**FPLF Path**: Optimized routing with dynamic weights and traffic priority
- Algorithm: Dijkstra with `adjusted_weight = base_weight × priority_factor`
- Considers real-time link utilization (monitored every 1 second)
- Prioritizes critical traffic (VIDEO, SSH) on low-load paths

**When FPLF Chooses Different Routes** (`route_changed=YES`):

1. **Link Congestion**: If baseline path has congested links (utilization ≥ 90%), FPLF routes around them
   ```
   Baseline: s1 -> s2 -> s3 (s2 congested, weight=1000)
   FPLF:     s1 -> s4 -> s3 (alternate path, weight=498)
   ```

2. **High-Priority Traffic**: VIDEO/SSH gets preferential routing on lightly-loaded links
   ```
   VIDEO (priority=4): Chooses path with weight 498 over path with weight 500
   FTP (priority=1):   Would take either path (less sensitive)
   ```

3. **Load Balancing**: Distributes flows across multiple paths based on current load
   ```
   First flow:  Uses s1 -> s2 (weight=500)
   Second flow: Uses s1 -> s3 (weight=500) - balances load
   Third flow:  Uses s1 -> s2 (weight=499.1) - still lower after traffic
   ```

**Example CSV Output**:
```csv
# Congestion avoidance
...,s1 -> s2 -> s3,s1 -> s4 -> s3,VIDEO,4,[1000,498],[250,124],YES

# Priority routing
...,s2 -> s1,s2 -> s3 -> s1,SSH,3,[500,498],[250,249],YES

# Optimal path confirmed
...,s2 -> s1,s2 -> s1,FTP,1,[498],[498],NO
```

## Troubleshooting

### Issue: Controller won't start

```bash
# Check if port 6653 is already in use
sudo netstat -tulpn | grep 6653

# Kill existing Ryu instances
pkill -f ryu-manager
```

### Issue: Topology not discovered

```bash
# Enable LLDP on switches
sudo ovs-vsctl set bridge s1 other-config:forward-bpdu=true

# Check if links are up
sudo ovs-ofctl show s1
```

### Issue: No traffic flows

```bash
# Check flow tables
sudo ovs-ofctl dump-flows s1

# Check connectivity
mininet> pingall

# Check controller connection
sudo ovs-vsctl show
```

### Issue: Inter-switch traffic fails (h5 can't ping h1)

**Symptoms**: Same-switch traffic works (h1 ping h2), but cross-switch fails (h5 ping h1)

**Cause**: MAC learning tables not populated (especially with `autoStaticArp=True`)

**Solution**:
1. Check `config/host_map.txt` exists and has all host mappings
2. Check controller logs for "Pre-populated MAC tables with X entries"
3. If manual topology triggered, verify it re-populated MAC tables

```bash
# Check controller logs
grep "Pre-populated MAC" data/fplf_monitoring/controller.log

# Verify host_map.txt
cat config/host_map.txt

# Should see all 9 hosts (h1-h9) mapped to switches
```

### Issue: High CPU usage

```bash
# Reduce monitoring frequency (edit controller)
# Change: hub.sleep(1)  →  hub.sleep(5)

# Or reduce logging verbosity
ryu-manager src/controller/dynamic_fplf_controller.py  # Remove --verbose
```

## Performance Tuning

### Monitoring Interval

Edit [src/controller/dynamic_fplf_controller.py](src/controller/dynamic_fplf_controller.py):

```python
def _monitor(self):
    while True:
        # ...
        hub.sleep(1)  # Change to 5 for less frequent updates
```

### Link Capacity

Adjust capacity assumptions in `port_stats_reply_handler`:

```python
link_capacity = 100  # Change based on your network (Mbps)
```

### Utilization Threshold

Modify the weight formula:

```python
# Current: threshold at 0.9 (90%)
elif 0 < uti < 0.9:
    weight = 499 - (0.9 - uti)

# Change to 0.7 (70%) for earlier congestion detection:
elif 0 < uti < 0.7:
    weight = 499 - (0.7 - uti)
```

## References

### Original FPLF Algorithm
- Based on POX controller implementation (see [src/controller/simple_fplf.py](src/controller/simple_fplf.py))
- Adapted for Ryu framework with improvements

### Related Papers
1. "Dijkstra's Algorithm for SDN Routing" - Classical shortest path
2. "Load-Aware Routing in Software-Defined Networks" - Dynamic weight adjustment
3. "Flow Path Load Feedback for Traffic Engineering" - FPLF concept

### Documentation
- [Ryu Controller Documentation](https://ryu.readthedocs.io/)
- [OpenFlow 1.3 Specification](https://www.opennetworking.org/software-defined-standards/specifications/)
- [NetworkX Documentation](https://networkx.org/documentation/stable/)

## Contributing

This is part of the ML_SDN project. To add features:

1. Test changes with the demo script
2. Ensure backward compatibility with `custom_topo.py`
3. Update CSV output format documentation
4. Add monitoring for new metrics

## License

Part of the ML_SDN project. See main project license.

## Contact

For issues specific to FPLF implementation, check:
- Controller logs: `data/fplf_monitoring/controller.log`
- Mininet logs: Run with `--verbose` flag
- OpenFlow messages: `sudo ovs-ofctl snoop s1`

---

**Created**: November 2024
**Version**: 1.0
**Framework**: Ryu SDN Controller with Mininet
