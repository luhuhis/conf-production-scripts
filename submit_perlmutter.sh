#!/bin/bash

# File to run RHMC on perlmutter

#Nt=32
Nt=56

#streams=("a" "b" "c" "d")  # Nt32
streams=("b" "c")  # Nt56

#nodes=3  # Nt32
nodes=4  # Nt56

#Nodes="1 3 4 1"  # Nt32
Nodes="1 4 4 1"  # Nt56

#seeds=(15619 98789 87918 27180 )  # Nt32
seeds=(51070 58544)  # Nt56

for idx in "${!streams[@]}" ; do
./run_RHMC.sh \
--module_load cudatoolkit/11.5 craype-accel-nvidia80 PrgEnv-gnu gcc/10.3.0 \
--output_base_path /pscratch/sd/l/laltenko/conf \
--executable_dir /global/homes/l/laltenko/code/SIMULATeQCD/build_gnu/applications \
--conftype l96${Nt}f21b8249m002022m01011 \
--stream_id ${streams[idx]} \
--Lattice 96 96 96 ${Nt} \
--Nodes $Nodes \
--beta 8.249 --mass_s 0.01011 --mass_ud 0.002022 \
--rat_file /pscratch/sd/l/laltenko/conf/in.rational_n96b8249m002022m01011 \
--seed ${seeds[idx]} \
--jobname RHMC_96${Nt}${streams[idx]} --mail_user laltenkor@bnl.gov \
--time 06:00:00 --nodes $nodes --gpuspernode 4 --array "0-100%1" \
--account m3760_g --qos regular --constrain gpu \
--custom_cmds "export MPICH_GPU_SUPPORT_ENABLED=1;"
done

