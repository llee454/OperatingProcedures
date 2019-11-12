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
  exit 1
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

# Usage: createWorkingCopy BRANCH [Y]
# Accepts one argument: issue, an issue number string; clones
# the current version of the RiscvSpecFormal repo into an
# appropriately named directory; and compiles the code.
function createWorkingCopy {
  branch=$1;
  compile=$2;
  datestamp=$(date +%m%d%y);
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
  issueNumber=$1;
  suffix=$2;
  datestamp=$(date +%m%d%y);
  branchName="merge-issue$issueNumber-$datestamp""$suffix"
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
  ./runAll.sh;
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

# Usage: compareVerilogHaskell TESTNAME (32|64)
# Accepts two arguments: testName, the test name; and xlen, either
# "32" or "64"; executes the test in both the Haskell Simulator and
# the Verilog simulator; and displays the traces in vimdiff.
function compareVerilogHaskell {
  testName=$1
  xlen=$2
  ./doGenerate.sh --haskell --parallel;
  ./runElf.sh --debug --haskell --path /nettmp/netapp1a/vmurali/riscv-tests/isa/$testName --xlen $xlen;
  ./doGenerate.sh --parallel --xlen $xlen;
  ./runElf.sh --debug --path /nettmp/netapp1a/vmurali/riscv-tests/isa/$testName --xlen $xlen;
  vimdiff haskelldump/$testName.out verilogdump/$testName.out;
}

# Usage: generateVerilogHeapDump &> LOGFILE & [; disown $!]
# Accepts no arguments; compiles the verilog generator, CompAction,
# with profiling support; runs the Verilog generator and saves the
# resulting heap profile to a file.
function generateVerilogHeapDump {
  datestamp=$(date +%m%d%y);
  make -j;
  cd Kami && ./fixHaskell.sh ../HaskellGen .. && cd ..
  model=model64
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
