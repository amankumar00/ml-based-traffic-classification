"""
Setup script for ML-SDN project
"""

from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

with open("requirements.txt", "r", encoding="utf-8") as fh:
    requirements = [line.strip() for line in fh if line.strip() and not line.startswith("#")]

setup(
    name="ml-sdn",
    version="0.1.0",
    author="Your Name",
    author_email="your.email@example.com",
    description="ML-based SDN Traffic Classification System",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/yourusername/ml-sdn",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: Developers",
        "Intended Audience :: Science/Research",
        "Topic :: System :: Networking",
        "Topic :: Scientific/Engineering :: Artificial Intelligence",
        "License :: OSI Approved :: MIT License",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
    ],
    python_requires=">=3.8",
    install_requires=requirements,
    entry_points={
        "console_scripts": [
            "ml-sdn-controller=src.controller.sdn_controller:main",
            "ml-sdn-train=src.ml_models.train:main",
            "ml-sdn-classify=src.ml_models.classifier:main",
            "ml-sdn-extract=src.traffic_monitor.feature_extractor:main",
        ],
    },
)
