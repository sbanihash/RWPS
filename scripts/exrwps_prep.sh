#!/bin/bash
###############################################################################
#                                                                             #
# This script is the preprocessor for the RWPS wave model                     #
# performed by the following child scripts :                                  #
#                                                                             #
#   wavemod_def.sh   :  generate mod_def.ww3 files when needed                #
#   waveice_rwps.sh        :  preprocess ice fields                           #
#   wavendfd_rwps.sh      :  find and copy ndfd wind files (RWPS)             #
#                                                                             #
# Also used is the utililty script                                            #
#                                                                             #
#  wavestart.sh   : get time of most recent restart file.                     #
#                                                                             #
# Remarks :                                                                   #
#                                                                             #
# Origination:                    Saeideh Banihashemi          August, 2025   #
#                                                                             #
###############################################################################
# --------------------------------------------------------------------------- #
# 0.  Preparations
# 0.a Basic modes of operation

  set -x
  # Use LOUD variable to turn on/off trace.  Defaults to YES (on).
  export LOUD=${LOUD:-YES}; [[ $LOUD = yes ]] && export LOUD=YES
  [[ "$LOUD" != YES ]] && set +x

  cd $DATA

  msg="HAS BEGUN on `hostname`"
  postmsg   "$msg"
    msg="Starting RWPS PREPROCESSOR SCRIPT"
  postmsg   "$msg"

  set +x
  echo ' '
  echo '                      ********************************'
  echo '                      *** RWPS PREPROCESSOR SCRIPT ***'
  echo '                      ********************************'
  echo ' '
  echo "Starting at : `date`"
  [[ "$LOUD" = YES ]] && set -x

  rm -f ice.warning

  export lsth_ice=0 # Using only one ice data time slice
  ttime13=36

  wndTAG="ndfd_rwps"

  export buoy='rwps'
  export grids='rwps'
  export igrids=

# 0.b Date and time stuff
#     The ending time of the run always is the $lsth hour forecast. The starting
#     time depends on availablility of restart files, and is obtained with
#     wavestart.sh
#
#     Make sure nback is set identically in the forecast script !!!
#     nback is the number of cycles (12-hour cycles) to look back.
  export date=$PDY
  export YMDH=${PDY}${cyc}
  export nback=0
  $USHrwps/wavestart_rwps.sh
  ymdh_beg=`head wavestart.out | awk '{ print $1 }'`
  rm -f wavestart.out
  time_beg="`echo $ymdh_beg | cut -c1-8` `echo $ymdh_beg | cut -c9-10`0000"    

# Ice file generated for glw and rwps independently, needs ice timing variables set to NAM always
  export YMDH_ICE="${YMDH}"
  ymdh_beg_ice=$ymdh_beg
  ymdh_newtres_ice=`$NDATE ${ttime13} $YMDH_ICE`  
  time_beg_ice="`echo $ymdh_beg_ice | cut -c1-8` `echo $ymdh_beg_ice | cut -c9-10`0000"    

# NDFD winds change from 1 to 3 hourly at this date stamp
  ymdh_newtres_13=`$NDATE 36 ${PDY}00`
# NDFD winds change from 3 to 6 hourly at this date stamp
  ymdh_newtres_36=`$NDATE 72 ${PDY}00`
# Determine which wind files are available

  ymdh=$ymdh_beg
  ndfd_ok='yes'

  set +x
  echo ' '
  echo '+-----------------------------------------------+'
  echo '|   Looking for relevant available NDFD files   |'
  echo '+-----------------------------------------------+'
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

  inc=0
  foundOK='no'
  lookback=12 # hours to look back for NDFD files
  while [ "$inc" -le "$lookback" ] && [ "$foundOK" = 'no' ]
  do
# Search for files sets a +- 30 min search ahead and behind a given bottom of hour

# Find files that are ahead of the search hour (bottom of hour version: search around 30 past)
    ymdht=`$NDATE -$inc $ymdh`
    ymd=`echo $ymdht | cut -c1-8`
    ext=`echo $ymdht | cut -c9-10`
    ndfd_files=`find $DCOMIN/$ymd/wgrbbul/ndfd/glwind_2p5_${ext}[3-5]?.grib2`

# Find files that are behind the search hour
    ymdhb=`$NDATE -$inc $ymdh`
    ymdb=`echo $ymdhb | cut -c1-8`
    extb=`echo $ymdhb | cut -c9-10`
    ndfd_files="${ndfd_files} "`find $DCOMIN/$ymdb/wgrbbul/ndfd/glwind_2p5_${extb}[0-2]?.grib2`
    export ndfd_file="${DATA}/glwind_2p5_${ext}.grib2"
    nndfd=`echo $ndfd_files | wc -w`

    if [ ${nndfd} -eq 0 ]
    then
      set +x
      echo " Could not find NDFD files for ${ndfd_file} (Looking further)"
      [[ "$LOUD" = YES ]] && set -x
    else
      set +x
      echo " Found NDFD files --> ${ndfd_files}"
      [[ "$LOUD" = YES ]] && set -x

      mkdir ./ndfd_tmp
      cd ./ndfd_tmp

      cp ${ndfd_files} ./.

# Set WIND, WDIR and TMP tags
      files=`ls glwind_2p5_????.grib2`

# Search for latest files and ensure only one file per variable is selected
      ntimes=
      for file in $files
      do
        file_vars="`$WGRIB2 -var $file | sed 's/:/ /g' | awk '{print $3}' | uniq`"
        time_tag="`$WGRIB2 -vt $file | sed -e 's/:/ /g' -e 's/vt=/ /g' | awk '{print $3}' | head -1`"
        ntimes="$ntimes $time_tag"
        for nvar in $file_vars
        do
          $WGRIB2 -match $nvar $file -grib ndfd_${nvar}_${time_tag}.grb2 > gen_file.out 2>&1
        done
      done

# Get latest time, second time (if present) and check if there are anough files
      tlatest=`echo $ntimes | xargs -n1 | sort -ur | xargs | awk '{print $1}'`
      tsecond=`echo $ntimes | xargs -n1 | sort -ur | xargs | awk '{print $2}'`
      if [ -f ndfd_WIND_${tlatest}.grb2 ] && [ -f ndfd_WDIR_${tlatest}.grb2 ]
      then
# If latest file has all needed variables, move ahead
        echo " Reading latest ndfd files in selected time range: $tsecond "
        cat ndfd_WIND_${tlatest}.grb2 ndfd_WDIR_${tlatest}.grb2 > ndfd_${tlatest}.grb2
        vtimei=`$WGRIB2 ndfd_${tlatest}.grb2 -var -vt | head -1 | sed 's/:vt=/ /g' | awk '{print $2}'`
        if [ ${vtimei} -le ${ymdh_beg} ]
        then
          cp ndfd_${tlatest}.grb2 ${ndfd_file}
          echo "NDFD file used: ndfd_${tlatest}.grb2" > $DATA/what_${runID}_used.t${cyc}z
        fi
      fi
# If latest files failed try the second file if present
      if [ ! -f ${ndfd_file} ] && [ -f ndfd_WIND_${tsecond}.grb2 ] && [ -f ndfd_WDIR_${tsecond}.grb2 ]
      then
        echo " Trying second ndfd files in selected time range: $tsecond "
        cat ndfd_WIND_${tsecond}.grb2 ndfd_WDIR_${tsecond}.grb2 > ndfd_${tsecond}.grb2
        vtimei=`$WGRIB2 ndfd_${tsecond}.grb2 -var -vt | head -1 | sed 's/:vt=/ /g' | awk '{print $2}'`
        if [ ${vtimei} -le ${ymdh_beg} ]
        then
          cp ndfd_${tsecond}.grb2 ${ndfd_file}
          echo "NDFD file used: ndfd_${tsecond}.grb2" > $DATA/what_${runID}_used.t${cyc}z
        fi
      fi

# Create final NDFD file with found consistent WIND and WDIR data
      if [ -f ${ndfd_file} ]
      then

        cd ${DATA}
        rm -rf ./ndfd_tmp

# Get first time slice of ndfd file
        vtimei=`$WGRIB2 ${ndfd_file} -var -vt | head -1 | sed 's/:vt=/ /g' | awk '{print $2}'`
        if [ ${vtimei} -le ${ymdh_beg} ]
        then
# Get inventory of time stamps in ndfd file
          vtimes_wind=`$WGRIB2 ${ndfd_file} -match WIND -vt | sed 's/:vt=/ /g' | awk '{print $2}' | sort | uniq`
          vtimes_wdir=`$WGRIB2 ${ndfd_file} -match WDIR -vt | sed 's/:vt=/ /g' | awk '{print $2}' | sort | uniq`
          nvt1=`echo $vtimes_wind | wc -w`  
          nvt2=`echo $vtimes_wdir | wc -w`  
          if [ $nvt1 -gt 36 ] && [ ${nvt1} -eq ${nvt2} ]
          then
            vtimes=$vtimes_wind
            foundOK='yes'
          else
            echo " NDFD file has incongruent numbers of WIND and WDIR data (looking further)"
          fi
        else
          echo " NDFD file does not extend back to starting time (Looking further)"
          foundOK='no'
        fi
      fi
    fi
    inc=`expr $inc + 1`
  done

  if [ "$foundOK" = 'no' ]
  then
    msg="FATAL ERROR: COULD NOT FIND RELEVANT NDFD FILES"
    postmsg   "$msg"
    set +x
    echo ' '
    echo '*****************************************************'
    echo '*** FATAL ERROR: DID NOT FIND RELEVANT NDFD FILES ***'
    echo '*****************************************************'
    echo ' '
    echo $msg
    [[ "$LOUD" = YES ]] && set -x
    echo "$runID prep $date $cycle : $grdID.inp missing." >> $wavelog
    err=1;export err;err_chk
  else
    export ndfd_file
    #echo "NDFD files used: $filelist" > what_${runID}_used.t${cyc}z
    if [ ${cyc} -eq 1 ] || [ ${cyc} -eq 7 ] || [ ${cyc} -eq 13 ] || [ ${cyc} -eq 19 ]
    then
      lsth=149
    else
      lsth=48
    fi
    wndID='NDFD'
  fi

  ymdh_end=`$NDATE $lsth $YMDH`
  time_end="`echo $ymdh_end | cut -c1-8` `echo $ymdh_end | cut -c9-10`0000"


  ymdh_end_ice=`$NDATE $lsth_ice $ymdh_beg_ice`
  time_end_ice="`echo $ymdh_end_ice | cut -c1-8` `echo $ymdh_end_ice | cut -c9-10`0000"

  set +x 
  echo ' ' 
  echo 'Times in wave model format :' 
  echo '----------------------------' 
  echo "   date / cycle  : $date $cycle"
  echo "   starting time : $time_beg"
  echo "   ending time   : $time_end"
  echo ' '
 
# 0.c Command file set-up
#     The command file points to $nfile files named cmdfile.$ifile.
#     The actual work is distributed over these files.

  [[ "$LOUD" = YES ]] && set -x
 
  set +x
  echo ' '
  echo '   Making command file(s)'
  echo "   Set up command file structure (type = $cmdtype)."
  echo "      Number of command files  : $nfile"
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

# --------------------------------------------------------------------------- #
# 1.  Get files that are used by most child scripts

  set +x 
  echo 'Preparing input files :'
  echo '-----------------------'
  [[ "$LOUD" = YES ]] && set -x

# 1.a Model definition file

  nmoddef=0

  rm -f cmdfile
  touch cmdfile
  chmod 744 cmdfile

  for grdID in $grids $igrids #$buoy
  do
    if [ -f "$FIXrwps/wave_${modID}_${grdID}.moddef.${rwps_ver}" ]
    then
      set +x
      echo " Mod def file for $grdID found in $FIXrwps. copying ...."
      [[ "$LOUD" = YES ]] && set -x
      cp $FIXrwps/wave_${modID}_${grdID}.moddef.${rwps_ver} mod_def.$grdID

    else
      set +x
      echo " Mod def file for $grdID not found in $FIXrwps. Setting up to generate ..."
      [[ "$LOUD" = YES ]] && set -x
      if [ -f $FIXrwps/wave_$grdID.inp ] || [ -f $FIXrwps/mesh.$grdID ]
      then
        cp $FIXrwps/wave_$grdID.inp $grdID.inp
        cp $FIXrwps/mesh.$grdID mesh.$grdID
      fi

      if [ -f $grdID.inp ] && [ "$grdID" = 'points' ]
      then
        set +x
        echo ' '
        echo "   $grdID.inp copied ($FIXrwps/wave_$grdID.inp)."
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
      elif [ -f $grdID.inp ] && [ -f mesh.$grdID ]
      then
        set +x
        echo ' '
        echo "   $grdID.inp copied ($FIXrwps/wave_$grdID.inp)."
        echo ' '
        [[ "$LOUD" = YES ]] && set -x
      else
        msg="ABNORMAL EXIT: NO INP FILE FOR MODEL DEFINITION FILE"
        postmsg   "$msg"
        set +x
        echo ' '
        echo '*********************************************************** '
        echo '*** FATAL ERROR : NO INP FILE FOR MODEL DEFINITION FILE *** '
        echo '*********************************************************** '
        echo "                                grdID = $grdID"
        echo ' '
        echo $msg
        [[ "$LOUD" = YES ]] && set -x
        echo "$runID prep $date $cycle : $grdID.inp missing." >> $wavelog
        err=2;export err;err_chk
      fi

      echo "$USHrwps/wavemod_def.sh $grdID > $grdID.out 2>&1" >> cmdfile

      nmoddef=`expr $nmoddef + 1`

    fi

  done

# 1.a.1 Execute $mpicmd (if needed)

  if [ "$nmoddef" -gt '0' ]
  then

    set +x
    echo ' '
    echo " Generating $nmoddef mod def files"
    echo ' '
    [[ "$LOUD" = YES ]] && set -x


      mpiexec -np 5 --cpu-bind verbose,core cfp cmdfile
      exit=$?


  fi

# 1.a.2 File check

  for grdID in $grids $igrids $buoy
  do
    if [ -f mod_def.$grdID ]
    then
      set +x
      echo ' '
      echo " mod_def.$grdID succesfully created/copied "
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
    else
      msg="ABNORMAL EXIT: NO MODEL DEFINITION FILE"
      postmsg   "$msg"
      set +x
      echo ' '
      echo '********************************************** '
      echo '*** FATAL ERROR : NO MODEL DEFINITION FILE *** '
      echo '********************************************** '
      echo "                                grdID = $grdID"
      echo ' '
      echo $msg
      [[ "$LOUD" = YES ]] && set -x
      sed "s/^/$grdID.out : /g"  $grdID.out
      echo "$runID prep $date $cycle : mod_def.$grdID missing." >> $wavelog
      err=3;export err;err_chk
    fi
  done

# Remove cmdfile after creating moddef (if the case)
  if ls cmdfile* &> /dev/null; then
    rm -f cmdfile*
  fi

# 1.b Wind preprocessor template file

  if [ -f $FIXrwps/waveprnc.${wndTAG}.tmpl ]
  then
    cp $FIXrwps/waveprnc.${wndTAG}.tmpl .
  fi

  if [ -f waveprnc.${wndTAG}.tmpl ]
  then
    echo "   waveprnc."${wndTAG}".tmpl copied ($FIXrwps/waveprnc."${wndTAG}".tmpl)."
  else
    msg="ABNORMAL EXIT: NO FILE waveprnc."${wndTAG}".tmpl"
    postmsg   "$msg"
    set +x
    echo ' '
    echo '************************************** '
    echo '*** FATAL ERROR : NO TEMPLATE FILE *** '
    echo '************************************** '
    echo ' '
    [[ "$LOUD" = YES ]] && set -x
    echo $msg
    echo "$runID prep $date $cycle : template file missing." >> $wavelog       
    err=4;export err;err_chk
  fi

# This section was exclusive to GLW, but will keep for both GLW and GLWU, in case
# future late runs have other ice types etc, so will generate new ice

# 1.c Ice preprocessor template file
  if [ -f $FIXrwps/waveprep.ice.tmpl ]
  then
    cp $FIXrwps/waveprep.ice.tmpl ./waveprep.ice.tmpl
  fi

  if [ -f waveprep.ice.tmpl ]
  then
    echo "   waveprep.ice.tmpl copied ($FIXrwps/waveprep.ice.tmpl)."
  else
    msg="ABNORMAL EXIT: NO FILE waveprep.ice.tmpl"
    postmsg   "$msg"
    set +x
    echo ' '
    echo '************************************** '
    echo '*** FATAL ERROR : NO TEMPLATE FILE *** '
    echo '************************************** '
    echo ' '
    [[ "$LOUD" = YES ]] && set -x
    echo $msg
    echo "$runID prep $date $cycle : template file missing." >> $wavelog
    err=5;export err;err_chk
  fi

# 1.d copy the wave model mask file


# 1.e Copy the ice template files
#
# This is an approach using directly the T_OEBA88_C_KNWC NIC format
#
  for ftype in mask0 ll  
  do
 
    file=$FIXrwps/T_OEBA88_C_KNWC.${ftype}

    if [ -f $file ]
    then
      cp $file ./
    fi

    if [ -f ${file} ]
    then
      set +x 
      echo "   T_OEBA88_C_KNWC.${ftype} copied."
      [[ "$LOUD" = YES ]] && set -x
    else
      set +x
      echo ' '
      echo '************************************** '
      echo "*** ERROR : NO ICE FIELD ${ftype} FILE *** "
      echo '************************************** '
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
      postmsg   "FATAL ERROR - NO ICE FIELD ${ftype} FILE"
      err=7;export err;err_chk
    fi

  done

# --------------------------------------------------------------------------- #
# 2.  Make command file(s) (ice, SST, coefficient files)i and/or (NDFD winds)

# 2.a Command file set-up
#     The command file points to $nfile files named cmdfile.$ifile.            
#     The actual work is distributed over these files.

  set +x
  echo '   Making command file(s)'
  echo "   Set up command file structure (type = $cmdtype)."
  echo "      Number of command files  : $nfile"
  [[ "$LOUD" = YES ]] && set -x

  touch cmdfile
  chmod 744 cmdfile

  ifile=1

# 2.b Ice preprocessing 
  echo "Ice preprocessing"
  ymdh=$ymdh_beg_ice

  while [ "$ymdh" -le "$ymdh_end_ice" ]
  do
  echo "$USHrwps/waveice_rwps.sh $ymdh > ice_$ymdh.err 2>&1"     >> cmdfile
    tinc_ice=1
    if [ $ymdh -ge $ymdh_newtres_ice -o $ymdh -lt $YMDH_ICE ]
    then
      tinc_ice=3
    fi
    ymdh=`$NDATE $tinc_ice $ymdh`
  done

# 2.c ndfd winds
  ymdh=$ymdh_beg
  hdr='T'

  for ymdh in $vtimes
  do
    if [ "$ymdh" -le "$ymdh_end" ]
    then
      echo "$USHrwps/wavendfd_rwps_inc.sh $ymdh 1 $hdr > ndfd_$ymdh.err 2>&1"     >> cmdfile
# Remove header from subsequent binary WW3 wind files so they can be catted  
      hdr='F'
    else
      break
    fi
  done
# --------------------------------------------------------------------------- #
# 3   Execute command file
# 3.a Execution

  set +x
  echo "   Executing command file."
  [[ "$LOUD" = YES ]] && set -x


    mpiexec -np $ntask --cpu-bind verbose,core cfp cmdfile
    exit=$?


# 3.b Error trap on ${mpicmd} or shell

  if [ "$exit" != '0' ]
  then
    msg="ABNORMAL EXIT: ERROR IN $cmdtype"
    postmsg   "$msg"
    set +x
    echo ' '
    echo '*********************************************** '
    echo "*** FATAL ERROR : ERROR IN aprun OR sh *** "
    echo '*********************************************** '
    echo ' '
    echo ' Probing for errors in cmdfile outputs '
    [[ "$LOUD" = YES ]] && set -x
    cmderr=`grep 'FATAL ERROR' *.err`
    if [ -z "$cmderr" ]
    then
       echo ' '
       echo ' CMDFILE WITH NO OUTPUT, UNKOWN ERROR HAS OCCURRED'
    else
       echo ' '
       echo ' CMDFILE EXITED WITH FOLLOWING ERRORS: '
       grep 'FATAL ERROR' *.err
    fi
    echo "$runID prep $date $cycle : error in $cmdtype." >> $wavelog          
    echo $msg
    err=8;export err;err_chk
  fi

# --------------------------------------------------------------------------- #
# 4.  ICE fields: Check for errors and pack onto input file

  set +x
  echo ' '
  echo '   Checking for errors.'
  [[ "$LOUD" = YES ]] && set -x

# 4.a Check for error in Ice field
#     We will go on if the number of errors in files is less
#     than err_max

  err_max=1
  set +x
  echo '      Sources of NIC-ice files :'
  [[ "$LOUD" = YES ]] && set -x

  ymdh=$ymdh_beg_ice
  nr_err=0

  while [ "$ymdh" -le "$ymdh_end_ice" ]
  do
    if [ -d eice_${ymdh} ]
    then
      postmsg   "    File for $ymdh : error in waveice_rwps.sh"
      set +x
      echo "         File for $ymdh : error in waveice_rwps.sh"
      [[ "$LOUD" = YES ]] && set -x       
      nr_err=`expr $nr_err + 1`
      rm -f eice.$ymdh
    else
      nicfile=`grep 'File for' ice_${ymdh}.err`
      if [ -z "$nicfile" ]
      then
        set +x
        echo "         File for $ymdh : cannot identify source"
        nr_err=`expr $nr_err + 1`
        [[ "$LOUD" = YES ]] && set -x
        rm -f eice.$ymdh
      else
        if [ ! -f T_OEBA88_C_KNWC.$ymdh ]
        then
        set +x
          echo "         File for $ymdh : file not found"
        [[ "$LOUD" = YES ]] && set -x
          nr_err=`expr $nr_err + 1`
        else
        set +x
          echo "      $nicfile"
          mv -f ice_${ymdh}.err ice_${ymdh}.out
        [[ "$LOUD" = YES ]] && set -x
        fi
      fi
    fi
    tinc=1
    if [ $ymdh -ge $ymdh_newtres_ice -o $ymdh -lt $YMDH_ICE ]
    then
      tinc=3
    fi
     ymdh=`$NDATE $tinc $ymdh`
  done

  if ls ice_*.err  1> /dev/null 2>&1
  then
    set +x
    echo ' '
    echo '****************************************'
    echo '*** ERROR OUTPUT waveice_rwps.sh ***'
    echo '****************************************'
    echo '            Possibly in multiple calls'
    echo "$runID prep $date $cycle : error in ice   files." >> $wavelog
    [[ "$LOUD" = YES ]] && set -x
    for file in ice_*.err
    do
      set +x
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
      sed "s/^/$file : /g" $file
    done
     # rm -f ice_*.out
    postmsg   "NON-FATAL ERROR in waveice_rwps.sh, possibly in multiple calls."
  fi
  if [ "$nr_err" -gt "$err_max" ]
  then
    msg="ABNORMAL EXIT: ERROR(S) IN NAM-ICE FILES"
    postmsg   "$msg"
    set +x
    echo ' '
    echo '*********************************************** '
    echo '*** FATAL ERROR : ERROR(S) IN NAM-ICE FILES *** '
    echo '*********************************************** '
    echo $nr_err
    echo ' '
    [[ "$LOUD" = YES ]] && set -x
    echo $msg
    echo "$runID prep $date $cycle : fatal error in NIC   files." >> $wavelog
    err=9;export err;err_chk
  fi
  rm -f cmdfile*

# 4.b  Run waveprep for ice field
  set +x
  echo ' '
  echo '   Running ice field through preprocessor.'
  [[ "$LOUD" = YES ]] && set -x
  sed "s/GRIDLAYOUT/$GRID/g" waveprep.ice.tmpl > ww3_prep.inp
  rm -f waveprep.ice.tmpl

# Here using igrids (the regular grid for ice grlr)
  for grdID in $grids
  do

    cp mod_def.$grdID mod_def.ww3
    $EXECrwps/waveprep > waveprep.out
    err=$?

    if [ "$err" != '0' ]
    then
      msg="ABNORMAL EXIT: ERROR IN waveprep"
      postmsg   "$msg"
      set +x
      echo ' '
      echo '******************************************** '
      echo '*** FATAL ERROR : ERROR IN waveprep *** '
      echo '******************************************** '
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
      echo "$runID $grdID prep $date $cycle : error in waveprep." >> $wavelog
      err=12;export err;err_chk
    fi

    if [ ! -f ice.ww3 ]
    then
      msg="ABNORMAL EXIT: FILE ice.ww3 MISSING"
      postmsg   "$msg"
      set +x
      echo ' '
      cat waveprep.out
      echo ' '
      echo '****************************************'
      echo '*** FATAL ERROR : ice.ww3 NOT FOUND ***'
      echo '****************************************'
      echo ' '
      [[ "$LOUD" = YES ]] && set -x
      echo "$runID $grdID prep $date $cycle : ice.ww3 missing." >> $wavelog
      err=13;export err;err_chk
    else
      set +x
      echo "      Ice file succesfully created for $ymdh"
      [[ "$LOUD" = YES ]] && set -x
      cp ice.ww3 ice.$grdID
    fi
  done
  rm -f eice.*
  rm -f ice.new
  rm -f ww3_prep.inp
# --------------------------------------------------------------------------- #
# 5.  NDFD fields: Check for errors and pack onto input file

# 5.a Error checking made at extraction level, check if files are there
#     and move to final file name

  ymdh=$ymdh_beg

  first='y'

  for ymdh in $vtimes
  do
    if [ "$ymdh" -le "$ymdh_end" ]
    then
      if [ -d ndfd_${ymdh} ]
      then
        set +x
        echo "         Wind data could not be found for $ymdh"
        echo "         Error output from wavendfd_rwps.sh:"
        cat ndfd_$ymdh.err
        ndfd_ok='no'
        [[ "$LOUD" = YES ]] && set -x
      else
        set +x
        echo "      Wind data succesfully extracted for $ymdh"
        [[ "$LOUD" = YES ]] && set -x
          if [ "$first" = 'y' ]
          then
            for grdID in $grids
            do
              mv wind.$grdID.$ymdh wind.$grdID
            done
            first='n'
          else
            for grdID in $grids
            do
              cat wind.$grdID.$ymdh >> wind.$grdID
            done
          fi
        mv -f ndfd_$ymdh.err ndfd_$ymdh.out
      fi
    else
      break
    fi
  done
  
# end of if loop from 5.a 

# 5.b Error captcha

  if [ "$ndfd_ok" = 'no' ]
  then
    msg="ERROR IN EXTRACTING DATA FROM NDFD GRIDS"
    postmsg   "$msg"
    echo ' ' > warning
    echo '***********************************************************' >> warning
    echo '*** WARNING !! ERROR IN EXTRACTING DATA FROM NDFD GRIDS ***' >> warning
    echo "***    Missing NDFD winds for RWPS run $PDY t${cyc}z    ***" >> warning
    echo '***********************************************************' >> warning
    echo ' ' >> warning
    echo "$runID prep $date $cycle : Error converting winds." >> $wavelog
    set +x
    cat warning
    [[ "$LOUD" = YES ]] && set -x
    err=14;export err;./err_chk
  fi

# --------------------------------------------------------------------------- #
# 6.  Output to /com

  if [ "$SENDCOM" = 'YES' ]
  then
    for grdID in $grids $igrids
    do
     for input in wind ice
     do
      set +x
      echo ' '
      if [ -f ${input}.$grdID ]
      then
        echo "   Saving ${input}.$grdID as $COMOUT/$runID.$grdID.$cycle.${input}"        
        [[ "$LOUD" = YES ]] && set -x
        cp ${input}.$grdID $COMOUT/$runID.$grdID.$cycle.${input}
        chmod 664 $COMOUT/$runID.$grdID.$cycle.${input}
      fi
     done
    done

    [[ "$LOUD" = YES ]] && set -x

# Copy the ice file log to com
    cp whatglwice  $COMOUT/whatglwice.$cycle
    if [ -f ice.warning ] ; then echo "$runID prep $date $cycle : missing ice info" >> $wavelog ; fi

    if [ -f ice.warning ] && [ "${runID}" == "rwps" ] ; then
# prepare ice email	
	echo ' ' > email.ice
	echo '******************************************************' >> email.ice
	echo '***   WARNING !! COULD NOT FIND RWPS ICE INFO     ' >> email.ice
	echo '***        (SETTING ICE COVERAGE TO ZEROS)            ' >> email.ice
	echo '******************************************************' >> email.ice
	echo ' ' >> email.ice
   
        mail.py -s "Missing RWPS ice info for $PDY t${cyc}z" email.ice
    fi
      sort -b what_${runID}_used.$cycle > $COMOUT/what_${runID}_used.$cycle
      $SIPHONROOT/bin/dbn_alert MODEL OMBWAVE $job $COMOUT/what_${runID}_used.$cycle
  fi


# --------------------------------------------------------------------------- #
# 7.  Ending output

  set +x
  echo ' '
  echo "Ending at : `date`"
  echo ' '
  echo '                     *** End of RWPS preprocessor ***'
  echo ' '
  [[ "$LOUD" = YES ]] && set -x

  msg="$job completed normally"
  postmsg   "$msg"

# End of GLW preprocessor script -------- ----------------------------------- #
