# Public data release

The source images and tabular data supporting the associated manuscript are
distributed as the GitHub release
[`data-v1.0.0`](https://github.com/dk862900122-jpg/surface-moisture-rgb-imaging/releases/tag/data-v1.0.0).

## Contents

- 130 laboratory JPEG images in `group1 images/`
- 210 laboratory JPEG images in `group 2 images/`
- 90 field JPEG images in `field images/`
- 16 images generated using camera colour-temperature/white-balance settings
- 201 images from the additional Jiaohe and Suoyang soil datasets
- 203 images from the surface-roughness assessment
- three CSV tables containing 130 laboratory, 210 laboratory, and 90 field observations
- `DATASET_README.md` with directory, variable, range, and provenance details
- `FILE_MANIFEST.csv` with file sizes and SHA-256 checksums

The release contains 850 JPEG images and three source CSV tables. The ZIP
archive SHA-256 checksum is:

```text
220c50fa82899e7133a5b6af7ed72eee52ee2ef1dcecdccb4373b04c01d54725
```

No grey-card or colour-card correction was applied. The colour-temperature
folder records camera colour-temperature/white-balance settings and should not
be interpreted as an experiment with independently controlled physical
light-source CCT.

All EXIF APP1 metadata was removed from the public JPEG copies to exclude
acquisition dates and camera or lens serial identifiers. The files were not
recompressed. The compressed image scan data and image dimensions were
verified as unchanged for all 850 images.

The original filenames and schemas are retained. The CSV tables do not include
a complete filename identifier column, so the release does not claim an exact
row-to-filename mapping beyond the moisture labels present in filenames and
directory names.

The release is distributed under the repository MIT License.

