# vep2regenie
The purpose of vep2regenie is to clean, transform and prepare VEP output data to be used as input in REGENIE.

Before using a VEP output file as input to REGENIE, we must ensure that the file contains only the correct columns and in the correct order, but also that there are no missing values, errors, inconsistencies, or weird characters in the data. 

vep2regenie is a bash script that is able to scrub, or clean the data in VEP output files using very fast and efficient linux command line tools, such as awk, sed, grep. It uses a 16 step "automated process", that performs:
- Extraction of certain columns -  to match REGENIE requirements
- Extraction of words - to identify annotation labels in VEP output
- Replacement of values  - to create combined annotation labels
- Removal of duplicates - to avoid REGENIE miscalculations 
- Filtering of lines - to create annotation and setlist input files for MISSENSE and PTVs
 
As much effort goes into scrubbing the VEP data before an analysis can be made with REGENIE, the vep2regenie is a tool that can be used by any bioinformatics researcher to speed-up the process.
Future revisions of vep2regenie will introduce more features.
