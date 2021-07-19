ARG GPU=gpu

FROM tensorflow/tensorflow:latest-devel${GPU:+-$GPU} AS build_image

LABEL maintainer="Saltball <yanbohan98@gmail.com>"

ARG TF_SRC=/tensorflow_src
ARG TF_BINAR=/tensorflow_binaries
ARG PROTOBUF_VERSION=3.17.3
ARG LAMMPS_VERSION=stable_29Oct2020
ARG DPMD_DIR=/dpmd

WORKDIR /
# Get and compile protobuf
RUN  wget https://github.com/protocolbuffers/protobuf/releases/download/v${PROTOBUF_VERSION}/protobuf-cpp-${PROTOBUF_VERSION}.zip &&\
    unzip -q protobuf-cpp-${PROTOBUF_VERSION} &&\
    cd protobuf-${PROTOBUF_VERSION} &&\
    ./configure && make -j$(nproc) install

FROM scratch AS build_image2
COPY --from=build_image / /

ARG TF_SRC=/tensorflow_src
ARG TF_BINAR=/tensorflow_binaries
ARG PROTOBUF_VERSION=3.17.3
ARG LAMMPS_VERSION=stable_29Oct2020
ARG DPMD_DIR=/dpmd

# compile tensorflow
RUN mkdir -p ${TF_BINAR}/lib/&&\
    mkdir -p ${TF_BINAR}/include/ &&\
    cd ${TF_SRC}  &&\
    sed -i -e "s:\${TF_BINAR}:${TF_BINAR}:" tensorflow/core/platform/default/build_config/BUILD &&\
    mkdir -p ./bazel_output_base &&\
    export PYTHON_BIN_PATH=$(which python3) &&\
    export PYTHON_LIB_PATH="$($PYTHON_BIN_PATH -c 'import site; print(site.getsitepackages()[0])')" &&\
    export USE_DEFAULT_PYTHON_LIB_PATH=1 &&\
    # Additional compute capabilities can be added if desired but these increase
    # the build time and size of the package.
    export TF_CUDA_COMPUTE_CAPABILITIES="3.5,5.2,6.0,6.1,7.0,7.5,8.0,8.6" &&\
    export TF_NCCL_VERSION="" &&\
    export GCC_HOST_COMPILER_PATH="$(which gcc)" &&\
    export GCC_HOST_COMPILER_PREFIX=$(dirname "$(which gcc)") &&\


    # additional settings
    # do not build with MKL support
    export TF_NEED_MKL=0 &&\
    export CC_OPT_FLAGS="-march=nocona -mtune=haswell" &&\
    export TF_ENABLE_XLA=0 &&\
    export TF_NEED_OPENCL=0 &&\
    export TF_NEED_OPENCL_SYCL=0 &&\
    export TF_NEED_COMPUTECPP=0 &&\
    export TF_NEED_ROCM=0 &&\
    export TF_NEED_MPI=0 &&\
    export TF_DOWNLOAD_CLANG=0 &&\
    export TF_SET_ANDROID_WORKSPACE=0 &&\

    # CUDA details
    export TF_NEED_CUDA=1 &&\
    # export TF_CUDA_VERSION="${cuda_compiler_version}" &&\
    # export TF_CUDNN_VERSION="${cudnn}" &&\
    export TF_CUDA_CLANG=0 &&\
    export TF_NEED_TENSORRT=0 &&\

    ./configure &&\

    bazel ${BAZEL_OPTS} build \
    --copt=-march=nocona \
    --copt=-mtune=haswell \
    --copt=-ftree-vectorize \
    --copt=-fPIC \
    --copt=-fstack-protector-strong \
    --copt=-O2 \
    --cxxopt=-fvisibility-inlines-hidden \
    --cxxopt=-fmessage-length=0 \
    --linkopt=-zrelro \
    --linkopt=-znow \
    --linkopt="-L${TF_BINAR}/lib" \
    --verbose_failures \
    --config=opt \
    --config=cuda \
    --color=yes \
    --curses=no \
    --jobs=$(nproc)\
    //tensorflow:libtensorflow_cc.so &&\

    mkdir -p $TF_BINAR/lib  &&\
    cp -d bazel-bin/tensorflow/libtensorflow_cc.so* $TF_BINAR/lib/ &&\
    cp -d bazel-bin/tensorflow/libtensorflow_framework.so* $TF_BINAR/lib/ &&\
    cp -d $TF_BINAR/lib/libtensorflow_framework.so.2 $TF_BINAR/lib/libtensorflow_framework.so &&\
    mkdir -p $TF_BINAR/include &&\
    mkdir -p $TF_BINAR/include/tensorflow &&\
    # copy headers
    rsync -avzh --exclude '_virtual_includes/' --include '*/' --include '*.h' --include '*.inc' --exclude '*' bazel-bin/ $TF_BINAR/include/ &&\
    rsync -avzh --include '*/' --include '*.h' --include '*.inc' --exclude '*' tensorflow/cc $TF_BINAR/include/tensorflow/ &&\
    rsync -avzh --include '*/' --include '*.h' --include '*.inc' --exclude '*' tensorflow/core $TF_BINAR/include/tensorflow/ &&\
    rsync -avzh --include '*/' --include '*' --exclude '*.cc' third_party/ $TF_BINAR/include/third_party/ &&\
    rsync -avzh --include '*/' --include '*' --exclude '*.txt' bazel-tensorflow_src/external/eigen_archive/Eigen/ $TF_BINAR/include/Eigen/ &&\
    rsync -avzh --include '*/' --include '*' --exclude '*.txt' bazel-tensorflow_src/external/eigen_archive/unsupported/ $TF_BINAR/include/unsupported/ &&\
    rsync -avzh --include '*/' --include '*.h' --include '*.inc' --exclude '*' bazel-tensorflow_src/external/com_google_protobuf/src/google/ $TF_BINAR/include/google/ &&\
    rsync -avzh --include '*/' --include '*.h' --include '*.inc' --exclude '*' bazel-tensorflow_src/external/com_google_absl/absl/ $TF_BINAR/include/absl/ 

FROM scratch AS build_image3
# copy the build artifacts to the lmp buildtime image
ARG TF_SRC=/tensorflow_src
ARG TF_BINAR=/tensorflow_binaries
ARG PROTOBUF_VERSION=3.17.3
ARG LAMMPS_VERSION=stable_29Oct2020
ARG DPMD_DIR=/dpmd

COPY --from=build_image2 ${TF_BINAR} ${TF_BINAR}
# initialize the build environment
RUN apt update &&\
    apt install git cmake wget mpich python3-dev pkg-config &&\
    git clone https://github.com/deepmodeling/deepmd-kit/ -b devel &&\
    # set varibles
    export tensorflow_root=${TF_BINAR} &&\
    export deepmd_root_to_install=${DPMD_DIR} &&\
    export deepmd_source_dir=/deepmd-kit &&\

    mkdir -p ${deepmd_root_to_install} &&\

    # build deepmd
    cd ${deepmd_source_dir}/source &&\
    mkdir build &&\
    cd build &&\
    cmake -DTENSORFLOW_ROOT=$tensorflow_root -DCMAKE_INSTALL_PREFIX=$deepmd_root_to_install -DUSE_CUDA_TOOLKIT=True .. &&\
    make -j$(nproc) &&\
    make install &&\

    # build deepmd_lammps
    cd ${deepmd_source_dir}/source/build &&\
    make lammps &&\

    # build lmp with dpmd
    export lammps_binary_root=/lammps_bin &&\
    mkdir -p ${lammps_binary_root} &&\
    cd ${lammps_binary_root} &&\
    wget https://github.com/deepmodeling/lammps/archive/refs/tags/${LAMMPS_VERSION}.tar.gz &&\
    tar -xzf ${LAMMPS_VERSION}.tar.gz &&\

    cd ${lammps_binary_root}/lammps-${LAMMPS_VERSION}/src &&\
    cp -r $deepmd_source_dir/source/build/USER-DEEPMD . &&\

    # compile with cmake
    cd ${lammps_binary_root}/lammps-${LAMMPS_VERSION}/cmake &&\
    git clone https://github.com/saltball/dpmd_lmp_docker &&\
    cp dpmd_lmp_docker/USER-DEEPMD.cmake ./Modules/Packages/ &&\
    cp dpmd_lmp_docker/CMake.patch . &&\
    patch -p1 < CMake.patch &&\
    rm dpmd_lmp_docker/ -r &&\

    # compile lammps
    export dpmd_lmp_install_root=/dpmd_lmp_install &&\
    cd ${lammps_binary_root}/lammps-${LAMMPS_VERSION} &&\
    mkdir build &&\
    cd build &&\
    cmake -C ../cmake/presets/most.cmake ../cmake -DBUILD_MPI=on -DPKG_USER-DEEPMD=on -DDEEPMD_ROOT=$deepmd_root_to_install -DTENSORFLOW_INCLUDE_DIRS="$tensorflow_root/include" -DTENSORFLOW_LIBRARY_PATH="$tensorflow_root/lib" -DCMAKE_INSTALL_PREFIX=$dpmd_lmp_install_root &&\

    make -j$(nproc) &&\
    make install

FROM scratch AS build_image4
ARG TF_SRC=/tensorflow_src
ARG TF_BINAR=/tensorflow_binaries
ARG PROTOBUF_VERSION=3.17.3
ARG LAMMPS_VERSION=stable_29Oct2020
ARG DPMD_DIR=/dpmd
# copy the build artifacts to the lmp runtime image
COPY --from=build_image3 ${DPMD_DIR} ${DPMD_DIR}
COPY --from=build_image3 ${TF_BINAR} ${TF_BINAR}
COPY --from=build_image3 /dpmd_lmp_install /dpmd_lmp_install
# set the environment variable
RUN export LD_LIBRARY_PATH=${TF_BINAR}/lib:${LD_LIBRARY_PATH} &&\
    export LD_LIBRARY_PATH=${DPMD_DIR}/lib64:${LD_LIBRARY_PATH} &&\
    export PATH=${DPMD_DIR}/bin:${PATH} 

CMD [ "/bin/bash" ]

