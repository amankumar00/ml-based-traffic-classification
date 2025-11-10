# Why Routes Aren't Changing (route_changed=NO)

## The Problem

You observed that in `fplf_routes.csv`, all entries show:
- `baseline_path` = `fplf_path` (same paths)
- `route_changed = NO` (no optimization happening)

## Root Cause: Linear Topology

Your current topology is **linear** (`s1 -- s2 -- s3`), which has **only ONE path** between any pair of switches:

```
Linear Topology:
s1 ─────── s2 ─────── s3
  (port 4)    (port 4-5)
```

**Available paths:**
- s1 → s2: Only `s1 -> s2` (1 path)
- s2 → s3: Only `s2 -> s3` (1 path)
- s1 → s3: Only `s1 -> s2 -> s3` (1 path)

**Result**: Baseline and FPLF **must** choose the same path because no alternative exists!

## Why FPLF Needs Multiple Paths

FPLF demonstrates its value when:
1. **Multiple paths exist** between source and destination
2. **Paths have different costs** (based on utilization, congestion)
3. **FPLF can choose** the better path based on traffic priority

With only one path, FPLF cannot demonstrate:
- ❌ Congestion avoidance (no alternate route)
- ❌ Load balancing (no redundant paths)
- ❌ Priority-based routing (all traffic uses same path)

## The Solution: Mesh Topology

Use a topology with **redundant paths**:

```
Mesh Topology:
     s1 ───────── s2
      \          /
       \        /
        \      /
         \    /
          \  /
           s3
```

**Available paths:**
- s1 → s3: **TWO paths**
  - Direct: `s1 -> s3` (1 hop, delay=3ms)
  - Via s2: `s1 -> s2 -> s3` (2 hops, delay=4ms)

**FPLF Decision Making:**

| Scenario | Baseline Choice | FPLF Choice | Route Changed? |
|----------|----------------|-------------|----------------|
| All links idle | `s1 -> s3` (shortest) | `s1 -> s3` (lowest weight=500) | ❌ NO |
| s1-s3 link congested (90% util) | `s1 -> s3` (shortest) | `s1 -> s2 -> s3` (avoid weight=1000) | ✅ YES |
| VIDEO traffic, s2 at 50% | `s1 -> s3` (shortest) | `s1 -> s2 -> s3` (priority factor makes it better) | ✅ YES |
| FTP traffic, balanced load | `s1 -> s3` (shortest) | `s1 -> s3` (low priority, same path) | ❌ NO |

## How to See Route Changes

### Quick Test (Recommended)

```bash
cd /home/hello/Desktop/ML_SDN
sudo ./scripts/test_fplf_mesh.sh
```

This will:
1. Start controller
2. Create mesh topology with 3 alternate paths
3. Generate mixed traffic (VIDEO, SSH, HTTP, FTP)
4. Run for 60 seconds

**Check results:**
```bash
# Show all route changes
grep "YES" data/fplf_monitoring/fplf_routes.csv

# Example output you should see:
# 2025-11-06 14:30:15,1,3,s1 -> s2 -> s3,s1 -> s3,VIDEO,4,[500,498],[125,124],YES
```

### Manual Test

```bash
# Terminal 1: Controller
cd /home/hello/Desktop/ML_SDN
ryu-manager --verbose --observe-links src/controller/dynamic_fplf_controller.py

# Terminal 2: Mesh topology
sudo python3 topology/fplf_topo.py --topology mesh

# Terminal 2: In Mininet CLI, generate traffic
mininet> h1 ping h7 -c 100 &
mininet> h4 ping h7 -c 100 &
mininet> iperf h1 h7
```

Watch controller logs for:
```
======================================================================
FPLF Route Comparison #50
  Flow: 10.0.0.1 -> 10.0.0.7
  Traffic: VIDEO (Priority=4)
  Baseline Path (no FPLF): s1 -> s2 -> s3
  FPLF Path (optimized):   s1 -> s3
  ⚡ ROUTE CHANGED! FPLF chose different path
  Base Weights: [500]
  Adjusted Weights: [125]
======================================================================
```

## When You'll See route_changed=YES

### 1. Congestion Avoidance
When a link is heavily loaded (≥90% utilization), FPLF routes around it:
```csv
...,s1 -> s3,s1 -> s2 -> s3,VIDEO,4,[1000],[250],YES
```
Baseline uses direct path (congested), FPLF uses alternate route.

### 2. Priority Routing
High-priority traffic (VIDEO=4, SSH=3) gets preferential paths:
```csv
...,s1 -> s2 -> s3,s1 -> s3,VIDEO,4,[500],[125],YES
```
Direct path is better for VIDEO (adjusted weight=125 < 250).

### 3. Load Balancing
FPLF distributes flows across multiple equal paths:
```csv
# First flow uses s1 -> s3 (idle)
...,s1 -> s3,s1 -> s3,HTTP,2,[500],[375],NO

# Second flow uses alternate path (load balancing)
...,s1 -> s3,s1 -> s2 -> s3,HTTP,2,[499,499],[374,374],YES
```

## Topology Comparison

| Topology | Paths s1→s3 | Route Changes? | Use Case |
|----------|-------------|----------------|----------|
| Linear (`custom`) | 1 path | ❌ Never | Basic testing, connectivity |
| Mesh (`mesh`) | 2+ paths | ✅ Yes | FPLF demo, load balancing |
| Star (`star`) | 1 path (via center) | ❌ Never | Simple hub-spoke |
| Full Mesh (4+ switches) | Many paths | ✅ Yes, frequent | Complex optimization |

## Summary

**Your current setup (linear):**
- ✅ FPLF is working correctly
- ✅ Dynamic weights are calculated
- ✅ Priority adjustment is applied
- ❌ But route_changed=NO because only 1 path exists

**To see FPLF in action:**
1. Use mesh topology: `sudo ./scripts/test_fplf_mesh.sh`
2. Generate mixed traffic (VIDEO, SSH, FTP)
3. Look for `route_changed=YES` in CSV
4. Compare baseline vs FPLF paths

The mesh topology will demonstrate FPLF's real value: **intelligent path selection based on load and priority**.
