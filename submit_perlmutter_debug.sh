#!/bin/bash

# File to run RHMC on perlmutter

Nts=(36 56)
nodes=(3 6)
Nodes=("1 3 4 1" "1 4 6 1")
no_updates=(100 100)
streams=("streams36" "streams56")
seeds=("seeds36" "seeds56")

streams36=("a" "b" "c" "d")
streams56=("b" "c")
seeds36=(15619 98789 87918 27180 )
seeds56=(51070 58544)


for idx in "${!Nts[@]}"; do
    this_streams="${streams[idx]}"
    this_seeds="${seeds[idx]}"
    declare -n this_streams this_seeds  # convert these variables to a reference of the variables their value names
    for idy in "${!this_streams[@]}" ; do
./run_RHMC.sh \
--CheckConf_path ~/code/SIMULATeQCD/build_gnu/applications/CheckConf \
--CheckRand_path ~/code/SIMULATeQCD/build_gnu/applications/CheckRand \
--module_load cudatoolkit/11.5 craype-accel-nvidia80 PrgEnv-gnu gcc/10.3.0 \
--output_base_path /pscratch/sd/l/laltenko/conf \
--executable_dir /global/homes/l/laltenko/code/SIMULATeQCD/build_gnu/applications \
--n_sim_steps 1 \
--conftype l96${Nts[idx]}f21b8249m002022m01011 \
--stream_id ${this_streams[idy]} \
--Lattice "96 96 96 ${Nts[idx]}" \
--Nodes "${Nodes[idx]}" \
--beta 8.249 --mass_s 0.01011 --mass_ud 0.002022 \
--rat_file /pscratch/sd/l/laltenko/conf/in.rational_n96b8249m002022m01011 \
--rand_file auto \
--rand_flag 1 \
--load_conf 2 --write_every 1 \
--conf_nr auto \
--seed ${this_seeds[idy]} \
--jobname RHMC_96${Nts[idx]}${this_streams[idy]} --mail_user laltenkor@bnl.gov \
--time 02:00:00 --nodes ${nodes[idx]} --gpuspernode 4 --array "0-0%1" \
--account m3760_g --qos debug --sbatch_custom "constraint gpu" \
--custom_cmds "export MPICH_GPU_SUPPORT_ENABLED=1;" \
--no_updates ${no_updates[idx]} \
--save_jobscript jobscript_${Nts[idx]}_${this_streams[idy]}.sh
    done
    # unset the variable references
    unset -n this_streams
    unset -n this_seeds
done

