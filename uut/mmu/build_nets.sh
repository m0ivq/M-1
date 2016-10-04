#! /bin/bash

set -e
if [ ! -e tmp ] 
	then
		mkdir tmp
fi

if [ ! -e bak ] 
	then
		mkdir bak
fi

# initialize databases
cp mmu_seed.txt mmu_default.udb
cp mmu_seed.txt mmu_sram_ic202.udb
cp mmu_seed.txt mmu_sram_ic203.udb
cp mmu_seed.txt mmu_osc.udb

# import BSDL models
bsmcl import_bsdl mmu_default.udb
bsmcl import_bsdl mmu_sram_ic202.udb
bsmcl import_bsdl mmu_sram_ic203.udb
bsmcl import_bsdl mmu_osc.udb

# make boundary scan nets from skeleton.txt
bsmcl mknets mmu_default.udb
bsmcl mknets mmu_sram_ic202.udb
bsmcl mknets mmu_sram_ic203.udb
bsmcl mknets mmu_osc.udb

echo "PASSED" > tmp/test_result.tmp
exit
