# RECOVAR

**User manual: https://egead.github.io/recovar-seiscomp**

[![arXiv](https://img.shields.io/badge/arXiv-2407.18402v1-b31b1b.svg)](https://arxiv.org/abs/2407.18402)

## Installation

### Installation Using conda 

The `environment.yml` installs Python 3.10, TensorFlow 2.14.0 and NumPy 1.26.0 together, and installs the `recovar` package (and dependencies)

```bash
git clone https://github.com/egead/recovar-seiscomp.git
cd recovar-seiscomp
conda env create -f environment.yml --solver=libmamba
conda activate recovar
```

## Demo
`demo.ipynb` scores a real MiniSEED file end to end and shows a labeled dataset ROC/AUC benchmark. It uses `data/test.mseed` (450 s of `KO.DKL..HH?` around the M6.1 Bigadiç–Balıkesir 2025 earthquake).

To rebuild `data/test.mseed` from IRIS:

```bash
python mseed_demo/create_test_mseed.py
```

## Examples

Run these notebooks from the `recovar_demo/` folder. 

### Training: `recovar_demo/model_train.ipynb`

Trains `RepresentationLearningMultipleAutoencoder` on `data/X_train_1280sample.npy`.

```bash
cd recovar_demo
jupyter notebook model_train.ipynb
```

- Runs on CPU. Remove `CUDA_VISIBLE_DEVICES=""`to train on GPU. 
- Trains for `EPOCHS = 1`. Change it in the configuration cell.
- Saves a checkpoint per epoch to `recovar_demo/checkpoints/autoencoder_epoch_XX.h5` and the final weights to `recovar_demo/checkpoints/representation_cross_covariances.h5`.

### Testing: `recovar_demo/model_test.ipynb`

Scores `data/X_test_1280sample.npy` and plots the ROC curve with AUC against `data/Y_test_1280sample.npy`.

```bash
cd recovar_demo
jupyter notebook model_test.ipynb
```

- Uses `models/representation_cross_covariances.h5` by default. To test the model trained in `model_train.ipynb`, set `MODEL_PATH = 'checkpoints/representation_cross_covariances.h5'`.
- To try another model, change the model cell, the classifier cell (if needed) and `MODEL_PATH` together.

## SeisComP Integration
RECOVAR can run as a real-time pick filter inside [SeisComP](https://www.seiscomp.de/),
scoring incoming picks with the pretrained model. The integration files are under
`seiscomp_integration/` folder

- `seiscomp_integration/README.md`, installing the daemon, running it, and querying scored picks.
- `seiscomp_integration/docker/INSTALL.md`, building and starting the container.
- `seiscomp_integration/docker/DEMO.md`, running the pick-filter demo in the container.

### GPU support
For GPU execution, install the CUDA-bundled TensorFlow build before installing the package

```bash
pip install "tensorflow[and-cuda]==2.14.0"
pip install ".[test]"
```

## License

RECOVAR is released under the GNU AGPL v3 (see [`LICENSE`](./LICENSE)). 

## Contact
For any questions, issues, or feature requests, please open an issue on the GitHub repository contact onur.efe44@gmail.com.
