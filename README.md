# Clinical Reporting in R

This is the clinical reporting pipeline.
Currently, it creates a genetic report of somatic mutations from a vcf file annotated via [Ensembl Variant Effect Predictor](https://github.com/Ensembl/ensembl-vep).

*Note*: CIViC only supports reference genome build 37.

## Installation
We recommend running the pipeine as either Docker or Singularity container, such that all dependencies are
encapsulated.

### Docker
The Docker engine needs to be installed on the build machine for building Docker images.
The process of building the Docker images is split into two consecutive parts:
1. base
2. reporting

The `clinical-reporting` image can be built via:
```
make base
make reporting
```
The `make base` step will take a lot of time, as the cache for the human genome assembly from Ensembl
has to be built. It will build the `clinical-reporting-base` image, which will then be used as the base
image for the actual `clinical-reporting` image.

The `make reporting` step will build the `clinical-reporting` image, which will be used for report
generation.


At the end of the build process, your Docker host should have the image
```
clinical-reporting:latest
```
available.

### Singularity
Currently, the Singularity image must be built from the corresponding Docker image. Use
the supplied recipe file `Singularity` for this purpose.


## Usage

### Docker
Put all the VCF files for which a report should be generated into a directory on your host system. This
directory needs to be mounted inside the container for processing. Given that the VCF files are 
stored at `$VCF_DIR` on the host system, we can then run the reporting pipeline via:
```
docker run --rm -v $VCF_DIR:/inout clinical-reporting:latest
````
The ``--rm`` switch will ensure that the container is going to be removed after it exits. The above 
command also demonstrates that the directory on the host containing the VCF files needs to be mounted at the
`/inout` directory inside the container.






