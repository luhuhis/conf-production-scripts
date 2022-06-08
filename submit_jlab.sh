#!/bin/bash

# File to run RHMC on jlab 21g

Ns=64
Nts=(20 20 24 22)
betas=(7570 7704 8068 8147)  # divide by 1,000
mass_s=(1973 1723 1204 1115)  # divide by 100,000
mass_ud=(3946 3446 2408 2230)  # divide by 1,000,000

nodes=1
Nodes=("1 1 1 1")
no_updates=5

streams=(a ) #b c d) # b c d

seeds=("seeds_7570" "seeds_7704" "seeds_8068" "seeds_8147") #  "seeds_b" "seeds_c" "seeds_d")
seeds_7570=(642309 856827 382011 210878)
seeds_7704=(892577 758420 985615 131065)
seeds_8068=(768096 613374 358356 524410)
seeds_8147=(954979 629458 789310 251736)

rat_path="/volatile/thermo/laltenko/conf/rat_approx/"
rat_files=("rat.out_ml003946ms019730Nfl2Nfs1Npf1" "rat.out_ml003446ms017230Nfl2Nfs1Npf1" "rat.out_ml002408ms012040Nfl2Nfs1Npf1" "rat.out_ml002230ms011150Nfl2Nfs1Npf1")


for idx in "${!Nts[@]}"; do
    this_seeds="${seeds[idx]}"
    declare -n this_seeds
    for idy in "${!streams[@]}" ; do
./run_RHMC.sh \
--module_load rocm/5.1.3 mpi/openmpi-x86_64 \
--output_base_path /volatile/thermo/laltenko/conf \
--executable_dir /home/laltenko/code_build/SIMULATeQCD/build/applications \
--conftype l$Ns${Nts[idx]}f21b${betas[idx]}m00${mass_ud[idx]}m0${mass_s[idx]} \
--stream_id ${streams[idy]} \
--Lattice $Ns $Ns $Ns ${Nts[idx]} \
--Nodes ${Nodes} \
--beta $(echo "scale=3; ${betas[idx]}/1000" | bc -l) --mass_s 0$(echo "scale=5; ${mass_s[idx]}/100000" | bc -l) --mass_ud $(echo "scale=6; ${mass_ud[idx]}/1000000" | bc -l) \
--rat_file $rat_path${rat_files[idx]} \
--seed ${this_seeds[idy]} \
--jobname RHMC_$Ns${Nts[idx]}${streams[idy]} --mail_user laltenkor@bnl.gov \
--time 00:30:00 --nodes ${nodes} --gpuspernode 8 \
--account thermo21g --partition 21g --qos debug \
--custom_cmds "" \
--no_updates ${no_updates} \
--rand_flag 0 
    done
    unset -n this_seeds
done

