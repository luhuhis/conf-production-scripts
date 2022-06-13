#!/bin/bash
# File to run RHMC on jlab 21g

Ns=64
Nts=(20 20 24 22)
betas=(7570 7704 8068 8147)  # divide by 1,000
mass_strange=(1973 1723 1204 1115)  # divide by 100,000
mass_light=(3946 3446 2408 2230)  # divide by 1,000,000

# streams a b c d
seeds_7570=(642309 856827 382011 210878)
seeds_7704=(892577 758420 985615 131065)
seeds_8068=(768096 613374 358356 524410)
seeds_8147=(954979 629458 789310 251736)
seeds_names=("seeds_7570" "seeds_7704" "seeds_8068" "seeds_8147")

rat_path="/volatile/thermo/laltenko/conf/rat_approx/"
rat_files=("rat.out_ml003946ms019730Nfl2Nfs1Npf1" "rat.out_ml003446ms017230Nfl2Nfs1Npf1" "rat.out_ml002408ms012040Nfl2Nfs1Npf1" "rat.out_ml002230ms011150Nfl2Nfs1Npf1")

visible_dev=(0 1 2 3 4 5 6 7)

# arrange labels in the correct format for the run script.

conftypes=()
streams=()
Lattice=()
beta=()
mass_s=()
seeds=()
rat_file=()
custom_cmds=()
for idx in "${!Nts[@]}"; do
    streams+=(a)
    streams+=(b)

    this_seeds="${seeds_names[idx]}"
    declare -n this_seeds

    for ((i=0; i<2; i++)); do
        conftypes+=("l$Ns${Nts[idx]}f21b${betas[idx]}m00${mass_light[idx]}m0${mass_strange[idx]}")
        Lattice+=("\"$Ns $Ns $Ns ${Nts[idx]}\"")
        beta+=("$(echo "scale=3; ${betas[idx]}/1000" | bc -l)")
        mass_s+=("0$(echo "scale=5; ${mass_strange[idx]}/100000" | bc -l)")
        mass_ud+=("0$(echo "scale=6; ${mass_light[idx]}/1000000" | bc -l)")
        seeds+=("${this_seeds[i]}")
        rat_file+=("${rat_path}${rat_files[idx]}")
	custom_cmds+=("\"unset CUDA_VISIBLE_DEVICES; export ROCR_VISIBLE_DEVICES=${visible_dev[i+idx*2]}\"")
    done

    unset -n this_seeds
done

script_call=$(cat <<DELIM
./run_RHMC.sh \
--module_load mpi/openmpi-x86_64 \
--output_base_path /volatile/thermo/laltenko/conf \
--executable_dir /home/laltenko/code_build/SIMULATeQCD/build/applications \
--n_sim_steps 8 \
--conftype ${conftypes[@]} \
--stream_id ${streams[@]} \
--Lattice ${Lattice[@]} \
--Nodes "1 1 1 1" \
--beta ${beta[@]} --mass_s ${mass_s[@]} --mass_ud ${mass_ud[@]} \
--rat_file ${rat_file[@]} \
--seed ${seeds[@]} --rand_file auto \
--jobname RHMC_${Ns}Nt --mail_user laltenkor@bnl.gov \
--time 24:00:00 --nodes 1 --gpuspernode 8 \
--account thermo21g --partition 21g --qos normal \
--conf_nr auto \
--custom_cmds ${custom_cmds[@]} \
--no_md 1 --no_step_sf 1 --no_sw 1 --step_size 1 \
--no_updates 1 \
--rand_flag 0 \
--always_acc 1 \
--cgMax 1 \
--write_every 1 --load_conf 2 2 2 2 2 2 0 0 \
--no_srun
DELIM
)

echo "$script_call"

echo -n "Continue y/n? "
read -r input
if [ "$input" != "y" ]; then
    exit 0
fi

eval $script_call
