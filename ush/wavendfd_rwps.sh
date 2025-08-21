#!/bin/sh
###############################################################################
#                                                                             #
# This script converts ndfd files into wind.ww3 format files for WW3          #
#                                                                             #
# This version extracts forcing fields information from the ndfd grib2 file.  #
#                                                                             #
# Remarks :                                                                   #
# - This script runs in the work directory designated in the mother script in #
#   which it generates its own sub-directory 'ndfd_yyyymmddhh'. If all's well #
#   the directory is renamed at the end of the script.                        #
# - The time group yyyymmddhh is the first parameter passed to the script.    #
# - See section 0.c for variables that need to be set.                        #
#                                                                             #
# Script parameters are:                                                      #
#  $1            - DateTime of data being processed                           #
#  count=$2      - File count                                                 #
#  hdr=$3        - Header defining if ww3 binary will have a header           #
#                                                                             #
#                                                                August 2025  #
#                                                                             #
###############################################################################
#
# --------------------------------------------------------------------------- #
# 0.  Preparations
# 0.a Basic modes of operation

  echo ' Start of wavendfd_rwps.sh at: '
  date

  cd $DATA

  set -x
  # Use LOUD variable to turn on/off trace.  Defaults to YES (on).
  export LOUD=${LOUD:-YES}; [[ $LOUD = yes ]] && export LOUD=YES
  [[ "$LOUD" != YES ]] && set +x

  rm -rf ndfd_$1
  mkdir ndfd_$1
  cd ndfd_$1

  count=$2
  hdr=$3

  set +x
  echo ' '
  echo '+--------------------------------+'
  echo '!     Find and copy ndfd files    |'
  echo '+--------------------------------+'
  [[ "$LOUD" = YES ]] && set -x

# 0.b Check if time set

  if [ "$#" -lt '1' ]
  then
    set +x
    echo ' '
    echo '***************************************'
    echo '*** TIME IN wavendfd_rwps.sh NOT SET ***'
    echo '***************************************'
    echo ' '
    [[ "$LOUD" = YES ]] && set -x
    postmsg   " TIME IN wavendfd_rwps.sh NOT SET"
    exit 1
  else
    ymdh=$1
    set +x
    echo "   Time            : $ymdh"
    echo ' '
    [[ "$LOUD" = YES ]] && set -x
  fi

# 0.c The tested variables should be exported by the calling script.

  if [ -z "$DCOMIN" ] || [ -z "$EXECrwps" ]
  then
    set +x
    echo ' '
    echo '**********************************'
    echo '*** EXPORTED VARIABLES NOT SET ***'
    echo '**********************************'
    echo ' '
    postmsg   " EXPORTED VARIABLES NOT SET."
    exit 1
    [[ "$LOUD" = YES ]] && set -x
  fi

# --------------------------------------------------------------------------- #
# 1. The ndfd file has been selected by the mother script

# --------------------------------------------------------------------------- #
# 1b. Convert grib2 ndfd to regular ndfd, compute UGRD/VGRD, interpolate to 
#     regular grid and create netcdf file. (Interpolation is needed because 
#     the WW3 netcdf preprocessor only works with regular grids)

# Convert NDFD file scan order to make sense to wgrib2 #
  $WGRIB2 ${ndfd_file} -match "(WIND|WDIR)" -rpn alt_x_scan -set table_3.4 64 -grib_out glwnd.grb2

# Convert to UGRD/VGRD
  $WGRIB2 glwnd.grb2 -match "(WIND|WDIR)" \
     -if "WIND" -rpn "sto_1" -fi \
     -if "WDIR" -rpn "sto_2" -fi \
     -if_reg 1:2 \
       -rpn "rcl_2:3.141592:*:180:/:sin:rcl_1:*:-1:*:clr_1:clr_2" \
       -set_var UGRD \
       -grib_out ugrd.grib2 > ugrib.out 2>&1

  $WGRIB2 glwnd.grb2 -match "(WIND|WDIR)" \
     -if "WIND" -rpn "sto_1" -fi \
     -if "WDIR" -rpn "sto_2" -fi \
     -if_reg 1:2 \
       -rpn "rcl_2:3.141592:*:180:/:cos:rcl_1:*:-1:*:clr_1:clr_2" \
       -set_var VGRD \
       -grib_out vgrd.grib2 > vgrib.out 2>&1

# Unify UGRD/VGRD files
  cat ugrd.grib2 vgrd.grib2 > gluv.grb2

# Interpolate to regular grid and higher reslution to avoid resolution cramp
  $WGRIB2 gluv.grb2 -new_grid_winds earth -new_grid_vectors UGRD:VGRD -new_grid latlon 267.28:1376:0.0125 41.1675:910:.009 gluv.grib2 > grib_interp.out 2>&1

# Final store on NetCDF file
  $WGRIB2 gluv.grib2 -netcdf gluv.nc > grib2nc.out 2>&1

  if [ -f gluv.nc ]
  then
    ndfdOK='yes'
  else
    ndfdOK='no'
  fi
 
# --------------------------------------------------------------------------- #
# 2. run waveprep 

  if [ "$ndfdOK" = 'yes' ]
  then

# 2.a Prepare the input file

    sed -e "s/HDR/$hdr/g" ../waveprnc.ndfd_rwps.tmpl > ww3_prnc.inp

# 2.b Execute code

    for grdID in $grids
    do 

      cp ../mod_def.$grdID mod_def.ww3
      $EXECrwps/waveprnc > waveprnc.out.$ymdh 
      err=$?

      if [ "$err" != '0' ]
      then
        set +x
        echo ' '
        echo '*****************************************'
        echo '*** FATAL ERROR IN EXECUTING WAVEPREP ***'
        echo '*****************************************'
        echo ' '
        postmsg   "ERROR IN EXECUTING WAVEPREP FOR $ymdh."
        [[ "$LOUD" = YES ]] && set -x
        ndfdOK='no'
      else
        if [ ! -f wind.ww3 ]
        then
          set +x
          echo ' '
          echo '****************************************'
          echo '*** FATAL ERROR : wind.ww3 NOT FOUND ***'
          echo '****************************************'
          echo ' '
          postmsg   "ERROR IN EXECUTING WAVEPREP FOR $ymdh."
          [[ "$LOUD" = YES ]] && set -x
          ndfd_ok='no'
        else
          set +x
          echo ' '
          echo " Run succesful moving wind file ..."
          [[ "$LOUD" = YES ]] && set -x
          cp -f wind.ww3 ../wind.$grdID.$ymdh
          cp -f wdata.dat ../wdata.$grdID.$ymdh
          cp -f wmask.dat ../wmask.dat
          cp -f ll.dat ../ll.dat
        fi
      fi

    done
  
  else
    set +x
    echo ' '
    echo '**************************************************'
    echo '*** FATAL ERROR : COULD NOT GENERATE wind file ***'
    echo '**************************************************'
    echo ' '
    postmsg   "COULD NOT EXTRACT WIND FOR $ymdh."
    [[ "$LOUD" = YES ]] && set -x
    ndfdOK='no'
  fi

# --------------------------------------------------------------------------- #
# 3.  Clean up the directory

  if [ "$ndfdOK" = 'yes' ]
  then
    set +x
    echo ' '
    echo "   Removing work directory after success."
    [[ "$LOUD" = YES ]] && set -x

    cd ..

# rm -rf ndfd_$ymdh
  mv ndfd_$ymdh ndfd_${ymdh}_done

  fi

  set +x
  echo ' '
  echo 'End of wavendfd_rwps.sh at'
  date

# End of wavendfd_rwps.sh ---------------------------------------------------- #
