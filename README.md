# ML-based SDN Traffic Classification

A Python project for simulating Software-Defined Networking (SDN) environments and classifying network traffic using Machine Learning models. This project uses Ryu SDN Controller and Mininet to monitor traffic between nodes and applies ML algorithms to identify traffic types.

## Features

- **SDN Controller**: Ryu-based controller for network monitoring and traffic collection
- **Traffic Monitoring**: Real-time packet capture and flow statistics collection
- **Feature Extraction**: Converts raw packets into ML-ready features (packet size, protocols, timing, etc.)
- **ML Classification**: Supports multiple algorithms (Random Forest, SVM, Neural Networks)
- **Network Simulation**: Mininet topologies for testing (custom, linear, star)
- **Real-time Classification**: Classify traffic flows in real-time with confidence scores

## Project Structure

```
ML_SDN/
├── src/
│   ├── controller/
│   │   └── sdn_controller.py       # Ryu SDN controller with traffic monitoring
│   ├── traffic_monitor/
│   │   └── feature_extractor.py    # Extract features from captured packets
│   ├── ml_models/
│   │   ├── train.py                # Train ML classification models
│   │   └── classifier.py           # Real-time traffic classifier
│   └── utils/                      # Utility functions
├── topology/
│   └── custom_topo.py              # Mininet network topologies
├── config/
│   └── config.yaml                 # Configuration settings
├── data/
│   ├── raw/                        # Captured traffic data
│   ├── processed/                  # Extracted features
│   └── models/                     # Trained ML models
├── tests/                          # Unit tests
├── logs/                           # Application logs
└── requirements.txt                # Python dependencies
```

## Requirements

- Python 3.8+
- Ryu SDN Controller
- Mininet (for network simulation)
- scikit-learn, TensorFlow/Keras (for ML)
- OpenFlow-enabled switches (or Mininet virtual switches)

## Installation

### 1. Clone the Repository

```bash
cd /home/hello/Desktop/ML_SDN
```

### 2. Create Virtual Environment (Recommended)

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Install Mininet (if not already installed)

```bash
# On Ubuntu/Debian
sudo apt-get update
sudo apt-get install mininet

# Or install from source
git clone https://github.com/mininet/mininet
cd mininet
sudo ./util/install.sh -a
```

## Quick Start

### Step 1: Start the Ryu Controller

In Terminal 1:

```bash
ryu-manager src/controller/sdn_controller.py --verbose
```

The controller will:
- Listen for switch connections
- Monitor network traffic
- Collect packet data and flow statistics
- Save captured data to `data/raw/`

### Step 2: Start Mininet Network

In Terminal 2:

```bash
sudo python topology/custom_topo.py --topology custom
```

This creates a network with 3 switches and 9 hosts. Alternative topologies:
- `--topology linear`: Simple linear topology
- `--topology star`: Star topology with central switch

### Step 3: Generate Traffic

In the Mininet CLI:

```bash
mininet> pingall                    # Test connectivity
mininet> h1 ping -c 100 h2         # ICMP traffic
mininet> iperf h1 h2               # TCP bandwidth test
mininet> h1 python3 -m http.server 8000 &
mininet> h2 wget http://10.0.1.1:8000
```

Or generate traffic automatically:

```bash
sudo python topology/custom_topo.py --topology custom --traffic mixed --duration 60
```

### Step 4: Extract Features

```bash
python src/traffic_monitor/feature_extractor.py \
    data/raw/captured_packets_*.json \
    data/processed/features.csv
```

This converts raw packet data into ML features.

### Step 5: Train ML Model

Before training, you need to add labels to your feature data. Create a CSV with a `traffic_type` column:

```bash
python src/ml_models/train.py \
    data/processed/features_labeled.csv \
    random_forest \
    data/models/
```

Supported model types:
- `random_forest` (default)
- `svm`
- `neural_network`

### Step 6: Classify Traffic

```bash
python src/ml_models/classifier.py \
    data/models/ \
    data/processed/new_features.csv
```

## Usage Examples

### Example 1: Collecting Training Data

```bash
# Terminal 1: Start controller
ryu-manager src/controller/sdn_controller.py

# Terminal 2: Start network and generate HTTP traffic
sudo python topology/custom_topo.py --topology star --traffic http --duration 30

# Terminal 3: Extract features
python src/traffic_monitor/feature_extractor.py data/raw/*.json data/processed/http_features.csv
```

### Example 2: Training Multiple Models

```bash
# Train Random Forest
python src/ml_models/train.py data/processed/labeled_data.csv random_forest data/models/rf/

# Train SVM
python src/ml_models/train.py data/processed/labeled_data.csv svm data/models/svm/

# Train Neural Network
python src/ml_models/train.py data/processed/labeled_data.csv neural_network data/models/nn/
```

### Example 3: Real-time Classification

```python
from src.ml_models.classifier import RealTimeClassifier

# Initialize classifier
classifier = RealTimeClassifier('data/models/', classification_threshold=0.7)

# Classify a flow
flow_features = {
    'total_packets': 150,
    'total_bytes': 50000,
    'flow_duration': 2.5,
    # ... other features
}

result = classifier.classify_flow(flow_features)
print(f"Traffic Type: {result['predicted_class']}")
print(f"Confidence: {result['confidence']}")
```

## Traffic Types

The system can classify various types of network traffic:

- **HTTP/HTTPS**: Web traffic
- **FTP**: File transfer
- **SSH**: Secure shell connections
- **DNS**: Domain name queries
- **ICMP**: Ping and network diagnostics
- **Video Streaming**: Multimedia content
- **P2P**: Peer-to-peer file sharing
- **Other**: Unknown or mixed traffic

Note: You'll need to label your training data with appropriate traffic types.

## Extracted Features

The feature extractor generates 28+ features per flow:

**Packet-level:**
- Total packets (forward/backward)
- Packet sizes (min, max, mean, std)
- Packet size ratios

**Flow-level:**
- Flow duration
- Total bytes (forward/backward)
- Packets per second
- Bytes per second

**Timing:**
- Inter-arrival times (mean, std, min, max)

**Protocol-specific:**
- TCP flags (SYN, ACK, FIN, RST, PSH)
- TCP window size
- IP TTL and ToS values
- Port numbers

## Configuration

Create `config/config.yaml`:

```yaml
controller:
  port: 6653
  max_packets: 10000

monitoring:
  flow_stats_interval: 10
  packet_capture_dir: data/raw/

ml_models:
  model_type: random_forest
  test_size: 0.2
  cross_validation: 5

network:
  topology: custom
  num_switches: 3
  hosts_per_switch: 3
```

## Troubleshooting

### Issue: Mininet cannot connect to controller

```bash
# Check if Ryu is running
ps aux | grep ryu

# Check controller port
sudo netstat -tulpn | grep 6653

# Try specifying controller explicitly
sudo mn --controller=remote,ip=127.0.0.1,port=6653
```

### Issue: Permission denied for Mininet

```bash
# Run with sudo
sudo python topology/custom_topo.py

# Or add user to mininet group
sudo usermod -aG mininet $USER
```

### Issue: Missing features during classification

The classifier expects all training features. Ensure your feature extraction matches the training data format.

## Development

### Running Tests

```bash
pytest tests/ -v
```

### Adding New Features

1. Modify `feature_extractor.py` to extract new features
2. Update `get_feature_names()` method
3. Retrain models with new features
4. Update documentation

### Adding New Traffic Types

1. Collect traffic samples of the new type
2. Label the data
3. Add to training dataset
4. Retrain models
5. Update classification logic

## Performance Tips

1. **For large networks**: Increase `max_packets` in controller config
2. **For faster training**: Use Random Forest (faster than SVM/NN)
3. **For better accuracy**: Collect more diverse training samples
4. **For real-time use**: Set appropriate `classification_threshold`

## References

- [Ryu SDN Framework](https://ryu-sdn.org/)
- [Mininet](http://mininet.org/)
- [OpenFlow Protocol](https://opennetworking.org/software-defined-standards/specifications/)
- [Network Traffic Classification](https://www.sciencedirect.com/topics/computer-science/network-traffic-classification)

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details

## Authors

Your Name - ML-based SDN Traffic Classification Project

## Acknowledgments

- Ryu SDN Framework team
- Mininet project
- scikit-learn contributors
