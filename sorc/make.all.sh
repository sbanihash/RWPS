#!/bin/bash
###############################################################################
#                                                                             #
# Compiles all codes, moves executables to exec and cleans up                 #
#                                                                             #
#                                                                 Dec, 2016   #
#                                                                             #
###############################################################################
#


# 1. Build ice field processor

readonly HOMErwps_=$(cd "$(dirname "$(readlink -f -n "${BASH_SOURCE[0]}" )" )/.." && pwd -P)

source ../versions/build.ver

outfile=`pwd`/build_ww3.out
#rm -f ${outfile}

module purge
source ../modulefiles/build_rwps.module
module list 

dirs=`ls -d inpaint*.fd`
codes=`echo $dirs | sed 's/\.fd/ /g'`
if [ ! -d "../exec" ]; then
   echo 'Creating exec directory'
   mkdir ../exec
fi

for i in  $codes
do
        cd ${i}.fd
        make clean > ${outfile} 2>> ${outfile}
        module list >> ${outfile} 2>> ${outfile}
        make >> ${outfile} 2>> ${outfile}
        mv $i ../../exec
        make clean
        cd ../
done



# 2. Build WW3 model code 
# Determine which switch to use 

ww3switch=model/bin/switch_NCEP_rwps


# Check final exec folder exists
if [ ! -d "../exec" ]; then
  mkdir ../exec
fi

finalexecdir=$( pwd -P )/../exec

# Determine machine and load modules
 set +x

 module purge
 source ../modulefiles/build_wavewatch3.modules
 module list 


 set -x

#Set WW3 directory, switch, prep and post exes 
cd WW3
export WW3_DIR=$( pwd -P )
export SWITCHFILE="${WW3_DIR}/${ww3switch}"

# Build exes for prep jobs and post jobs:
prep_exes="ww3_grid ww3_prep ww3_prnc"
post_exes="ww3_outp ww3_gint ww3_ounf ww3_grib"
run_exes="ww3_shel"

#create build directory: 
path_build=$WW3_DIR/build_SHRD
mkdir -p $path_build
cd $path_build
echo "Forcing a SHRD build" 

echo $(cat ${SWITCHFILE}) > ${path_build}/tempswitch


sed -e "s/DIST/SHRD/g" \
  -e "s/OMPG / /g" \
  -e "s/OMPH / /g" \
  -e "s/MPIT / /g" \
  -e "s/MPI / /g" \
  -e "s/PIO / /g" \
  -e "s/B4B / /g" \
  -e "s/PDLIB / /g" \
  -e "s/SCOTCH / /g" \
  -e "s/METIS / /g" \
  -e "s/NOGRB/NCEP2/g" \
  "${path_build}/tempswitch" >"${path_build}/switch"
rm "${path_build}/tempswitch"

echo "Switch file is $path_build/switch with switches:"
cat $path_build/switch

#define cmake build options
MAKE_OPT="-DCMAKE_INSTALL_PREFIX=${path_build}"
if [[ "${BUILD_TYPE:-"Release"}" == "Debug" ]]; then
    MAKE_OPT+=" -DCMAKE_BUILD_TYPE=Debug"
fi

#Build executables:
# shellcheck disable=SC2086
cmake $WW3_DIR -DSWITCH=$path_build/switch -DCMAKE_INSTALL_PREFIX=install
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "Fatal error in cmake."
  exit $rc
fi
make -j 8
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "Fatal error in make."
  exit $rc
fi
make install
if [[ $rc -ne 0 ]] ; then
  echo "Fatal error in make install."
  exit $rc
fi

# Copy to top-level exe directory
cp $path_build/install/bin/ww3_grid $finalexecdir/wavegrid
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_grid to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp $path_build/install/bin/ww3_prep $finalexecdir/waveprep
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_prep to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp $path_build/install/bin/ww3_prnc $finalexecdir/waveprnc
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_prnc to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp $path_build/install/bin/ww3_outp $finalexecdir/wavespec
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_outp to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp $path_build/install/bin/ww3_gint $finalexecdir/wavegrid_interp
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_gint to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp $path_build/install/bin/ww3_ounf $finalexecdir/wavefldn
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_ounf to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp $path_build/install/bin/ww3_ounp $finalexecdir/wavespnc
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_ounp to $finalexecdir (Error code $rc)"
  exit $rc
fi

cp $path_build/install/bin/ww3_grib $finalexecdir/wavegrib2
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_grib to $finalexecdir (Error code $rc)"
  exit $rc
fi

#clean-up build directory:
echo "executables are in $finalexecdir" 
echo "cleaning up $path_build" 
rm -rf $path_build

#create run build directory: 
path_build=$WW3_DIR/build_DIST
mkdir -p $path_build
cd $path_build
echo "Forcing a DIST build" 

echo $(cat ${SWITCHFILE}) > ${path_build}/runswitch

echo "Switch file is $path_build/switch with switches:" 
cat $path_build/runswitch

#Build executables: 
cmake $WW3_DIR -DSWITCH=$path_build/runswitch -DCMAKE_INSTALL_PREFIX=install
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "Fatal error in cmake."
  exit $rc
fi
make -j 8
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "Fatal error in make."
  exit $rc
fi
make install
if [[ $rc -ne 0 ]] ; then
  echo "Fatal error in make install."
  exit $rc
fi

# Copy to top-level exe directory
cp $path_build/install/bin/ww3_shel $finalexecdir/wavefcst
rc=$?
if [[ $rc -ne 0 ]] ; then
  echo "FATAL: Unable to copy $path_build/ww3_multi to $finalexecdir (Error code $rc)"
  exit $rc
fi

#clean-up run build directory:
echo "executables are in $finalexecdir" 
echo "cleaning up $path_build" 
rm -rf $path_build

