# Accepts one argument: issue, an issue number string; clones
# the current version of the RiscvSpecFormal repo into an
# appropriately named directory; and compiles the code.
function createWorkingCopy () {
  branch=$1;
  datestamp=$(date +%m%d%y);
  git clone git@github.com:sifive/RiscvSpecFormal.git "RiscvSpecFormal-$branch-$datestamp";
  cd "RiscvSpecFormal-$branch-$datestamp";
  git submodule update --init;
  git submodule update --remote;
  cd ProcKami;
  git checkout $branch;
  cd ..;
  ln --symbolic /nettmp/netapp1a/vmurali/riscv-tests/isa riscv-tests;
  ./doGenerate.sh --haskell --parallel;
};

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
  git merge master;
  echo "Notice: Now run the test process";
}

# Run after initTest
# Runs the RISC-V test suite tests.
function runTestProcess {
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
    then git request-pull;
  fi;
  echo "Notice: Done";
}
