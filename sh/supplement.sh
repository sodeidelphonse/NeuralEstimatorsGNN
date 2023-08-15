#!/bin/bash

set -e

echo "Do you wish to use a very low number of parameter configurations and epochs to quickly establish that the code is working? (y/n)"
read quick_str

if [[ $quick_str == "y" ||  $quick_str == "Y" ]]; then
    quick=--quick
elif [[ $quick_str == "n" ||  $quick_str == "N" ]]; then
    quick=""
else
    echo "Please re-run and type y or n"
    exit 1
fi

echo ""
echo "##### Starting supplementary experiments #####"
echo ""

julia --threads=auto --project=. src/supplement/graphstructures.jl $quick
Rscript src/supplement/graphstructures.R --model=$model

julia --threads=auto --project=. src/supplement/variablesamplesize.jl $quick
Rscript src/supplement/variablesamplesize.R --model=$model