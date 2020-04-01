# This script generates a trace using Spike and the processor
# model and compares them to determine at which address the two
# traces differ.
source common.sh

options=$(getopt --options="hx:" --longoptions="help,xlen:" -- "$@")
[ $? == 0 ] || error "Invalid command line. The command line includes one or more invalid command line parameters."

eval set -- "$options"
while true
do
  case "$1" in
    -h | --help)
      cat <<- EOF
Usage: ./compare_trace.sh [OPTIONS] SIM1 SIM2 FILENAME

Accepts three arguments: SIM1 and SIM2, two simulator names (either
'spike', 'forvis', 'haskell-sim', or 'coq-sim'); and FILENAME,
the name of a RISCV test; and displays a diff of the summaries of
the traces produced by SIM1 and SIM2.

If SIMN is 'spike' or 'forvis', this script will run the selected
simulator to generate the trace.

Options:
  -h|--help
  Displays this message.

Example
  ./compare_trace.sh spike haskell-sim rv32ui-p-and

Runs riscv-tests/rv32ui-p-and in Spike under RV32 and compares
Spike's trace with that in haskelldump/rv32ui-p-and.

Note:
  When Comparing against a forvis trace forvis must be run with
  its --verbosity flag set to 1.

Authors
  * Larry Lee <llee454@gmail.com> 
EOF
      exit 0;;
    -x|--xlen)
      xlen=$2
      shift 2;;
    --)
      shift
      break;;
  esac
done
shift $((OPTIND - 1))

sim1=$1
sim2=$2
filename=$3

[[ -z $sim1 ]] && error "Invalid command line. The SIM1 argument is missing."
[[ -z $sim2 ]] && error "Invalid command line. The SIM2 argument is missing."
[[ -z $filename ]] && error "Invalid command line. The FILENAME argument is missing."

function awkScript () {
  local sim=$1
  local path='/home/larryl/OperatingProcedures/compare_trace'
  [[ $sim == 'spike'       ]] && echo "$path/summarize_trace_spike.awk"
  [[ $sim == 'forvis'      ]] && echo "$path/summarize_trace_forvis.awk"
  [[ $sim == 'haskell-sim' ]] && echo "$path/summarize_trace.awk"
  [[ $sim == 'coq-sim'     ]] && echo "$path/summarize_trace.awk"
}

function traceFilename () {
  local sim=$1
  [[ $sim == 'spike'       ]] && echo "$filename-spike.trace"
  [[ $sim == 'forvis'      ]] && echo "$filename-forvis.trace"
  [[ $sim == 'haskell-sim' ]] && echo "haskelldump/$filename.out"
  [[ $sim == 'coq-sim'     ]] && echo "coqdump/$filename.out"
}

function getTestXlen () {
  local fileName=$1
  echo ${fileName:2:2}
}

function generateTrace () {
  local sim=$1
  echo $sim
  [[ $sim == 'spike'       ]] && echo 'running spike.' && /scratch/larryl/srcs/riscv-tools/riscv-isa-sim/spike -l --isa="RV$(getTestXlen $filename)IMAFDC" /nettmp/netapp1a/vmurali/riscv-tests/isa/$filename &> $(traceFilename $sim)
  [[ $sim == 'forvis'      ]] && echo 'ERROR: CANNOT GENERATE FORVIS'
  # [[ $sim == 'haskell-sim' ]] && true
  # [[ $sim == 'coq-sim'     ]] && true
  true
}

function summaryFilename () {
  local sim=$1
  echo $filename-$sim.summary
}

function summarizeTrace () {
  local sim=$1
  gawk -f $(awkScript $sim) $(traceFilename $sim) > $(summaryFilename $sim)
}

generateTrace $sim1 \
  && generateTrace $sim2 \
  && echo 'generated trace files.' \
  && summarizeTrace $sim1 \
  && echo 'summarized first trace.' \
  && summarizeTrace $sim2 \
  && echo 'summarized second trace.' \
  && vimdiff $(summaryFilename $sim1) $(summaryFilename $sim2)
