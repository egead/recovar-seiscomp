# RECOVAR

[![arXiv](https://img.shields.io/badge/arXiv-2407.18402v1-b31b1b.svg)](https://arxiv.org/abs/2407.18402)

## Table of Contents

- [Recovar:](#recovar)
  - [Table of Contents](#table-of-contents)
  - [Installation](#installation)
    - [Prerequisites](#prerequisites)
    - [Using conda (recommended)](#using-conda-recommended)
    - [Using pip](#using-pip)
    - [GPU support](#gpu-support)
  - [SeisComP Integration](#seiscomp-integration)
  - [Contact](#contact)

---

## Installation

### Prerequisites

- **Python:** 3.10 or 3.11. TensorFlow 2.14.0 has no wheel for Python 3.12, so the environment is capped at `<3.12`.
- **TensorFlow / NumPy:** the project is pinned to `tensorflow==2.14.0` and `numpy==1.26.0`. The NumPy pin is required, TensorFlow 2.14 declares no upper bound on NumPy and will crash with an ABI error if NumPy 2.x is installed.
- **NVIDIA GPU drivers + CUDA/cuDNN (optional):** only needed for GPU support; versions must be compatible with TensorFlow 2.14.0.

### Installation Using conda 

The `environment.yml` installs Python 3.10, TensorFlow 2.14.0 and NumPy 1.26.0 together,
and installs the `recovar` package (and dependencies) in
one step.

```bash
git clone git@github.com:egeadg/recovar-seiscomp.git
cd recovar
conda env create -f environment.yml --solver=libmamba
conda activate recovar
```

> The `--solver=libmamba` flag is strongly recommended: conda's classic solver is
> extremely slow at resolving `tensorflow=2.14.0` and may exhaust memory. On
> conda ≥ 23.10 libmamba is already the default and the flag can be omitted.

### GPU support

For GPU execution, install the CUDA-bundled TensorFlow build before installing
the package:

```bash
pip install "tensorflow[and-cuda]==2.14.0"
pip install ".[test]"
```
It's possible to feed numpy arrays directly for training. **model_train.ipynb** provides example for this case. You can also test your data as well. Please check **model_test.ipynb**. Both notebooks are under "recovar_demo" folder. For training and testing, pretrained models are stored in the **models/** folder. Besides, **data/** involves a small dataset
for experimenting. 

## SeisComP Integration
RECOVAR can run as a real-time pick filter inside [SeisComP](https://www.seiscomp.de/),
scoring incoming picks with the pretrained model. The integration lives in the
`seiscomp_integration/` folder and ships its own installer and docs:

- `seiscomp_integration/README.md`, installing the daemon, running it, and querying scored picks.
- `seiscomp_integration/docker/INSTALL.md`, building and starting the container.
- `seiscomp_integration/docker/DEMO.md`, running the pick-filter demo in the container.


## Contact
For any questions, issues, or feature requests, please open an issue on the GitHub repository contact onur.efe44@gmail.com.
