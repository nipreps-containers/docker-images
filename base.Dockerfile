# Use Ubuntu 16.04 LTS
FROM ubuntu:xenial-20200114

# Prepare environment
RUN echo "deb http://us.archive.ubuntu.com/ubuntu/ xenial universe" >> /etc/apt/source.list && \
    echo "deb http://us.archive.ubuntu.com/ubuntu/ xenial-updates universe" >> /etc/apt/source.list && \
    apt-get update && \
    apt-get install -y --no-install-recommends          \
                    curl bzip2 ca-certificates          && \
    apt-get install -y --no-install-recommends          \
                    tcsh gsl-bin netpbm libjpeg62 xvfb  \
                    xterm libglu1-mesa-dev              \
                    libglw1-mesa libxm4 build-essential && \
    apt-get install -y --no-install-recommends          \
                    libquadmath0 tclsh wish file unzip && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Installing ANTs 2.2.0 (NeuroDocker build)
ENV ANTSPATH=/opt/ants
RUN mkdir -p $ANTSPATH && \
    curl -sSL "https://dl.dropbox.com/s/2f4sui1z6lcgyek/ANTs-Linux-centos5_x86_64-v2.2.0-0740f91.tar.gz" \
    | tar -xzC $ANTSPATH --strip-components 1

# FSL environment
ENV FSLDIR="/opt/fsl" \
    FSLOUTPUTTYPE="NIFTI_GZ" \
    FSLMULTIFILEQUIT="TRUE" \
    LD_LIBRARY_PATH="$FSLDIR/lib:$LD_LIBRARY_PATH" \
    FSLTCLSH="/usr/bin/tclsh" \
    FSLWISH="/usr/bin/wish" \
    POSSUMDIR="/usr/share/fsl/5.0"

# AFNI environment
ENV AFNIPATH="/opt/afni" \
    AFNI_MODELPATH="$AFNIPATH/models" \
    AFNI_IMSAVE_WARNINGS="NO" \
    AFNI_TTATLAS_DATASET="$AFNIPATH/atlases" \
    AFNI_PLUGINPATH="$AFNIPATH/plugins"

# FreeSurfer environment
ENV FSL_DIR="$FSLDIR" \
    FS_OVERRIDE=0 \
    FIX_VERTEX_AREA="" \
    FSF_OUTPUT_FORMAT="nii.gz" \
    FREESURFER_HOME="/opt/freesurfer"
ENV SUBJECTS_DIR="$FREESURFER_HOME/subjects" \
    FUNCTIONALS_DIR="$FREESURFER_HOME/sessions" \
    MNI_DIR="$FREESURFER_HOME/mni" \
    LOCAL_DIR="$FREESURFER_HOME/local" \
    MINC_BIN_DIR="$FREESURFER_HOME/mni/bin" \
    MINC_LIB_DIR="$FREESURFER_HOME/mni/lib" \
    MNI_DATAPATH="$FREESURFER_HOME/mni/data"
ENV PERL5LIB="$MINC_LIB_DIR/perl5/5.8.5" \
    MNI_PERL5LIB="$MINC_LIB_DIR/perl5/5.8.5"

# Setup PATH
ENV PATH="$FREESURFER_HOME/bin:$FSFAST_HOME/bin:$FREESURFER_HOME/tktools:$MINC_BIN_DIR:$PATH"
ENV PATH=$ANTSPATH:$AFNIPATH:$FSLDIR/bin:$PATH

COPY --from=docker.pkg.github.com/nipreps/afni/afni:20.3.02 /opt/afni $AFNIPATH
COPY --from=docker.pkg.github.com/nipreps/fsl/fsl:6.0.4 /opt/fsl $FSLDIR
# COPY --from=docker.pkg.github.com/nipreps/freesurfer/freesurfer:6.0.1 /opt/freesurfer $FREESURFER_HOME

# Installing and setting up miniconda
RUN curl -sSLO https://repo.continuum.io/miniconda/Miniconda3-4.5.11-Linux-x86_64.sh && \
    bash Miniconda3-4.5.11-Linux-x86_64.sh -b -p /usr/local/miniconda && \
    rm Miniconda3-4.5.11-Linux-x86_64.sh

# Set CPATH for packages relying on compiled libs (e.g. indexed_gzip)
ENV PATH="/usr/local/miniconda/bin:$PATH" \
    CPATH="/usr/local/miniconda/include/:$CPATH" \
    LANG="C.UTF-8" \
    LC_ALL="C.UTF-8" \
    PYTHONNOUSERSITE=1

# Installing precomputed python packages
RUN conda install -y python=3.7.1 \
                     graphviz=2.40.1 \
                     libxml2=2.9.8 \
                     libxslt=1.1.32 \
                     matplotlib=2.2.2 \
                     mkl-service \
                     mkl=2018.0.3 \
                     numpy=1.15.4 \
                     pandas=0.23.4 \
                     scikit-learn=0.19.1 \
                     scipy=1.1.0 \
                     setuptools=44.0.0 \
                     setuptools_scm=3.4.3 \
                     toml=0.10 \
                     traits=4.6.0 \
                     zlib; sync && \
    chmod -R a+rX /usr/local/miniconda; sync && \
    chmod +x /usr/local/miniconda/bin/*; sync && \
    conda clean --all -y; sync && \
    conda clean -tipsy && sync

# Precaching fonts, set 'Agg' as default backend for matplotlib
RUN python -c "from matplotlib import font_manager" && \
    sed -i 's/\(backend *: \).*$/\1Agg/g' $( python -c "import matplotlib; print(matplotlib.matplotlib_fname())" )

# Unless otherwise specified each process should only use one thread - nipype
# will handle parallelization
ENV MKL_NUM_THREADS=1 \
    OMP_NUM_THREADS=1

ENV IS_DOCKER_8395080871=1
RUN ldconfig
