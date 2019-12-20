# This file contains a collection of Bash functions that automate
# common operating procedures performed by me (Larry D. Lee Jr.) at
# SiFive.
#
# Note: you should always maintain a log of the output produced by
# these commands. To do so, you can either use "screen -L COMMAND" or
# "COMMAND &> LOGFILE &" followed by "disown PID" to disassociate it
# from you. If the command accepts user input experiment with using
# the "yes" command in combination.

verbose=0

# Accepts one argument: message, a message
# string; and prints the given message iff the
# verbose flag has been set.
function error {
  local emsg=$1

  echo -e "\033[91mError:\033[0m $emsg" >&2
#  exit 1
}

# Accepts one argument: message, a message
# string; and prints the given message
function notice {
  local msg=$1

  echo -e "\033[92mNotice:\033[0m $msg" >&2
}

# Accepts one argument, $cmd, a bash command
# string, executes the command and returns an
# error message if it fails.
function execute {
  local cmd=$1
  if [[ $verbose == 1 ]]
  then
    echo -e "\033[93mNotice:\033[0m $cmd" >&2
  fi
  eval $cmd
  [ $? == 0 ] || error "An error occured while trying to execute the following command: \"$cmd\"."
}

# Usage: listFunctions
# Accepts no arguments, and prints a list of the functions defined in
# this script.
function listFunctions {
  grep --color --extended 'Usage:' ~/OperatingProcedures/OperatingProcedures.sh
}

# Usage: stringSearch "PATTERN" PATH
# Accepts two arguments: PATTERN, a string; and PATH, a file path;
# and displays every instance of PATTERN in the Coq Vernacular files
# under PATH.
function stringSearch {
  local pattern=$1
  local path=$2
  grep --color --recursive --include '*.v' "$pattern" "$path"
}

# Usage: runInBackground "CMD"
# Accepts two arguments: cmd, a bash command; and logFileName,
# a file name string; and runs cmd in the background while logging
# its output to logFileName. If logFileName is omitted, this function
# will autogenerate a log file and save the output there.
function runInBackground {
  local cmd=$1
  local logFileName=$2
  if [ -z $logFileName ]
  then
    local datestamp=$(date +%m%d%y);
    logFileName=$(mktemp "runInBackground-$datestamp-XXXX")
  fi
  notice "running $cmd in background and logging output to $logFileName"
  eval "{ $cmd; }" &> $logFileName & disown $!
}

# Usage: checkMemUsage
# Prints out the amount of disk space your using and saves a fuller
# report to file named checkMemUsage.out.
function checkMemUsage {
  fileName=$(mktemp "checkMemUsage-XXX.out")
  notice "saving disk usage report to $fileName"
  du --human-readable --total /nettmp/netapp1a/llee | sort --human-numeric-sort > $fileName
  du --human-readable --total /scratch/larryl | sort --human-numeric-sort > $fileName
  notice "The top twenty most expensive files and directories."
  tail --lines 20 $fileName
}

# Usage: createWorkingCopy BRANCH [Y]
# Accepts one argument: issue, an issue number string; clones
# the current version of the RiscvSpecFormal repo into an
# appropriately named directory; and compiles the code.
function createWorkingCopy {
  local branch=$1;
  local compile=$2;
  local datestamp=$(date +%m%d%y);
  git clone git@github.com:sifive/RiscvSpecFormal.git "RiscvSpecFormal-$branch-$datestamp";
  cd "RiscvSpecFormal-$branch-$datestamp";
  git submodule update --init;
  git submodule update --remote;
  git config credential.helper store;
  cd ProcKami;
  git config credential.helper store;
  git checkout $branch;
  cd ..;
  ln --symbolic /nettmp/netapp1a/vmurali/riscv-tests/isa riscv-tests;
  if [[ $compile ]]
  then
    ./doGenerate.sh --haskell --parallel;
  fi
};

# Usage: initTest ISSUE [a,b,...]
# Accepts two arguments: issueNumber, the issue that the current
# directories edits fix; and suffix, a unique suffix such as "a" or
# "b" that distinguishes this branch from others; and create a merge
# branch based on the current directory.
function initTest {
  local issueNumber=$1;
  local suffix=$2;
  local datestamp=$(date +%m%d%y);
  local branchName="merge-issue$issueNumber-$datestamp""$suffix"
  git branch $branchName;
  git checkout master;
  git pull origin master;
  git checkout $branchName;
  git rebase origin/master # https://sifive.slack.com/archives/C9SGWP6BW/p1573166746001300
  echo "Now run the test process";
}

# Usage: screen -L runTestProcess BRANCHNAME
# Run after initTest
# Runs the RISC-V test suite tests.
function runTestProcess {
  branchName=$1
  cp -v /nettmp/netapp1a/vmurali/RiscvSpecFormal/{run32.sh,run32v.sh,run64.sh,run64v.sh,runAll.sh} .;
  read -p "comment out lines related to verilog in runTests";
  rm -v screenlog.0;
  rm -v slurm-*.out;
  read -p "enter cntrl-a cntrl-d after screen starts";
  screen -L ./runAll.sh;
  echo "monitor the tests using 'tail -f screenlog.0'";
  echo "monitor the tests using 'watch squeue -u larryl'";
  read -p "start next step once tests finish";
  ./doGenerate.sh --parallel --xlen 64;
  ./runElf.sh --path /nettmp/netapp1a/vmurali/riscv-tests/isa/rv64ui-p-add --xlen 64;
  ./runElf.sh --path /nettmp/netapp1a/vmurali/riscv-tests/isa/rv64ui-v-add --xlen 64;
  ./doGenerate.sh --parallel --xlen 32;
  ./runElf.sh --path /nettmp/netapp1a/vmurali/riscv-tests/isa/rv32ui-p-add --xlen 32;
  ./runElf.sh --path /nettmp/netapp1a/vmurali/riscv-tests/isa/rv32ui-v-add --xlen 32;
  read -p "Did all of the tests pass (cat slurm-XXX.out)? [Y/N]" submitPR;
  if [[ $submitPR = "Y" ]];
    then
      cd ProcKami;
      git push origin $branchName;
      echo "Submit a PR. WARNING ALWAYS SQUASH MERGE"
  fi;
  echo "Done";
}

# Usage: runRiscvHaskellTests
# Runs the RISC-V test suite in the Haskell Kami Processor simulator
# and stores the resulting trace files in haskelldump.
# Note: you must run doGenerate to generate the Haskell simulator
# before running this command.
function runRiscvHaskellTests {
  rm -f runTests64.out runTests32.out
  runInBackground "time srun --priority=TOP --cpus-per-task=32 --mem=12G ./runTests.sh --haskell --path /nettmp/netapp1a/vmurali/riscv-tests/isa --parallel --skip --xlen 64" "runTests64.out"
  runInBackground "time srun --priority=TOP --cpus-per-task=32 --mem=12G ./runTests.sh --haskell --path /nettmp/netapp1a/vmurali/riscv-tests/isa --parallel --skip --xlen 32" "runTests32.out"
  watch "tail --lines 20 runTests64.out | cut -c-80; echo ===============; tail --lines 20 runTests32.out | cut -c-80"
}

# Usage buildVerilog
function buildVerilog {
  local datestamp=$(date +%m%d%y);
  local logFileName="buildVerilog-$datestamp.out"
  runInBackground "./doGenerate.sh --parallel --xlen 64 && ./doGenerate.sh --parallel --xlen 32" $logFileName
  watch "tail --lines 40 $logFileName | cut -c-80"
}

# Usage: runRiscvVerilogTests
# Runs the RISC-V test suite in the Haskell Kami Processor simulator
# and stores the resulting trace files in verilogdump.
# Note: you must run buildVerilog to generate the Verilog simulator
# before running this command.
function runRiscvVerilogTests {
  local datestamp=$(date +%m%d%y);
  local logFileName64="runVerilogTests64-$datestamp.out"
  local logFileName32="runVerilogTests32-$datestamp.out"
  rm -f $logFileName64 $logFileName32
  runInBackground "time srun --cpus-per-task=32 --mem=12G ./runTests.sh --path /nettmp/netapp1a/vmurali/riscv-tests/isa --parallel --skip --xlen 64" $logFileName64
  runInBackground "time srun --cpus-per-task=32 --mem=12G ./runTests.sh --path /nettmp/netapp1a/vmurali/riscv-tests/isa --parallel --skip --xlen 32" $logFileName32
  watch "tail --lines 20 runTests64.out | cut -c-80; echo ===============; tail --lines 20 runTests32.out | cut -c-80"
}

# Usage: compareVerilogHaskell TESTNAME (32|64)
# Accepts two arguments: testName, the test name; and xlen, either
# "32" or "64"; executes the test in both the Haskell Simulator and
# the Verilog simulator; and displays the traces in vimdiff.
function compareVerilogHaskell {
  local testName=$1
  local xlen=$2
  ./doGenerate.sh --haskell --parallel;
  ./runElf.sh --debug --haskell --path /nettmp/netapp1a/vmurali/riscv-tests/isa/$testName --xlen $xlen;
  ./doGenerate.sh --parallel --xlen $xlen;
  ./runElf.sh --debug --path /nettmp/netapp1a/vmurali/riscv-tests/isa/$testName --xlen $xlen;
  vimdiff haskelldump/$testName.out verilogdump/$testName.out;
}

# Usage: generateVerilogHeapDump
# Accepts no arguments; compiles the verilog generator, CompAction,
# with profiling support; runs the Verilog generator and saves the
# resulting heap profile to a file.
# Note: consider: runInBackgroung generateVerilogHeapDump
function generateVerilogHeapDump {
  local datestamp=$(date +%m%d%y);
  make -j;
  cd Kami && ./fixHaskell.sh ../HaskellGen .. && cd ..
  local model=model64
  cat Haskell/Target.raw > HaskellGen/Target.hs
  echo "rtlMod = separateModRemove $model" >> HaskellGen/Target.hs
  execute "ghc -j -prof -fprof-auto -O1 --make -iHaskellGen -iKami -iKami/Compiler Kami/Compiler/CompAction.hs"
  execute "Kami/Compiler/CompAction +RTS -p -h -RTS > System.sv"
  # Dump stack if exception occurs.
  # execute "ghc -j -prof -fprof-auto -rtsopts -fprof-cafs -O1 --make -iHaskellGen -iKami -iKami/Compiler Kami/Compiler/CompAction.hs"
  # execute "Kami/Compiler/CompAction +RTS -xc -RTS > System.sv"
  cp CompAction.prof "CompAction-$datestamp.prof"
  notice "Done. See CompAction-$datestamp.prof."
}
