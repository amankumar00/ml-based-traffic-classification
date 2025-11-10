# Topology Synchronization Summary

## Problem
ML classifier was using a different topology than FPLF testing, causing inconsistent training data.

## Solution
Created matching mesh topology for both ML classifier and FPLF testing.

---

## Topology Configuration

### FPLF Testing
**File**: `topology/fplf_topo.py`
**Topology**: MeshTopology (3 switches, 9 hosts)

### ML Classifier
**File**: `topology/ml_classifier_mesh_topo.py` ← **NEW**
**Topology**: Same mesh topology as FPLF

---

## Network Layout

```
Host Distribution:
  s1: h1, h2, h3 (10.0.0.1-3)
  s2: h4, h5, h6 (10.0.0.4-6)
  s3: h7, h8, h9 (10.0.0.7-9)

Switch Links:
  s1 ----100 Mbps (2ms)---- s2
   \                        /
    \                      /
  10 Mbps              100 Mbps
  (3ms)                (2ms)
      \                /
       \              /
        \            /
           ----s3----

Key: s1-s3 = 10 Mbps BOTTLENECK
```

---

## Traffic Flows (Updated for Cross-Switch)

### Original (6 hosts, single switch)
- VIDEO: h3→h1, h4→h2 (same switch)

### New (9 hosts, mesh)
- **VIDEO: h3→h7, h4→h8** ← **CROSS-SWITCH (s1→s3)**
- SSH: h1→h5, h2→h6
- HTTP: h3→h1, h4→h2
- FTP: h5→h3, h6→h4

---

## Changes Made

### 1. Created new topology file
**File**: `topology/ml_classifier_mesh_topo.py`
- 3 switches in triangle mesh
- 9 hosts (3 per switch)
- Exact same bandwidth/delay as FPLF

### 2. Updated ML classifier script
**File**: `scripts/automated_traffic_classification.sh`
- Lines 76-90: Import and use new mesh topology
- Lines 184-200: VIDEO servers on h7, h8 (s3 hosts)
- Lines 305-324: VIDEO clients h3→h7, h4→h8 (cross-switch)

### 3. Controller threshold adjustment
**File**: `src/controller/dynamic_fplf_controller.py`
- Line 37: Congestion threshold: 90% → **8%**
- Line 501: Same threshold in weight calculation
- **Reason**: Controller assumes 100 Mbps but s1-s3 is 10 Mbps
  - 10% measured = 100% actual on 10 Mbps link

---

## How to Use

### Run ML Classifier (generates CSV)
```bash
bash scripts/automated_traffic_classification.sh
```
This now uses **mesh topology** matching FPLF.

### Run FPLF Test (uses CSV)
```bash
sudo bash scripts/test_route_changes.sh
```
This uses the **same mesh topology**.

---

## Expected Results

With synchronized topologies:

1. **ML Classifier generates**: `data/processed/host_to_host_flows.csv`
   - Contains h3→h7, h4→h8 VIDEO flows (cross-switch s1→s3)

2. **FPLF Controller reads CSV**: Maps (h3,h7) → VIDEO priority 4

3. **During congestion**:
   - s1-s3 link: 10% utilization (10 Mbps saturated)
   - Weight becomes: **1000** (congested)
   - FPLF chooses: `s1 → s2 → s3` (weight ~997)
   - Baseline uses: `s1 → s3` (shortest)
   - **Result**: `route_changed=YES` ✓

---

## Files Modified

1. ✅ `topology/ml_classifier_mesh_topo.py` - NEW
2. ✅ `scripts/automated_traffic_classification.sh` - Updated
3. ✅ `src/controller/dynamic_fplf_controller.py` - Threshold adjusted
4. ⚠️ `data/processed/host_to_host_flows.csv` - Will be regenerated on next ML run

---

## Next Steps

1. Run ML classifier to regenerate CSV with mesh topology:
   ```bash
   bash scripts/automated_traffic_classification.sh
   ```

2. Run FPLF test to see route changes:
   ```bash
   sudo bash scripts/test_route_changes.sh
   ```

3. Expected output: CSV with `route_changed=YES` entries!
