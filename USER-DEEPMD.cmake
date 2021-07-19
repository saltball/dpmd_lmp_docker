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

include_directories(${LAMMPS_SOURCE_DIR} ${LAMMPS_SOURCE_DIR}/KSPACE ${TENSORFLOW_INCLUDE_DIRS} ${DEEPMD_ROOT}/include ${USER_DEEPMD_INCLUDE_DIRS})

target_sources(lammps PRIVATE ${USER_DEEPMD_SOURCE})
target_link_libraries(lammps PRIVATE ${TFLIB_CC} ${TFLIB_FW} ${DEEPMDLIB_OP} ${DEEPMDLIB_})