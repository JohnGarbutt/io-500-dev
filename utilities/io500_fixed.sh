#!/bin/bash -e
#IO-500 benchmark
# Do not edit this file.  Edit io500.sh to set parameters as you would like.  Then run it; it will source this file.
# If you discover a need to edit this file, please email the mailing list to discuss.

set -euo pipefail   # give bash better error handling.
export LC_NUMERIC=C  # prevents printf errors

function main {
  check_variables
  output_description
  core_setup
  ior_easy "write"
  mdt_easy "write"
  touch $timestamp_file  # this file is used subsequently by the find command
  ior_hard "write"
  mdt_hard "write"
  myfind
  ior_easy "read"
  mdt_easy "stat"
  ior_hard "read"
  mdt_hard "stat"
  mdt_easy "delete"
  mdt_hard "read"
  mdt_hard "delete"
  mdreal
  cleanup
  output_score
}

function cleanup {
  [ "$io500_cleanup_workdir" != "True" ] && printf "\n[Leaving] datafiles in $io500_workdir\n" && return 0
  echo "[Removing] all files in $io500_workdir"
}

function output_description {
  extra_description
  echo "System: " `uname -n`
  echo "filesystem_utilization=$(df ${io500_workdir}|tail -1)"
  echo "date=$timestamp"
  (set -o posix; set | grep '^io500' | sort)
}

function check_variables {
  local important_vars="io500_workdir io500_ior_easy_params io500_ior_easy_size io500_mdtest_hard_files_per_proc io500_ior_hard_writes_per_proc io500_find_cmd io500_ior_cmd io500_mdtest_cmd io500_mpirun"

  for V in $important_vars; do
    [ -z "${!V}" -o "${!V}" = "xxx" ] &&
      echo "Need to set '$V' in io500.sh" && exit 1
  done

  return 0
}

# helper utility to run an mpi job
function myrun {
  command="$io500_mpirun $io500_mpiargs $1"
  echo "[Exec] $command"
  $command > $2 2>&1
  echo "[Results] in $2."
}

function get_ior_bw {
  file=$1
  operation=$2
  grep '^'$operation $file | head -1 | awk '{print $2/1024}'
}

function get_ior_time {
  file=$1
  operation=$2
  grep '^'$operation $file | head -1 | awk '{print $8}'
}

function get_mdt_iops {
  file=$1
  op=$2
  grep '^ *File '$op $file | awk '{print $4/1000}'
}

function ior_easy {
  phase="ior_easy_$1"
  [ "$io500_run_ior_easy" != "True" ] && printf "\n[Skipping] $phase\n" && return 0

  params_ior_easy="-C -Q 1 -g -G 27 -k -e $io500_ior_easy_params -o $io500_workdir/ior_easy/ior_file_easy -O stoneWallingStatusFile=$io500_workdir/ior_easy/stonewall"
  result_file="$io500_result_dir/$phase.txt"

  if [[ "$1" == "write" ]] ; then
    startphase
    myrun "$io500_ior_cmd -w $params_ior_easy -O stoneWallingWearOut=1 -D $io500_stonewall_timer " $result_file
    endphase_check "write" "io500_ior_easy_size"
    bw1=$(get_ior_bw $result_file "write")
    dur=$(get_ior_time $result_file "write")
    print_bw 1 $bw1 $dur "$invalid"
  else
    [ "$io500_run_ior_easy_read" != "True" ] && printf "\n[Skipping] $phase\n" && return 0
    startphase
    myrun "$io500_ior_cmd -r -R $params_ior_easy" $result_file
    endphase_check "read"
    bw3=$(get_ior_bw $result_file "read")
    dur=$(get_ior_time $result_file "read")
    print_bw 3 $bw3 $dur "$invalid"
  fi
}

function mdt_easy {
  phase="mdtest_easy_$1"
  [ "$io500_run_md_easy" != "True" ] && printf "\n[Skipping] $phase\n" && return 0

  params_md_easy="-F -d $io500_workdir/mdt_easy -n $io500_mdtest_easy_files_per_proc $io500_mdtest_easy_params -x $io500_workdir/mdt_easy-stonewall"
  result_file=$io500_result_dir/$phase.txt

  if [[ "$1" == "write" ]] ; then
    startphase
    myrun "$io500_mdtest_cmd -C $params_md_easy -W $io500_stonewall_timer" $result_file
    endphase_check "write" "io500_mdtest_easy_files_per_proc"
    iops1=$( get_mdt_iops $result_file "creation" )
    print_iops 1 $iops1 $duration "$invalid"
  elif [[ "$1" == "stat" ]] ; then
    [ "$io500_run_md_easy_stat" != "True" ] && printf "\n[Skipping] $phase\n" && return 0
    startphase
    myrun "$io500_mdtest_cmd -T $params_md_easy" $result_file
    endphase_check "stat"
    iops4=$( get_mdt_iops $result_file "stat" )
    print_iops 4 $iops4 $duration "$invalid"
  else
    [ "$io500_run_md_easy_delete" != "True" ] && printf "\n[Skipping] $phase\n" && return 0
    startphase
    myrun "$io500_mdtest_cmd -r $params_md_easy" $result_file
    endphase_check "delete"
    iops6=$( get_mdt_iops $result_file "removal" )
    print_iops 6 $iops6 $duration "$invalid"
  fi
}

function ior_hard {
  phase="ior_hard_$1"
  [ "$io500_run_ior_hard" != "True" ] && printf "\n[Skipping] $phase\n" && return 0

  params_ior_hard="-C -Q 1 -g -G 27 -k -e -t 47008 -b 47008 -s $io500_ior_hard_writes_per_proc $io500_ior_hard_other_options -o $io500_workdir/ior_hard/IOR_file -O stoneWallingStatusFile=$io500_workdir/ior_hard/stonewall"
  result_file="$io500_result_dir/$phase.txt"

  if [[ "$1" == "write" ]] ; then
    startphase
    myrun "$io500_ior_cmd -w $params_ior_hard -O stoneWallingWearOut=1 -D $io500_stonewall_timer" $result_file
    endphase_check "write" "io500_ior_hard_writes_per_proc"
    bw2=$(get_ior_bw $result_file "write")
    dur=$(get_ior_time $result_file "write")
    print_bw 2 $bw2 $dur "$invalid"
  else
    [ "$io500_run_ior_hard_read" != "True" ] && printf "\n[Skipping] $phase\n" && return 0
    startphase
    myrun "$io500_ior_cmd -r -R $params_ior_hard" $result_file
    endphase_check "read"
    bw4=$(get_ior_bw $result_file "read")
    dur=$(get_ior_time $result_file "read")
    print_bw 4 $bw4 $dur "$invalid"
  fi
}

function mdt_hard {
  phase="mdtest_hard_$1"
  [ "$io500_run_md_hard" != "True" ] && printf "\n[Skipping] $phase\n" && return 0

  params_md_hard="-t -F -w $mdt_hard_fsize -e $mdt_hard_fsize -d $io500_workdir/mdt_hard -n $io500_mdtest_hard_files_per_proc -x $io500_workdir/mdt_hard-stonewall $io500_mdtest_hard_other_options"
  result_file=$io500_result_dir/$phase.txt

  if [[ "$1" == "write" ]] ; then
    startphase $phase
    myrun "$io500_mdtest_cmd -C $params_md_hard -W $io500_stonewall_timer" $result_file
    endphase_check "write" "io500_mdtest_files_per_proc"
    iops2=$( get_mdt_iops $result_file "creation" )
    print_iops 2 $iops2 $duration "$invalid"
  elif [[ "$1" == "stat" ]] ; then
    [ "$io500_run_md_hard_stat" != "True" ] && printf "\n[Skipping] $phase\n" && return 0
    startphase
    myrun "$io500_mdtest_cmd -T $params_md_hard" $result_file
    endphase_check "stat"
    iops5=$( get_mdt_iops $result_file "stat" )
    print_iops 5 $iops5 $duration "$invalid"
  elif [[ "$1" == "read" ]] ; then
    [ "$io500_run_md_hard_read" != "True" ] && printf "\n[Skipping] $phase\n" && return 0
    startphase
    myrun "$io500_mdtest_cmd -E $params_md_hard" $result_file
    endphase_check "read"
    iops7=$( get_mdt_iops $result_file "read" )
    print_iops 7 $iops7 $duration "$invalid"
  else
    [ "$io500_run_md_hard_delete" != "True" ] && printf "\n[Skipping] $phase\n" && return 0
    startphase
    myrun "$io500_mdtest_cmd -r $params_md_hard" $result_file
    endphase_check "delete"
    iops8=$( get_mdt_iops $result_file "removal" )
    print_iops 8 $iops8 $duration "$invalid"
  fi
}

function mdreal {
  phase="mdreal"
  [ "$io500_run_mdreal" != "True" ] && printf "\n[Skipping] $phase\n" && return 0
  echo "Running mdreal"
  io500_mdreal_params="-I=3 -L=$io500_result_dir/mdreal -D=1 $io500_mdreal_params  -- -D=${io500_workdir}/mdreal"
}

function myfind {
  phase="find"
  [ "$io500_run_find" != "True" ] && printf "\n[Skipping] $phase\n" && return 0
  result_file=$io500_result_dir/$phase.txt

  command="$io500_find_cmd $io500_workdir -newer $timestamp_file -size ${mdt_hard_fsize}c -name *01* $io500_find_cmd_args"

  startphase $phase
  if [ "$io500_find_mpi" != "True" ] ; then
    echo "[EXEC] $command"
    matches=$( $command | grep MATCHED | tail -1 )
  else
    myrun "$command" $result_file
    matches=$( grep MATCHED $result_file | tail -1 )
  fi

  endphase_check "find"
  totalfiles=`echo $matches | cut -d \/ -f 2`
  iops3=`echo "scale = 2; ($totalfiles / $duration)/1000" | bc`
  echo "[FIND] $matches in $duration seconds"
  print_iops 3 $iops3 $duration "$invalid"
}

function output_score {
  echo "[Summary] Results files in $io500_result_dir"
  if [ "$io500_cleanup_workdir" != "True" ] ; then
    echo "[Summary] Data files in $io500_workdir"
  fi
  cat $summary_file | grep BW
  cat $summary_file | grep IOPS
  bw_score=`echo $bw1 $bw2 $bw3 $bw4 | awk '{print ($1*$2*$3*$4)^(1/4)}'`
  md_score=`echo $iops1 $iops2 $iops3 $iops4 $iops5 $iops6 $iops7 $iops8 | awk '{print ($1*$2*$3*$4*$5*$6*$7*$8)^(1/8)}'`
  tot_score=`echo $bw_score $md_score | awk '{print ($1*$2)^(1/2)}'`
  if [ "$io500_run_ior_easy" != "True" ] ; then
    echo "IOR Easy Write skipped. Aggregate score is not valid."
    io500_invalid="-invalid"
  fi
  if [ "$io500_run_md_easy" != "True" ] ; then
    echo "MD Easy Create skipped. Aggregate score is not valid."
    io500_invalid="-invalid"
  fi
  if [ "$io500_run_ior_hard" != "True" ] ; then
    echo "IOR Hard Write skipped. Aggregate score is not valid."
    io500_invalid="-invalid"
  fi
  if [ "$io500_run_md_hard" != "True" ] ; then
    echo "MD Hard Create skipped. Aggregate score is not valid."
    io500_invalid="-invalid"
  fi
  if [ "$io500_run_find" != "True" ] ; then
    echo "Find skipped. Aggregate score is not valid."
    io500_invalid="-invalid"
  fi
  if [ "$io500_run_ior_easy_read" != "True" ] ; then
    echo "IOR Easy Read skipped. Aggregate score is not valid."
    io500_invalid="-invalid"
  fi
  if [ "$io500_run_md_easy_stat" != "True" ] ; then
    echo "MD Easy Stat skipped. Aggregate score is not valid."
    io500_invalid="-invalid"
  fi
  if [ "$io500_run_ior_hard_read" != "True" ] ; then
    echo "IOR Hard Read skipped. Aggregate score is not valid."
    io500_invalid="-invalid"
  fi
  if [ "$io500_run_md_hard_stat" != "True" ] ; then
    echo "MD Hard Stat skipped. Aggregate score is not valid."
    io500_invalid="-invalid"
  fi
  if [ "$io500_run_md_easy_delete" != "True" ] ; then
    echo "MD Easy Delete skipped. Aggregate score is not valid."
    io500_invalid="-invalid"
  fi
  if [ "$io500_run_md_hard_delete" != "True" ] ; then
    echo "MD Hard Delete skipped. Aggregate score is not valid."
    io500_invalid="-invalid"
  fi
  if [ -n "$io500_invalid" ]; then
    echo "One or more test phases invalid.  Not valid for IO-500 submission."
  fi
  echo "[SCORE$io500_invalid] Bandwidth $bw_score GB/s : IOPS $md_score kiops : TOTAL $tot_score" | tee -a $summary_file
}

function core_setup {
  echo "Running the IO500 Benchmark now"
  echo "[Creating] directories"
  pushd . > /dev/null
  cd $io500_workdir
  mkdir -p ior_easy mdt_easy mdt_hard ior_hard mdreal $io500_result_dir
  popd > /dev/null
  timestamp_file=$io500_workdir/timestampfile  # this file is used by the find command
  summary_file=$io500_result_dir/result_summary.txt
  iops1=0;iops2=0;iops3=0;iops4=0;iops5=0;iops6=0;iops7=0;iops8=0
  bw1=0;bw2=0;bw3=0;bw4=0
  mdt_hard_fsize=3901
  io500_invalid=""
}

function print_bw  {
  printf "[RESULT$4] BW   phase $1 %25s %20.3f GB/s : time %6.2f seconds\n" $phase $2 $3 | tee -a $summary_file
}

function print_iops  {
  printf "[RESULT$4] IOPS phase $1 %25s %20.3f kiops : time %6.2f seconds\n" $phase $2 $3 | tee -a $summary_file
}

function startphase {
  echo ""
  echo "[Starting] $phase"
  start=`date +%s.%N`
}

function endphase_check  {
  r=$?
  local op="$1"

  if [[ "$r" != "0" ]] ; then
     echo "Error: the benchmark returned $r"
     exit 1
  fi
  end=$(date +%s.%N)
  duration=$(printf "%.4f" $(echo "$end - $start" | bc))

  if [[  "$op" == "write" && $(printf "%.0f" $duration) -lt 300 ]] ; then
    local var="$2"

    echo "[Warning] This cannot be an official IO-500 score. The phase runtime of ${duration}s is below 300s."
    echo "[Warning] Suggest $var=$(echo "${!var} * 320 / $duration" | bc)"
    io500_invalid="-invalid"
    invalid="-invalid"
  else
    invalid=""
  fi
}

main
