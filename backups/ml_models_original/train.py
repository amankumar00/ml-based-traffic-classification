"""
ML Model Training Module
Trains machine learning models for network traffic classification
"""

import os
import json
import pickle
import numpy as np
import pandas as pd
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.ensemble import RandomForestClassifier
from sklearn.svm import SVC
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
from sklearn.neural_network import MLPClassifier
import matplotlib.pyplot as plt
import seaborn as sns


class TrafficClassifierTrainer:
    """
    Trains ML models for traffic classification
    Supports Random Forest, SVM, and Neural Network classifiers
    """

    def __init__(self, model_type='random_forest'):
        """
        Initialize trainer

        Args:
            model_type: Type of model ('random_forest', 'svm', 'neural_network')
        """
        self.model_type = model_type
        self.model = None
        self.scaler = StandardScaler()
        self.label_encoder = LabelEncoder()
        self.feature_names = []
        self.class_names = []

    def load_data(self, csv_path, label_column='traffic_type'):
        """
        Load training data from CSV file

        Args:
            csv_path: Path to CSV file with features and labels
            label_column: Name of column containing traffic type labels

        Returns:
            X (features), y (labels)
        """
        df = pd.read_csv(csv_path)

        if label_column not in df.columns:
            raise ValueError(f"Label column '{label_column}' not found in dataset")

        # Separate features and labels
        y = df[label_column]
        X = df.drop(columns=[label_column, 'flow_key'], errors='ignore')

        # Handle non-numeric features
        X = self._preprocess_features(X)

        self.feature_names = X.columns.tolist()

        return X, y

    def _preprocess_features(self, X):
        """Preprocess features: handle categorical variables, missing values"""
        # Convert protocol to numeric if present
        if 'protocol' in X.columns:
            protocol_mapping = {'TCP': 0, 'UDP': 1, 'ICMP': 2, 'OTHER': 3}
            X['protocol'] = X['protocol'].map(protocol_mapping).fillna(3)

        # Fill missing values with 0
        X = X.fillna(0)

        # Convert all columns to numeric
        for col in X.columns:
            X[col] = pd.to_numeric(X[col], errors='coerce').fillna(0)

        return X

    def create_model(self):
        """Create ML model based on model_type"""
        if self.model_type == 'random_forest':
            self.model = RandomForestClassifier(
                n_estimators=100,
                max_depth=20,
                min_samples_split=5,
                min_samples_leaf=2,
                random_state=42,
                n_jobs=-1
            )
        elif self.model_type == 'svm':
            self.model = SVC(
                kernel='rbf',
                C=10,
                gamma='scale',
                random_state=42
            )
        elif self.model_type == 'neural_network':
            self.model = MLPClassifier(
                hidden_layer_sizes=(100, 50),
                activation='relu',
                solver='adam',
                max_iter=500,
                random_state=42
            )
        else:
            raise ValueError(f"Unknown model type: {self.model_type}")

        print(f"Created {self.model_type} model")
        return self.model

    def train(self, X, y, test_size=0.2):
        """
        Train the model

        Args:
            X: Features
            y: Labels
            test_size: Proportion of data to use for testing

        Returns:
            Dictionary with training results
        """
        # Encode labels
        y_encoded = self.label_encoder.fit_transform(y)
        self.class_names = self.label_encoder.classes_.tolist()

        # Split data
        X_train, X_test, y_train, y_test = train_test_split(
            X, y_encoded, test_size=test_size, random_state=42, stratify=y_encoded
        )

        # Scale features
        X_train_scaled = self.scaler.fit_transform(X_train)
        X_test_scaled = self.scaler.transform(X_test)

        # Create and train model
        if self.model is None:
            self.create_model()

        print(f"\nTraining {self.model_type} model...")
        print(f"Training samples: {len(X_train)}, Test samples: {len(X_test)}")
        print(f"Number of features: {X_train.shape[1]}")
        print(f"Classes: {self.class_names}")

        self.model.fit(X_train_scaled, y_train)

        # Evaluate
        y_pred = self.model.predict(X_test_scaled)
        accuracy = accuracy_score(y_test, y_pred)

        print(f"\nTraining completed!")
        print(f"Test Accuracy: {accuracy:.4f}")

        # Detailed evaluation
        print("\nClassification Report:")
        print(classification_report(y_test, y_pred,
                                   target_names=self.class_names))

        results = {
            'accuracy': accuracy,
            'confusion_matrix': confusion_matrix(y_test, y_pred),
            'y_test': y_test,
            'y_pred': y_pred,
            'model_type': self.model_type,
            'feature_names': self.feature_names,
            'class_names': self.class_names
        }

        return results

    def cross_validate(self, X, y, cv=5):
        """Perform cross-validation"""
        y_encoded = self.label_encoder.fit_transform(y)
        X_scaled = self.scaler.fit_transform(X)

        if self.model is None:
            self.create_model()

        scores = cross_val_score(self.model, X_scaled, y_encoded, cv=cv)
        print(f"\nCross-validation scores: {scores}")
        print(f"Mean accuracy: {scores.mean():.4f} (+/- {scores.std() * 2:.4f})")

        return scores

    def save_model(self, output_dir):
        """Save trained model and preprocessing objects"""
        os.makedirs(output_dir, exist_ok=True)

        # Save model
        model_path = os.path.join(output_dir, f'{self.model_type}_model.pkl')
        with open(model_path, 'wb') as f:
            pickle.dump(self.model, f)

        # Save scaler
        scaler_path = os.path.join(output_dir, 'scaler.pkl')
        with open(scaler_path, 'wb') as f:
            pickle.dump(self.scaler, f)

        # Save label encoder
        encoder_path = os.path.join(output_dir, 'label_encoder.pkl')
        with open(encoder_path, 'wb') as f:
            pickle.dump(self.label_encoder, f)

        # Save metadata
        metadata = {
            'model_type': self.model_type,
            'feature_names': self.feature_names,
            'class_names': self.class_names
        }
        metadata_path = os.path.join(output_dir, 'model_metadata.json')
        with open(metadata_path, 'w') as f:
            json.dump(metadata, f, indent=2)

        print(f"\nModel saved to {output_dir}")

    def plot_results(self, results, output_dir=None):
        """Plot training results and confusion matrix"""
        # Confusion matrix
        plt.figure(figsize=(10, 8))
        sns.heatmap(results['confusion_matrix'],
                   annot=True,
                   fmt='d',
                   cmap='Blues',
                   xticklabels=self.class_names,
                   yticklabels=self.class_names)
        plt.title(f'Confusion Matrix - {self.model_type}')
        plt.ylabel('True Label')
        plt.xlabel('Predicted Label')

        if output_dir:
            os.makedirs(output_dir, exist_ok=True)
            plt.savefig(os.path.join(output_dir, f'{self.model_type}_confusion_matrix.png'))
            print(f"Confusion matrix saved to {output_dir}")
        else:
            plt.show()

        # Feature importance (for Random Forest)
        if self.model_type == 'random_forest' and hasattr(self.model, 'feature_importances_'):
            plt.figure(figsize=(12, 6))
            importances = self.model.feature_importances_
            indices = np.argsort(importances)[::-1][:20]  # Top 20 features

            plt.bar(range(len(indices)), importances[indices])
            plt.xticks(range(len(indices)),
                      [self.feature_names[i] for i in indices],
                      rotation=45,
                      ha='right')
            plt.title('Top 20 Feature Importances')
            plt.xlabel('Features')
            plt.ylabel('Importance')
            plt.tight_layout()

            if output_dir:
                plt.savefig(os.path.join(output_dir, 'feature_importance.png'))
            else:
                plt.show()


def main():
    """Example usage"""
    import sys

    if len(sys.argv) < 2:
        print("Usage: python train.py <training_data.csv> [model_type] [output_dir]")
        print("model_type: random_forest (default), svm, neural_network")
        sys.exit(1)

    data_path = sys.argv[1]
    model_type = sys.argv[2] if len(sys.argv) > 2 else 'random_forest'
    output_dir = sys.argv[3] if len(sys.argv) > 3 else 'data/models'

    # Initialize trainer
    trainer = TrafficClassifierTrainer(model_type=model_type)

    # Load data
    print(f"Loading data from {data_path}...")
    X, y = trainer.load_data(data_path)

    # Train model
    results = trainer.train(X, y)

    # Save model
    trainer.save_model(output_dir)

    # Plot results
    trainer.plot_results(results, output_dir)


if __name__ == '__main__':
    main()
