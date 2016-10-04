#! /bin/bash

# This script launches tests one after another.

# On error, exit from this script.
set -e 

bsmcl run infra
bsmcl run intercon
bsmcl run sram_ic202
bsmcl run sram_ic203
bsmcl run osc
bsmcl run LED_D401

exit

