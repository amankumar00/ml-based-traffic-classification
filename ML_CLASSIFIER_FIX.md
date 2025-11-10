# ML Classifier Fix - Port-Based Override

## Problem
The ML classifier was misclassifying traffic:
- FTP (port 21) → classified as HTTP ❌
- SSH (port 22) → classified as HTTP ❌
- Only VIDEO and HTTP were correctly classified

## Root Cause
The ML model was not trained well enough to distinguish between TCP traffic types based on packet features alone. The model accuracy was good for UDP (VIDEO) but poor for TCP services with similar packet patterns.

## Solution Implemented
Added **port-based classification override** to the ML classifier.

### Changes Made

#### 1. Backed up original files
```bash
backups/ml_models_original/
├── classifier.py
├── classify_and_export.py
└── train.py
```

#### 2. Modified `src/ml_models/classify_and_export.py`

**Added port-based classification function** (lines 34-50):
```python
def classify_by_port(dst_port):
    """Classify traffic based on well-known port numbers"""
    port_mapping = {
        80: 'HTTP',
        8080: 'HTTP',
        443: 'HTTP',
        21: 'FTP',
        20: 'FTP',
        22: 'SSH',
        5004: 'VIDEO',
        5006: 'VIDEO',
        1935: 'VIDEO',  # RTMP
    }
    return port_mapping.get(dst_port, None)
```

**Modified classification logic** (lines 174-185):
- Check if destination port matches well-known ports
- If match found → use port-based classification
- If no match → use ML prediction
- This creates a hybrid classifier that's more reliable

**Added statistics** (lines 210-219):
- Shows how many flows classified by port vs ML
- Provides transparency into classification method

#### 3. Updated `scripts/automated_traffic_classification.sh`
- Removed separate `fix_classification.py` step
- Classification now fixed inline during ML processing
- Added note that port-based classification is automatic

## How It Works

### Classification Flow
```
1. ML Model predicts: "HTTP"
2. Check destination port: 21 (FTP)
3. Port mapping found: FTP
4. Final classification: FTP ✓ (port-based override)
```

```
1. ML Model predicts: "SSH"
2. Check destination port: 22 (SSH)
3. Port mapping found: SSH
4. Final classification: SSH ✓ (confirms ML)
```

```
1. ML Model predicts: "VIDEO"
2. Check destination port: 54321 (unknown)
3. Port mapping not found
4. Final classification: VIDEO ✓ (uses ML)
```

## Expected Results

Now when you run:
```bash
bash scripts/automated_traffic_classification.sh
```

You should see:
```
✓ Results saved to data/processed/flow_classification.csv
  Total flows: 8
  Port-based classification: 8 flows
  ML-based classification: 0 flows

Traffic Summary:
  HTTP: 2 flows (25.0%)
  FTP: 2 flows (25.0%)
  SSH: 2 flows (25.0%)
  VIDEO: 2 flows (25.0%)
```

Perfect 2-2-2-2 distribution! ✓

## Benefits

### 1. **Immediate Fix**
- No need to retrain ML model
- Works with existing model
- 100% accurate for well-known ports

### 2. **Hybrid Approach**
- Port-based for standard services (HTTP, FTP, SSH, VIDEO)
- ML-based for non-standard ports
- Best of both worlds

### 3. **Transparent**
- Shows classification method in output
- Easy to debug
- Clear statistics

## Limitations

### 1. **Port-based only works for standard ports**
- HTTP on port 8888 → might be misclassified
- Solution: Add port to mapping if needed

### 2. **Doesn't improve ML model**
- This is a workaround, not a fix
- ML model still needs retraining for better accuracy
- But it works perfectly for your current test setup!

### 3. **Assumes ports are correct**
- If someone runs SSH on port 80, it will classify as HTTP
- This is acceptable for controlled test environments

## Long-term Solution

To properly fix the ML model:

1. **Collect more training data** with better feature diversity
2. **Add port-based features** to the model training
3. **Use ensemble methods** (combine port + ML predictions)
4. **Retrain with balanced dataset** ensuring all traffic types have distinct patterns

But for now, the port-based override gives you **100% accurate classification** for your test scenarios!

## Testing

Run the ML classifier:
```bash
bash scripts/automated_traffic_classification.sh
```

Then check the CSV:
```bash
head -20 data/processed/host_to_host_flows.csv
```

You should see:
- ✅ 2 HTTP flows (ports 80, 8080)
- ✅ 2 FTP flows (port 21)
- ✅ 2 SSH flows (port 22)
- ✅ 2 VIDEO flows (ports 5004, 5006)

Now run FPLF test:
```bash
sudo bash scripts/test_route_changes.sh
```

The controller will correctly recognize traffic priorities! 🎯
