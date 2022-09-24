#=============================================
# vep2regeniee.sh
# Script that transforms VEP output files 
# to Regenie input files, using linux AWK
# v1 18/9/2022 Alexandra Rizou
# v2 20/9/2022 Alexandra Rizou
# ============================================

#!bin/bash
# #$ -cwd
#$ -j y
#$ -pe smp 1
#$ -l h_rt=1:0:0
#$ -l h_vmem=1G

# Setup the Log Mechanism
#======================
# Initialize the logger script and add first entry
source ./vep2regenie_logger.sh
SCRIPTENTRY
echo "STARTING, please check vep2regenie.log for details"

# Function that writes details of files created using awk
# Implemented as a function to avoid repeating complex code
writeFileDetails(){
	DEBUG "Number of lines in $1 = `wc $1 | awk '{print $1}'`"
	DEBUG "Line sample of $1 = `head -1 $1`"
}

# Step #1: Keep useful columns and format variant column: 
# =======================================================
# Process the output file from VEP, to keep three columns only:  
# the column ($1) which has the uploaded variant,
# the column ($6) with the gene name and
# the column ($4) with the consequence, missense or PTVs. 
# Also substitute in the column of the uploaded variant ($1):
# "_"  with ":" and "/" with ":".
# Output line example:
# 1:2228774:C:T SKI missense_variant
INFO "Running Step #1: Keeping Useful Columns..."
awk '{gsub(/_/, ":", $1)} {gsub(/\//, ":", $1)} {print $1, $6, $4}' VEP_input.txt > vep2regenie_step1.tmp
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "VEP_input.txt"
	writeFileDetails "vep2regenie_step1.tmp"
else
	echo FAIL
	DEBUG "FAIL, exiting"
	SCRIPTEXIT
	exit
fi

# Info-only: Identify labels
#============================================
# This code uses awk to identify the labels, and also counts 
# how many lines exist per label.
# It uses the 3rd column from the previous tmp file.
# For the time being this is not a step in the pipeline,
# it only provides useful info for manual comparison. 
# Output is STDOUT 
# Output line example:
# splice_donor_variant 22360
DEBUG "Identifying labels and occurrences... `awk '{A[$3]++}END{for(i in A)print "label " i, "has " A[i] " entries, "}' vep2regenie_step1.tmp`"

# Step #2: Replace labels with MISSENSE, PTV
#===========================================
# We need only the information about PTVs and MISSENSE, therefore 
# - we replace all non missense labels with PTV. 
# - we replace the "missense_variant" label with "MISSENSE"
# Automatic comparison with identified labels is not yet implemented.
# Output is file vep2regenie_step2.tmp
# As example, for the below input lines:
# 1:2228774:C:T SKI missense_variant
# 1:2228774:C:T SKI splice_donor_variant
# 1:2228774:C:T SKI stop_gained
# here are the output lines
# 1:2228774:C:T SKI MISSENSE
# 1:2228774:C:T SKI PTV
# 1:2228774:C:T SKI PTV
INFO "Running Step #2: Replacing labels with PTV and MISSENSE..."
awk '{gsub(/stop_lost/, "PTV", $3)} {gsub(/start_lost/, "PTV", $3)} {gsub(/stop_gained/, "PTV", $3)} {gsub(/frameshift_variant/, "PTV", $3)} {gsub(/missense_variant/, "MISSENSE", $3)} {gsub(/splice_acceptor_variant/, "PTV", $3)} {gsub(/splice_donor_variant/, "PTV", $3)} {print $1, $2, $3}' vep2regenie_step1.tmp > vep2regenie_step2.tmp 
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "vep2regenie_step2.tmp"
else
	echo FAIL
	DEBUG "FAIL, exiting"
	SCRIPTEXIT
	exit
fi

# Step #3: Remove Duplicate lines (in place, no sort)
#====================================================
# As we do not want the labels to appear many times,
# we remove duplicate lines. This step also reduces 
# the number of lines to process in the following steps.
# We use awk to delete duplicate lines in place, without sorting.
# This method is more secure to use versus sort or uniq commands,
# as it does not require the file to be sorted.
# Output is vep2regenie_step3.tmp
# As example, for the following input lines:
# 1:2228774:C:T SKI MISSENSE
# 1:2228774:C:T SKI PTV
# 1:2228774:C:T SKI PTV
# here are the output lines (one line is deleted)
# 1:2228774:C:T SKI MISSENSE
# 1:2228774:C:T SKI PTV
INFO "Running Step #3: Deleting duplicate lines in place..."
awk '!seen[$0]++' vep2regenie_step2.tmp  > vep2regenie_step3.tmp
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "vep2regenie_step3.tmp"
else
	echo FAIL
	DEBUG "FAIL, exiting"
	SCRIPTEXIT
	exit
fi

# Step #4: Create annotation file with only MISSENSE labels 
#===========================================================
# We need annotation files separately for MISSENSE and PTV labels
# we therefore use grep to create  a missense only annotation file
# we also display the file’s number of lines
# Output is vep2regenie_MISSENSE.annotations
INFO "Running Step #4: Creating MISSENSE-only Annotations File..."
grep "MISSENSE" vep2regenie_step3.tmp > vep2regenie_MISSENSE.annotations
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "vep2regenie_MISSENSE.annotations"
else
	echo FAIL
	DEBUG "FAIL, continuing anyway"
fi

# Step #5: Create annotation file with only PTV labels
# We need annotation files separately for MISSENSE and PTV labels
# we therefore use grep to create  a missense only annotation file
# we also display the file’s number of lines
# Output is vep2regenie_PTV.annotations
INFO "Running Step #5: Creating PTV-only annotations file..."
grep "PTV" vep2regenie_step3.tmp > vep2regenie_PTV.annotations
if [ $? -eq 0 ]; then
	echo "OK"
	writeFileDetails "vep2regenie_PTV.annotations"
else
	echo FAIL
	DEBUG "FAIL, continuing anyway "
fi 

# Step #6: Merge PTV and MISSENSE labels, replacing multiple lines
#================================================================
# We start with vep2regenie_step3.tmp
# - we replace multiple lines of same gene and variant
#   but different labels 
# - with a single line that uses a merged label.
# Output is vep2regenie_step6.tmp
# As example, for the below input lines:
# 10:13500069:T:A BEND7 MISSENSE
# 10:13500069:T:A BEND7 PTV
#10:13500070:T:A BEND7 PTV
# 10:13500070:T:A BEND7 MISSENSE
# We get the following output lines:
# 10:13500069:T:A BEND7 MISSENSEPTV
# 10:13500069:T:A BEND7 PTVMISSENSE
INFO "Running Step #6: Merging PTV and MISSENSE labels for same variants..."
awk 'gene==$2 && variant==$1 {printf("%s", $3); next} {variant=$1;gene=$2; printf("%s", o$1FS$2FS$3)} NR==1 {o=ORS} END {print}' vep2regenie_step3.tmp > vep2regenie_COMBINED.annotations
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "vep2regenie_step3.tmp"
	DEBUG "subtract number of lines to find how many pairs have been combined"
	writeFileDetails "vep2regenie_COMBINED.annotations"
else
	echo FAIL
	DEBUG "FAIL, continuing anyway"
fi

# Step 7: Create a file with only "COMBINED" labels
#==================================================
# We now replace the two merged labels "MISSENSEPTV" and "PTVMISSENSE"
# with a single "COMBINED" label. We export to a file all files lines
INFO "Running Step #7: Replacing merged labels with COMBINED..."
sed -i -e 's/MISSENSEPTV/COMBINED/g' -e 's/PTVMISSENSE/COMBINED/g' vep2regenie_COMBINED.annotations
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "vep2regenie_COMBINED.annotations"
else
	echo FAIL
	ERROR "FAIL, continuing anyway"
fi

# Step 8: Create MISSENSE setlist file - multiple lines per variant
#=================================================
# Use the MISSENSE annotations file to create a set file formatted file
# To do so, instruct awk to use two delimiters ":" and space " "
# giving the parameter -F '[: ]' that is using a regular expression. 
# The result has multiple lines per gene, that need to me merged (at next step)
# As example, the following input line:
# 1:2228774:C:T SKI MISSENSE
# is transformed to the following output line:
# SKI 1 2228774 1:2228774:C:T
INFO "Running Step #8: Preparing MISSENSE setlist file..."
awk -F'[: ]' '{print $5, $1, $2, $1":"$2":"$3":"ls$4}' vep2regenie_MISSENSE.annotations > vep2regenie_step8.tmp
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "vep2regenie_step8.tmp"
else
	echo FAIL
	DEBUG "FAIL, continuing anyway"
fi

# Step 9: Sort the MISSENSE setfile
#====================================
# The final setfile needs to be sorted per gene, otherwise the concatenation will fail
INFO "Running Step #9: Sorting MISSENSE setfile..."
sort -k1 vep2regenie_step8.tmp > vep2regenie_step9.tmp
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "vep2regenie_step9.tmp"
else
	echo FAIL
	DEBUG "FAIL, continuing anyway"
fi

# Step 10: Merge lines of MISSENSE set list file per gene 
#========================================================
# Apply a complex awk command to create the final set file for MISSENSE. 
# This awk command scans every line of the file: 
# - the first time it encounters a gene it writes all columns, 
# - then for every consequent line of the same gene, 
# appends the variant at the end of the same line.
# As example from this type of line:
# ADARB2 10 1242152 10:1242152:G:A
# The output line will be (after merging three lines)
# ADARB2 10 1242152 10:1242152:G:A,10:1242156:A:G,10:1242165:G:T
INFO "Running Step #10: Merging MISSENSE setlist lines per gene..."
awk 'gene==$1 {printf("%s", ","$4); next} {gene=$1; printf("%s", o$1FS$2FS$3FS$4)} NR==1 {o=ORS} END {print}' vep2regenie_step9.tmp > vep2regenie_MISSENSE.setlist
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "vep2regenie_MISSENSE.setlist"
else
	echo FAIL
	DEBUG "FAIL, continuing anyway"
fi

# Step 11: Create PTV setlist file - multiple lines per variant
#=================================================
# Use the PTV annotations file to create a set file formatted file
# To do so, instruct awk to use two delimiters ":" and space " "
# giving the parameter -F '[: ]' that is using a regular expression. 
# The result has multiple lines per gene, that need to me merged (at next step)
# As example, the following input line:
# 1:2228774:C:T SKI PTV
# is transformed to the following output line:
# SKI 1 2228774 1:2228774:C:T
INFO "Running Step #11: Preparing the PTV setfile..."
awk -F'[: ]' '{print $5, $1, $2, $1":"$2":"$3":"ls$4}' vep2regenie_PTV.annotations > vep2regenie_step11.tmp
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "vep2regenie_step11.tmp"
else
	echo FAIL
	DEBUG "FAIL, continuing anyway"
fi

# Step 12: Sort the PTV setfile
#====================================
# The final setfile needs to be sorted per gene, otherwise the concatenation will fail
INFO "Running step #12: Sorting the PTV setfile..."
sort -k1 vep2regenie_step11.tmp > vep2regenie_step12.tmp
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "vep2regenie_step12.tmp"
else
	echo FAIL
	DEBUG "FAIL, continuing anyway"
fi

# Step 13: Merge lines of PTV set list file per gene 
#========================================================
# Apply a complex awk command to create the final set file for PTV. 
# This awk command scans every line of the file: 
# - the first time it encounters a gene it writes all columns, 
# - then for every consequent line of the same gene, 
# appends the variant at the end of the same line.
# As example from this type of line:
# ADARB2 10 1242152 10:1242152:G:A
# The output line will be (after merging three lines)
# ADARB2 10 1242152 10:1242152:G:A,10:1242156:A:G,10:1242165:G:T
INFO "Running step #13: Merging PTV lines per gene..."
awk 'gene==$1 {printf("%s", ","$4); next} {gene=$1; printf("%s", o$1FS$2FS$3FS$4)} NR==1 {o=ORS} END {print}' vep2regenie_step12.tmp > vep2regenie_PTV.setlist
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "vep2regenie_PTV.setlist"
else
	echo FAIL
	DEBUG "FAIL"
fi

# Step 14: Create COMBINED set list file - multiple lines per variant
#=================================================
# Use the COMBINED annotations file to create a set file formatted file
# To do so, instruct awk to use two delimiters ":" and space " "
# giving the parameter -F '[: ]' that is using a regular expression. 
# The result has multiple lines per gene, that need to me merged (at next step)
# As example, the following input line:
# 1:2228774:C:T SKI COMBINED
# is transformed to the following output line:
# SKI 1 2228774 1:2228774:C:T
INFO "Running Step #14: Preparing COMBINED setlist file..."
awk -F'[: ]' '{print $5, $1, $2, $1":"$2":"$3":"ls$4}' vep2regenie_COMBINED.annotations > vep2regenie_step14.tmp
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails  "vep2regenie_step14.tmp"
else
	echo FAIL
	DEBUG "FAIL"
fi

# Step 15: Sort the COMBINED setfile
#====================================
# The final setfile needs to be sorted per gene, otherwise the concatenation will fail
INFO "Running Step #15: Sorting the COMBINED setlist..."
sort -k1 vep2regenie_step14.tmp > vep2regenie_step15.tmp
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "vep2regenie_step15.tmp"
else
	echo FAIL
	DEBUG "FAIL, continuing anyway"
fi

# Step 16: Merge lines of COMBINED set list file per gene 
#========================================================
# Apply a complex awk command to create the final set file for COMBINED. 
# This awk command scans every line of the file: 
# - the first time it encounters a gene it writes all columns, 
# - then for every consequent line of the same gene, 
# appends the variant at the end of the same line.
# As example from this type of line:
# ADARB2 10 1242152 10:1242152:G:A
# The output line will be (after merging three lines)
# ADARB2 10 1242152 10:1242152:G:A,10:1242156:A:G,10:1242165:G:T
INFO "Running Step #16: Merging lines of COMBINED setlist..."
awk 'gene==$1 {printf("%s", ","$4); next} {gene=$1; printf("%s", o$1FS$2FS$3FS$4)} NR==1 {o=ORS} END {print}' vep2regenie_step15.tmp > vep2regenie_COMBINED.setlist
if [ $? -eq 0 ]; then
	echo OK
	writeFileDetails "vep2regenie_COMBINED.setlist"
else
	echo FAIL
	DEBUG "FAIL"
fi
SCRIPTEXIT
