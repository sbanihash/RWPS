#!/bin/sh
###############################################################################
#                                                                             #
# This is the actual forcast script for the RWPS wave model. It               #
# uses only a single ush script                                               #
#                                                                             #
#    wavestart.sh   Determine the time for the most recent available          #
#  restart file                                                               #
#                                                                             #
# For non-fatal errors output is witten to the wave.log file.                 #
#                                                                             #
# Initial RWPS workflow            Saeideh Banihashemi       August,  2025    #
#                                                                             #
###############################################################################
# --------------------------------------------------------------------------- #
# 0.  Preparations
# 0.a Basic modes of operation

  cd $DATA

# 0.a.1 Grids

  grids='rwps'
#  grids='rwps_mic rwps_hur'
  igrids=
  winds='rwps'
#  winds='rwps_mic rwps_hur'
  ice='rwps'
#  ice='rwps_mic rwps_hur'
# buoy='rwps_mic rwps_hur'
  buoy='rwps'

  seton='-xa'
  setoff='+xa'
  postmsg   "HAS BEGUN on `hostname`"

  msg="Starting RWPS WAVE MODEL SCRIPT"
  postmsg   "$msg"

  set $setoff
  echo ' '
  echo '*****************************'
  echo '** Regional WAVE SYSTEM **'
  echo '*** RWPS: UNSTRUCTURED !! ***'
  echo '*****************************'
  echo ' '
  echo "Starting at : `date`"
  set $seton

# --------------------------------------------------------------------------- #
# 1.  Set times
# 1.a Times

  export date=$PDY
  export YMDH=${PDY}${cyc}

  if [ ${cyc} -eq 1 ] || [ ${cyc} -eq 7 ] || [ ${cyc} -eq 13 ] || [ ${cyc} -eq 19 ]
  then
    lsth=149
  else
    lsth=48
  fi

  nrst=1
    
# 1.b Set all necessary times.        
#     YMDH     :  nowcast time in yyyymmddhh format 
#     time_beg :  begin time of run9 hour hindcast)         
#     time_rst :  restart file time6 hours after $time_beg) 
#     time_end :  ending time of run$lsth hour forecast)    
   
# off_hour is the offset for reding a prior restart file
# stp_hour is the step for generating restart files 
  grep 'off_hour=' $USHrwps/wavestart_rwps.sh   > time_info
  grep 'stp_hour=' $USHrwps/wavestart_rwps.sh  >> time_info

  . ./time_info ; rm -f time_info

    if [ "$RetroRun" = "YES" ]
    then
     stp_hour=6 # Retro runs are for long cycles only
    fi

  ymdh=`$NDATE $off_hour $YMDH`
  time_beg="`echo $ymdh | cut -c1-8` `echo $ymdh | cut -c9-10`0000"

  ymdh=`$NDATE $stp_hour $ymdh`
  time_rsts="`echo $ymdh | cut -c1-8` `echo $ymdh | cut -c9-10`0000"

  rst_hour=`expr $nrst \* $stp_hour - $stp_hour`
  ymdh=`$NDATE $rst_hour $ymdh`
  time_rste="`echo $ymdh | cut -c1-8` `echo $ymdh | cut -c9-10`0000"
  
  ymdh=`$NDATE $off_hour $YMDH`
  ymdh=`$NDATE $lsth $ymdh`
  time_end="`echo $ymdh | cut -c1-8` `echo $ymdh | cut -c9-10`0000"

  set $setoff
  echo ' '
  echo 'Times in wave model format :'
  echo '----------------------------'
  echo "   date / cycle  : $date $cycle"
  echo "   starting time : $time_beg"
  echo "   restart timestart) : $time_rsts"
  echo "   restart timeend)   : $time_rste"
  echo "   ending time   : $time_end"
  echo ' '

# --------------------------------------------------------------------------- #
# 2.  Get and prepare input and output files      
    
  echo 'Preparing input files :'      
  echo '-----------------------'      
  set $seton    
    
# 2.a Model definition file 
    
  for grdID in $grids $igrids $buoy   
  do
    
    if [ ! -f mod_def.$grdID ]        
    then      
      echo "   Copy mod_def.$grdID from $FIXrwps/wave_${modID}_$grdID.moddef.${rwps_ver}"      
      cp $FIXrwps/wave_${modID}_$grdID.moddef.${rwps_ver} mod_def.$grdID        
    fi
    
    if [ -f mod_def.$grdID ]  
    then      
      echo "   mod_def.$grdID exists."  
    else      
      msg="ABNORMAL EXIT: NO MODEL DEFINITION FILE" 
      postmsg   "$msg"      
      set $setoff         
      echo ' '  
      echo '********************************************** '  
      echo '*** FATAL ERROR : NO MODEL DEFINITION FILE *** '  
      echo '********************************************** '  
      echo ' '  
      echo "$runID fcst $date $cycle : fixed file(s) missing." >> $wavelog   
      echo $msg 
      set $seton
      err=1;export err;err_chk        
    fi        
    
  done        
    
# 2.b Wind file 
    
  for grdID in $winds     
  do
    
    if [ ! -f wind.$grdID ] 
    then      
      echo "   Copy wind.$grdID from $COMIN/$runID.$grdID.$cycle.wind"
      cp $COMIN/$runID.$grdID.$cycle.wind wind.$grdID         
    fi        
    
    if [ -f wind.$grdID ]   
    then      
      echo "   wind.$grdID exists."   
    else      
      msg="ABNORMAL EXIT: NO WIND FILE" 
      postmsg   "$msg"      
      set $setoff         
      echo ' '  
      echo '********************************** '  
      echo '*** FATAL ERROR : NO WIND FILE *** '  
      echo '********************************** '  
      echo ' '  
      echo "$runID $grdID fcst $date $cycle : wind file missing." >> $wavelog  
      echo $msg 
      set $seton
      err=2;export err;err_chk        
    fi        
    
  done        
    
# 2.c Boundary data file    
    
   echo '*******************************************'         
   echo '*** NO BOUNDARY DATA FILE FOR GLW MODEL ***'         
   echo '*******************************************'         
    
# 2.d Ice file  
    
  for grdID in $ice       
  do
    
    if [ ! -f ice.$grdID ]  
    then      
      echo "   Copy ice.$grdID from $COMIN/$runID.$grdID.$cycle.ice"
      cp $COMIN/$runID.$grdID.$cycle.ice ice.$grdID 
    fi        
    
    if [ -f ice.$grdID ]    
    then      
      echo "   ice.$grdID exists."    
      ice_flag=T
    else      
      echo "   ice.$grdID not found.   **** WARNING **** "       
      ice_flag=F
      echo "$runID $grdID fcst $date $cycle : no ice file." >> $wavelog      
      postmsg   "NON-FATAL ERROR - ice.$grdID NOT FOUND."
    fi        
    
  done        
    
# --------------------------------------------------------------------------- #
# 2.e Restart file        
#     Normally, we will pick up the file $runID.$grdID.$cycle.restart file   
#     that has been placed here from the previous cycle run. If that file    
#     is not there, we try to find a restart from a  cycle up to a maximum   
#     of nback cycles back. If there is no restart file anywhere, a cold     
#     start is performed automatically. The corresponding starting time      
#     is set in wavestart.sh     
#   
#     Make sure nback is set identically in the preprocessor !!!   
    
  export nback=0
  $USHrwps/wavestart_rwps.sh

  ymdh=`head wavestart.out | awk '{ print $1 }'`         
  rm -f wavestart.out  
    
  time_ini="`echo $ymdh | cut -c1-8` `echo $ymdh | cut -c9-10`0000"
  ymdh=`$NDATE -$off_hour $ymdh`
  rdate=`echo $ymdh | cut -c 1-8`     
  rcycle=t`echo $ymdh | cut -c 9-10`z   

  INrst=${COMINrst}/${RUN}.${rdate}  
   
  echo "Attempting to copy restart file from $dir"

  for grdID in $grids     
  do
    
    file=$runID.$grdID.${rcycle}.restart
    if [ -d $INrst ]        
    then      
      if [ -f $INrst/$file ]  
      then    
        cp  $INrst/$file restart.$grdID   
      fi      
    fi        
    
    if [ ! -f restart.$grdID ]        
    then      
      msg="   restart.$grdID not found (COLD START).      **** WARNING **** "  
      postmsg   "$msg"      
      echo "   restart.$grdID not found (COLD START).     **** WARNING **** "  
      echo "$runID $gridID fcst $date $cycle : cold start." >> $wavelog      
      cold_start=yes      
    else      
      echo "   restart.$grdID copied ($dir/$file)." 
      if [ "$time_ini" != "$time_beg" ] 
      then    
       set $setoff        
        echo ' '
        echo " model start time and restart times are not compatible (older restart is being used)"
        echo "  restart time     = $time_ini"     
        echo "  model start time = $time_beg"     
        echo ' '
        set $seton        
        echo "$runID fcst $date $cycle : older restart used (${rdate} ${rcycle})." >> $wavelog
        postmsg   "OLDER RESTART USED (${rdate} ${rcycle})." 
      fi      
      cold_start=no       
    fi        
    
  done        
    
# 2.f Buoy location file    
    
  if [ -f $FIXrwps/wave_$modID.buoys ]  
  then        
    cp $FIXrwps/wave_$modID.buoys buoy.loc        
  fi
    
  if [ -f buoy.loc ]      
  then        
    echo "   buoy.loc copied ($FIXrwps/wave_$modID.buoys)."   
  else        
    echo "   buoy.loc not found.   **** WARNING **** " 
    postmsg   " **** WARNING **** buoy.loc NOT FOUND"  
    touch buoy.loc        
    echo "$runID fcst $date $cycle : no buoy locations file." >> $wavelog    
  fi
    
# 2.g Create model input file from template       
    
  if [ -f $FIXrwps/wavefcst.$runID.tmpl ]    
  then        
    cp $FIXrwps/wavefcst.$runID.tmpl wavefcst.inp.tmpl   
  fi
    
  if [ ! -f wavefcst.inp.tmpl ]  
  then        
    msg="ABNORMAL EXIT: NO TEMPLATE FOR INPUT FILE" 
    postmsg   "$msg"        
    set $setoff 
    echo ' '    
    echo '************************************************ '  
    echo '*** FATAL ERROR : NO TEMPLATE FOR INPUT FILE *** '  
    echo '************************************************ '  
    echo ' '    
    echo "$runID fcst $date $cycle : fixed file(s) missing." >> $wavelog     
    echo $msg   
    set $seton  
    err=3;export err;err_chk
  fi
 
  sed -e "s/RUN_BEG/$time_ini/g" \
      -e "s/RUN_END/$time_end/g" \
      -e "s/OUT_BEG/$time_beg/g" \
      -e "s/OUT_END/$time_end/g" \
      -e "s/DTFLD/ 3600/g" \
      -e "s/FIELDS/N \n WND HS FP DP ICE LM SPR MXH WBT WCC WCH PHS PTP PDIR/g" \
      -e "s/DTPNT/ 3600/g" \
      -e "s/INPUT_CURFLD/ F F /g" \
      -e "s/INPUT_WINDS/ T F /g" \
      -e "s/INPUT_ICEFLD/ T F /g" \
      -e "/BUOY_FILE/r buoy.loc" \
      -e "s/BUOY_FILE/DUMMY/g" \
      -e "s/RST_TMES/$time_rsts/g" \
      -e "s/RST_TMEE/$time_rste/g" \
                                     wavefcst.inp.tmpl | \
  sed -n "/DUMMY/!p"               > ww3_shel.inp
 
#  rm -f wavefcst.inp.tmpl        
   
pwd

# --------------------------------------------------------------------------- #
# 3.  Run model 
    
  set $setoff   
  echo ' '    
  echo 'Start the wave model :'       
  echo '----------------------'       
  echo ' '
  echo "  RWPS is using $wndID winds "
  echo ' '
  set $seton    
  postmsg   "Start the wave model."     

# Link to ww3 extensions
  ln -fs mod_def.${grids} mod_def.ww3
  ln -fs wind.${grids} wind.ww3
  ln -fs ice.${grids} ice.ww3
  ${mpicmd} $EXECrwps/wavefcst         
  err=$?      
    
  if [ "$err" != '0' ]    
  then        
    pgm=wave_fcst         
    msg="ABNORMAL EXIT: ERROR IN wavefcst"   
    postmsg   "$msg"        
    set $setoff 
    echo ' '    
    echo '******************************************** '      
    echo '*** FATAL ERROR : ERROR IN wavefcst *** '      
    echo '******************************************** '      
    echo ' '    
    echo "$runID fcst $date $cycle : model crashed." >> $wavelog   
    echo $msg   
    set $seton  
    err=4;export err pgm;err_chk      
  fi
  postmsg   "Wave Model completed."     
    
  if [ "$cold_start" = 'no' ] && [ -n "`grep 'old start' log.ww3`" ]         
  then        
    echo "$runID fcst $date $cycle : cold start (not found until section 3)." \
       >> $wavelog 
    postmsg   "COLD START (not found until section 3)."  
  fi
    
# --------------------------------------------------------------------------- #
# 4.  Save and clean up files         
# 4.a Send files to com if requested  
    
  if [ "$SENDCOM" = 'YES' ] 
  then        
    set $setoff 
    echo ' '    
    echo 'Saving output files :'      
    echo '---------------------'      
    set $seton  
    
    echo "`hostname -s`" > $COMOUT/where_${runID}_ran.$cycle  
    
    if [ -f log.mww3 ] ; then         
      echo "   Copying log.mww3      to $COMOUT/$runID.$cycle.log" 
      cp               log.mww3         $COMOUT/$runID.$cycle.log  
    fi        
   
    if [ -f out_pnt.${buoy} ] ; then   
      echo "   Copying out_pnt.${buoy} to $COMOUT/$runID.${buoy}.$cycle.outpnt"      
      cp               out_pnt.${buoy}    $COMOUT/$runID.${buoy}.$cycle.outpnt       
    fi        
   
    for grdID in $grids   
    do        
    
      if [ -f log.$grdID ] ; then     
        echo "   Copying log.$grdID      to $COMOUT/$runID.$grdID.$cycle.log"  
        mv               log.$grdID         $COMOUT/$runID.$grdID.$cycle.log 
      fi      
    
      if [ -f out_grd.$grdID ] ; then   
        echo "   Copying out_grd.$grdID  to $COMOUT/$runID.$grdID.$cycle.outgrd"         
        cp               out_grd.$grdID     $COMOUT/$runID.$grdID.$cycle.outgrd
      fi      
      
    done

      irst=1
      ymdh=$YMDH

      while [ "$irst" -le "$nrst" ]
      do
        ymdh=`$NDATE $stp_hour $ymdh`
        ndate=`echo $ymdh | cut -c 1-8`
        ncycle=t`echo $ymdh | cut -c 9-10`z
        OUTrst=${COMOUTrst}/${RUN}.${ndate}
        if [ ! -d $OUTrst ]; then
          mkdir -p $OUTrst
        fi
        srst="00${irst}"
        for grdID in $grids
        do
          if [ -f restart${srst}.$grdID ] ; then
            echo "   Copying restart${srst}.$grdID to $OUTrst/$runID.$grdID.$ncycle.restart"
            cp               restart${srst}.$grdID    $OUTrst/$runID.$grdID.$ncycle.restart
          fi
        done

        irst=`expr $irst + 1`
      done      

  fi  

# 4.b Clean up unwanted files         
    
#  rm -f mod_def.* wind.* ice.* restart* 
#  rm -f wavefcst.inp   
    
# --------------------------------------------------------------------------- #
# 5.  Ending output      
    
  set $setoff   
  echo ' '    
  echo "Ending at : `date`" 
  echo ' '    
  echo '        *** End of RWPS forecast script ***'  
  echo ' '    
  msg="End of GLWU WAVE MODEL SCRIPT"  
  postmsg   "$msg"
    
# End of script ------------------------------------------------------------- #
