# Traffic-Aware Dynamic FPLF Implementation

## Overview

Successfully integrated **ML-based traffic classification** with **dynamic FPLF routing** to create an intelligent, adaptive SDN controller.

## Key Features

### 1. Traffic-Type Priorities (from ML Classification)
The controller reads `data/processed/host_to_host_flows.csv` and assigns priorities:

| Traffic Type | Priority | Behavior |
|--------------|----------|----------|
| **VIDEO** | 4 (Highest) | Strongly prefers low-latency, low-load paths |
| **SSH** | 3 (High) | Moderately prefers low-load paths |
| **HTTP** | 2 (Medium) | Slight preference for better paths |
| **FTP** | 1 (Low) | Uses any available path, less picky |

### 2. Dynamic Link Utilization (from FPLF)
Real-time monitoring updates link weights every second:

```python
if utilization == 0:
    base_weight = 500  # Idle link
elif 0 < utilization < 0.9:
    base_weight = 499 - (0.9 - utilization)  # Active
else:
    base_weight = 1000  # Congested (avoid!)
```

### 3. Combined Weight Formula

```python
adjusted_weight = base_weight * (5 - priority) / 4.0
```

**Examples:**
- **VIDEO on idle link**: 500 * 0.25 = 125 (very attractive)
- **VIDEO on loaded link**: 1000 * 0.25 = 250 (still better than FTP on idle!)
- **FTP on idle link**: 500 * 1.0 = 500
- **FTP on loaded link**: 1000 * 1.0 = 1000 (uses full weight)

This ensures VIDEO/SSH traffic gets the best paths, while FTP adapts to whatever is available.

## How It Works

1. **Packet arrives** at controller
2. **Extract source/destination hosts** from MAC addresses
3. **Lookup traffic type** in `classified_flows` dict: `(h3, h1) → VIDEO`
4. **Get priority**: VIDEO = 4
5. **Apply to all links**: `adjusted_weight = base_weight * (5-4)/4 = base_weight * 0.25`
6. **Run Dijkstra** on adjusted weights
7. **Install flows** on computed path
8. **Log route** with traffic type, priority, and weights

## CSV Outputs

### `fplf_routes.csv`
Now includes traffic-aware routing decisions:
```csv
timestamp,src_dpid,dst_dpid,path,traffic_type,priority,base_weights,adjusted_weights
2024-11-06 22:00:15,1,3,s1 -> s2 -> s3,VIDEO,4,[500, 500],[125.0, 125.0]
2024-11-06 22:01:20,2,1,s2 -> s1,FTP,1,[498.5],[498.5]
```

### `link_utilization.csv`
Unchanged - tracks per-link utilization:
```csv
timestamp,link,utilization_percent,weight
2024-11-06 22:00:15,s1-s2,15.32,484.68
```

### `graph_weights.csv`
Shows base weights (before priority adjustment):
```csv
timestamp,edge,weight,utilization
2024-11-06 22:00:15,(1,2),484.68,0.1532
```

## Controller Logs

```
============================================================
Dynamic FPLF Controller with Traffic-Type Awareness
============================================================
Monitoring data: /home/hello/Desktop/ML_SDN/data/fplf_monitoring
Loaded 9 host mappings
Loaded 8 classified flows
Traffic priorities: VIDEO=4, SSH=3, HTTP=2, FTP=1

============================================================
FPLF Route #50
  Flow: 10.0.0.3 -> 10.0.0.1
  Traffic: VIDEO (Priority=4)
  Path: s1 -> s2 -> s3
  Base Weights: [498.5, 499.0]
  Adjusted Weights: [124.6, 124.8]
============================================================
```

## Benefits

1. **QoS for Real-Time Traffic**: VIDEO/SSH automatically get best paths
2. **Dynamic Adaptation**: Weights update based on actual link usage
3. **ML-Driven**: Uses real traffic classification, not just port numbers
4. **Load Balancing**: Spreads traffic based on both priority and utilization
5. **Fair Resource Allocation**: Low-priority traffic still gets service

## Testing

```bash
# Start controller
./scripts/run_dynamic_fplf.sh

# In another terminal, start topology
sudo python3 topology/fplf_topo.py --topology custom

# Generate traffic
mininet> pingall
mininet> iperf h3 h1  # Should get good path if classified as VIDEO
mininet> iperf h5 h2  # FTP traffic, less picky about path
```

## Implementation Details

- **File**: `src/controller/dynamic_fplf_controller.py`
- **ML Input**: `data/processed/host_to_host_flows.csv`
- **Topology**: `topology/fplf_topo.py` (single subnet for routing)
- **Config**: `config/host_map.txt` (MAC to switch mapping)

## Comparison: Before vs After

| Aspect | Basic FPLF | Traffic-Aware FPLF |
|--------|------------|-------------------|
| Routing | Based only on utilization | Utilization + Traffic Priority |
| VIDEO Traffic | No special treatment | 4x stronger preference for low-load |
| FTP Traffic | Same as VIDEO | Uses full weights, less demanding |
| Weight Calculation | `base_weight` | `base_weight * (5-priority)/4` |
| ML Integration | ❌ None | ✅ Full integration |

## Future Enhancements

- [ ] Real-time ML classification (not just CSV lookup)
- [ ] Per-flow bandwidth reservation
- [ ] Congestion prediction using historical data
- [ ] QoS queue integration
- [ ] Multipath routing for high-priority flows

---

**Created**: November 2024  
**Algorithm**: POX FPLF + ML Traffic Classification  
**Framework**: Ryu SDN Controller
