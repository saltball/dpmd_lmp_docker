# build deepmdlib
```bash
apt update
apt install git cmake wget mpich python3-dev pkg-config

git clone https://github.com/deepmodeling/deepmd-kit/ -b devel
# set varibles
tensorflow_root=/tensorflow_binaries
deepmd_root_to_install=/dpmd
deepmd_source_dir=/deepmd-kit

mkdir $deepmd_root_to_install
```
## build deepmd
```bash
cd $deepmd_source_dir/source/
mkdir build
cd $deepmd_source_dir/source/build
cmake -DTENSORFLOW_ROOT=$tensorflow_root -DCMAKE_INSTALL_PREFIX=$deepmd_root_to_install -DUSE_CUDA_TOOLKIT=True ..
make -j $(nproc)
make install
```

##build deepmd_lammps
```bash
cd $deepmd_source_dir/source/build
make lammps
```

# build lmp with dpmd
```bash
lammps_source_files_name=stable_29Oct2020
lammps_binary_root=/lammps_bin
mkdir $lammps_binary_root
cd $lammps_binary_root # buildplace
wget https://github.com/lammps/lammps/archive/refs/tags/$lammps_source_files_name.tar.gz
tar xf stable_29Oct2020.tar.gz

cd $lammps_binary_root/lammps-$lammps_source_files_name/src/
cp -r $deepmd_source_dir/source/build/USER-DEEPMD .
# make yes-kspace
# make yes-user-deepmd
# make mpi -j4
```
# 使用CMake编译
使用cmake workflow
对于现有的cmake结构需要调整部分文件
需要在`cmake/Modules/Packages`下添加一`USER-DEEPMD.cmake`，内容为
```CMake
set(CXX_STANDARD 11)
add_definitions(-DHIGH_PREC)

set(USER_DEEPMD_INCLUDE_DIR '${LAMMPS_SOURCE_DIR}/USER-DEEPMD' CACHE STRING 'Path to USER-DEEPMD plugin headers')
set(USER_DEEPMD_INCLUDE_DIRS '${USER_DEEPMD_INCLUDE_DIR}')

MESSAGE(STATUS ${TENSORFLOW_LIBRARY_PATH})
file(GLOB DEEPMDLIB_OP ${DEEPMD_ROOT}/lib/libdeepmd_op*)
file(GLOB DEEPMDLIB_ ${DEEPMD_ROOT}/lib/libdeepmd*)
file(GLOB TFLIB_CC ${TENSORFLOW_LIBRARY_PATH}/*_cc.so)
file(GLOB TFLIB_FW ${TENSORFLOW_LIBRARY_PATH}/*_framework.so)
file(GLOB USER_DEEPMD_SOURCE ${USER_DEEPMD_INCLUDE_DIRS}/*)
MESSAGE(STATUS ${DEEPMDLIB_OP} OP ${DEEPMDLIB_} DP ${TFLIB_CC} ${TFLIB_FW} DPMDSRC ${USER_DEEPMD_SOURCE})

include_directories(${LAMMPS_SOURCE_DIR} ${LAMMPS_SOURCE_DIR}/KSPACE ${TENSORFLOW_INCLUDE_DIRS} ${DEEPMD_ROOT}/include ${USER_DEEPMD_INCLUDE_DIRS>

target_sources(lammps PRIVATE ${USER_DEEPMD_SOURCE})

target_link_libraries(lammps PRIVATE ${TFLIB_CC} ${TFLIB_FW} ${DEEPMDLIB_OP} ${DEEPMDLIB_})

```

并修改CMakeLists.txt，在`STANDARD_PACKAGES`中添加`USER-DEEPMD`
if(PKG_USER-DEEPMD)
  include(Packages/USER-DEEPMD)
endif()
#TODO 用patch实现

```bash
dpmd_lmp_install_root=/dpmd_lmp

cd $lammps_binary_root/lammps-$lammps_source_files_name
mkdir build
cd build/
cmake -C ../cmake/presets/most.cmake ../cmake -DBUILD_MPI=on -DPKG_USER-DEEPMD=on -DDEEPMD_ROOT=$deepmd_root_to_install -DTENSORFLOW_INCLUDE_DIRS="$tensorflow_root/include" -DTENSORFLOW_LIBRARY_PATH="$tensorflow_root/lib" -DCMAKE_INSTALL_PREFIX=$dpmd_lmp_install_root

cmake -DPKG_USER-DEEPMD=ON -DPKG_USER-MISC=ON -DFFT=FFTW3 -DCMAKE_INSTALL_PREFIX=${dpmd_lmp_install_root} -D CMAKE_CXX_FLAGS="-I${deepmd_root_to_install}/include -I${deepmd_root_to_install}/include/deepmd -L${deepmd_root_to_install}/lib -Wl,--no-as-needed -lrt -ldeepmd_op -ldeepmd -ltensorflow_cc -ltensorflow_framework -Wl,-rpath=${tensorflow_root}/lib" ../cmake

make -j$(nproc)
#make install
```