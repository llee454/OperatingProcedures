fileName=$1
gawk --bignum -f ~/OperatingProcedures/old_summarize_trace.awk ../RiscvSpecFormal-master-031920/haskelldump/$fileName.out > $fileName.model && gawk --bignum -f ~/OperatingProcedures/summarize_trace.awk haskelldump/$fileName.out > $fileName.out && cat -n $fileName.model > $fileName-num.model && cat -n $fileName.out > $fileName-num.out && vimdiff $fileName-num.model $fileName-num.out
