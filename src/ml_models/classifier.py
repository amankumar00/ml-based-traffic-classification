"""
Real-time Traffic Classifier
Loads trained ML models and classifies network traffic in real-time
"""

import os
import json
import pickle
import numpy as np
import pandas as pd
from datetime import datetime


class TrafficClassifier:
    """
    Real-time traffic classifier using trained ML models
    """

    def __init__(self, model_dir):
        """
        Initialize classifier with trained model

        Args:
            model_dir: Directory containing trained model files
        """
        self.model_dir = model_dir
        self.model = None
        self.scaler = None
        self.label_encoder = None
        self.metadata = None

        self._load_model()

    def _load_model(self):
        """Load trained model and preprocessing objects"""
        # Load metadata
        metadata_path = os.path.join(self.model_dir, 'model_metadata.json')
        with open(metadata_path, 'r') as f:
            self.metadata = json.load(f)

        model_type = self.metadata['model_type']
        print(f"Loading {model_type} model from {self.model_dir}")

        # Load model
        model_path = os.path.join(self.model_dir, f'{model_type}_model.pkl')
        with open(model_path, 'rb') as f:
            self.model = pickle.load(f)

        # Load scaler
        scaler_path = os.path.join(self.model_dir, 'scaler.pkl')
        with open(scaler_path, 'rb') as f:
            self.scaler = pickle.load(f)

        # Load label encoder
        encoder_path = os.path.join(self.model_dir, 'label_encoder.pkl')
        with open(encoder_path, 'rb') as f:
            self.label_encoder = pickle.load(f)

        print(f"Model loaded successfully")
        print(f"Classes: {self.metadata['class_names']}")

    def classify(self, features):
        """
        Classify traffic based on extracted features

        Args:
            features: Dictionary or DataFrame with extracted features

        Returns:
            Dictionary with prediction results
        """
        # Convert to DataFrame if needed
        if isinstance(features, dict):
            features = pd.DataFrame([features])

        # Ensure features are in correct order
        feature_names = self.metadata['feature_names']
        missing_features = set(feature_names) - set(features.columns)
        if missing_features:
            print(f"Warning: Missing features: {missing_features}")
            for feat in missing_features:
                features[feat] = 0

        features = features[feature_names]

        # Scale features
        features_scaled = self.scaler.transform(features)

        # Predict
        prediction = self.model.predict(features_scaled)
        prediction_proba = None

        if hasattr(self.model, 'predict_proba'):
            prediction_proba = self.model.predict_proba(features_scaled)

        # Decode prediction
        predicted_class = self.label_encoder.inverse_transform(prediction)[0]

        result = {
            'predicted_class': predicted_class,
            'prediction_index': int(prediction[0]),
            'timestamp': datetime.now().isoformat()
        }

        if prediction_proba is not None:
            result['confidence'] = float(np.max(prediction_proba[0]))
            result['class_probabilities'] = {
                class_name: float(prob)
                for class_name, prob in zip(self.metadata['class_names'],
                                           prediction_proba[0])
            }

        return result

    def classify_batch(self, features_df):
        """
        Classify multiple traffic flows at once

        Args:
            features_df: DataFrame with extracted features

        Returns:
            List of prediction results
        """
        results = []

        for idx, row in features_df.iterrows():
            result = self.classify(row.to_dict())
            result['flow_index'] = idx
            results.append(result)

        return results

    def get_model_info(self):
        """Get information about loaded model"""
        return {
            'model_type': self.metadata['model_type'],
            'classes': self.metadata['class_names'],
            'features': self.metadata['feature_names'],
            'num_features': len(self.metadata['feature_names'])
        }


class RealTimeClassifier:
    """
    Real-time classifier that can be integrated with Ryu controller
    """

    def __init__(self, model_dir, classification_threshold=0.7):
        """
        Initialize real-time classifier

        Args:
            model_dir: Directory containing trained model
            classification_threshold: Minimum confidence for classification
        """
        self.classifier = TrafficClassifier(model_dir)
        self.classification_threshold = classification_threshold
        self.classification_history = []

    def classify_flow(self, flow_features):
        """
        Classify a network flow

        Args:
            flow_features: Dictionary with flow features

        Returns:
            Classification result or None if below threshold
        """
        result = self.classifier.classify(flow_features)

        # Check confidence threshold
        if 'confidence' in result:
            if result['confidence'] < self.classification_threshold:
                result['status'] = 'low_confidence'
                result['action'] = 'monitor'
            else:
                result['status'] = 'classified'
                result['action'] = 'apply_policy'
        else:
            result['status'] = 'classified'
            result['action'] = 'apply_policy'

        # Store in history
        self.classification_history.append(result)

        return result

    def get_statistics(self):
        """Get classification statistics"""
        if not self.classification_history:
            return {}

        total = len(self.classification_history)
        class_counts = {}

        for entry in self.classification_history:
            pred_class = entry['predicted_class']
            class_counts[pred_class] = class_counts.get(pred_class, 0) + 1

        avg_confidence = np.mean([
            entry.get('confidence', 1.0)
            for entry in self.classification_history
        ])

        return {
            'total_classifications': total,
            'class_distribution': class_counts,
            'average_confidence': avg_confidence
        }

    def save_history(self, output_path):
        """Save classification history to file"""
        with open(output_path, 'w') as f:
            json.dump(self.classification_history, f, indent=2)
        print(f"Classification history saved to {output_path}")


def main():
    """Example usage"""
    import sys

    if len(sys.argv) < 3:
        print("Usage: python classifier.py <model_dir> <features.csv>")
        sys.exit(1)

    model_dir = sys.argv[1]
    features_file = sys.argv[2]

    # Load classifier
    classifier = TrafficClassifier(model_dir)

    # Show model info
    print("\nModel Information:")
    info = classifier.get_model_info()
    for key, value in info.items():
        print(f"  {key}: {value}")

    # Load and classify features
    print(f"\nClassifying flows from {features_file}...")
    features_df = pd.read_csv(features_file)

    results = classifier.classify_batch(features_df)

    # Display results
    print(f"\nClassified {len(results)} flows:")
    for i, result in enumerate(results[:10]):  # Show first 10
        print(f"\nFlow {i+1}:")
        print(f"  Predicted Class: {result['predicted_class']}")
        if 'confidence' in result:
            print(f"  Confidence: {result['confidence']:.4f}")
        if 'class_probabilities' in result:
            print("  Probabilities:")
            for class_name, prob in result['class_probabilities'].items():
                print(f"    {class_name}: {prob:.4f}")

    # Summary
    predictions = [r['predicted_class'] for r in results]
    print("\n\nSummary:")
    for class_name in set(predictions):
        count = predictions.count(class_name)
        percentage = (count / len(predictions)) * 100
        print(f"  {class_name}: {count} flows ({percentage:.1f}%)")


if __name__ == '__main__':
    main()
