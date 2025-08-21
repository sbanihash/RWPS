#!/bin/sh
###############################################################################
#                                                                             #
# This script finds the most recent restart file for a wave model and         #
# determines the corresponding initial time of the model.                     #
#                                                                             #
# Remarks :                                                                   #
#  - The ymdh of corresponding to the restart file is copied to wavestart.out #
#  - Note that the start time is offset to assure that the hindcasts use      #
#    final FGS products only.                                                 #
#  - This script is expected to operate quietly.                              #
#                                                                             #
#  Update record :                                                            #
#                                                                             #
# - Origination:                           Saeideh Banihashemi August 2025    #
#                                                                             #
###############################################################################
#
# --------------------------------------------------------------------------- #
# 0.  Preparations
#     Check necessary export variables.

  if [ -z "$YMDH" ] || [ -z "${COMINwave}" ] || [ -z "$modID" ] ||\
     [ -z "$nback" ] || [ -z "$RUN" ]  || [ -z "$runID" ] 
 
  then
    echo ' '
    echo '*******************************************************'
    echo '*** EXPORTED VARIABLES IN wavestart.sh NOT SET ***'
    echo '*******************************************************'
    echo ' '
    postmsg   "EXPORTED VARIABLES IN wavestart.sh NOT SET"
    exit 1
  fi

  off_hour=0

  stp_hour=1 # Hourly RWPS runs

# --------------------------------------------------------------------------- #
# 1.  Loop to find file

  ymdh=`$NDATE +${stp_hour} ${YMDH}`
  iback=0

  while [ "$iback" -le "$nback" ]
  do
    ymdh=`$NDATE -${stp_hour} ${ymdh}`
    date=`echo $ymdh | cut -c 1-8`
    cycle=t`echo $ymdh | cut -c 9-10`z

    dir=${COMINwave}/${RUN}.${date}

    if [ -d "$dir" ]
    then
      set +e
      nr=`ls ${dir}/${runID}.${runID}.${cycle}.restart 2> /dev/null | wc -l | awk '{print $1}'`
      set -e
      if [ "$nr" -gt '0' ]
      then
        iback=${nback}
      fi
    fi

    iback=`expr $iback + 1`

  done

# --------------------------------------------------------------------------- #
# 2.  Write file

  ymdh=`$NDATE +${off_hour} ${ymdh}`
  echo $ymdh > wavestart.out

# End of wavestart.sh -------------------------------------------------- #
