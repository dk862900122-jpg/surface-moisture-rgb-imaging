# Normalized RGB imaging for surface-moisture prediction

This repository contains the MATLAB code associated with the manuscript
"Normalized RGB imaging and transfer learning predict surface moisture at
exposed earthen sites."

The workflow extracts image-based colour features, constructs a laboratory
random-forest reference model, evaluates direct transfer to field data, and
trains a field-adapted model. No grey-card or colour-card correction is used
by any script in this repository.

## Repository contents

| File | Purpose |
| --- | --- |
| `matlab/extract_rgb_channels.m` | Fits the R, G, and B histograms of cropped JPEG images and exports the fitted channel locations. |
| `matlab/rgb_to_hsv_lab_converter.m` | Interactively converts RGB values to HSV, CIELAB, LCh, XYZ, and CMYK values. |
| `matlab/train_reference_model.m` | Trains and validates the laboratory random-forest reference model. |
| `matlab/validate_reference_model.m` | Applies the reference model directly to an independent field dataset. |
| `matlab/train_transfer_model.m` | Trains and evaluates the field-adapted random-forest model. |
| `matlab/quantify_surface_roughness.m` | Quantifies image-based pore descriptors and the pore evolution deterioration index. |
| `DATA_FORMAT.md` | Describes the required input files, columns, and principal outputs. |
| `DATASET.md` | Describes the public source-image and tabular-data release. |

Script filenames were standardised for repository use; the main function
filename `rgb_to_hsv_lab_converter.m` was retained because MATLAB requires the
file and primary function names to match. In `train_transfer_model.m`, the
independent field test subset is created before feature screening. Test samples
are excluded from feature selection, model fitting, and bias correction.
Feature screening is also refitted within each cross-validation training fold.

## Requirements

The scripts require MATLAB and use functions from the following products:

- Statistics and Machine Learning Toolbox
- Curve Fitting Toolbox
- Image Processing Toolbox

The exact MATLAB release used to generate the manuscript results was not
recorded in the supplied code folder. The scripts have therefore not been
assigned an unsupported release claim.

## Running the workflow

1. Set the MATLAB current folder to `matlab`.
2. Add the required images or tabular data described in `DATA_FORMAT.md`.
3. Run `extract_rgb_channels.m` to obtain fitted RGB-channel values when
   starting from cropped images.
4. Prepare the normalised RGB columns and measured gravimetric water content.
5. Run `train_reference_model.m` to create `final_model_tuned.mat`.
6. Run `validate_reference_model.m` for direct field validation.
7. Run `train_transfer_model.m` for field adaptation and independent test-set
   evaluation.

`rgb_to_hsv_lab_converter.m` and `quantify_surface_roughness.m` are supporting
utilities and are run independently when their outputs are required.

## Data availability

The author-provided source images and tabular data are available from the
GitHub release [`data-v1.0.0`](https://github.com/dk862900122-jpg/surface-moisture-rgb-imaging/releases/tag/data-v1.0.0).
The release contains 850 JPEG images, three CSV tables, a dataset README, and a
SHA-256 file manifest. See `DATASET.md` and `DATA_FORMAT.md` for the directory
and variable descriptions.

The supplied CSV tables do not encode a complete row-to-image identifier map.
The original filenames, directory labels, and table schemas have therefore
been preserved rather than retrospectively assigning unsupported identifiers.

## Reproducibility note

The repository and data release were checked for credentials, local absolute
paths, duplicate images, and embedded GPS records. No credentials, absolute
paths, duplicate JPEG files, or GPS records were found. EXIF metadata was
removed from the public JPEG copies without recompressing the image data. The
compressed image scan data and dimensions were verified as unchanged for all
850 files. MATLAB was not available in the preparation environment, so the
scripts were not executed there.

## Citation

Citation metadata are provided in `CITATION.cff`. Please cite the associated
article after its final bibliographic details become available.

## License

The code is released under the MIT License. See `LICENSE`.

