#!/bin/bash
# File to run RHMC on jlab 21g

Ns=64
Nts=(20 20 24 22)
betas=(7570 7704 8068 8147)  # divide by 1,000
mass_strange=(1973 1723 1204 1115)  # divide by 100,000
mass_light=(3946 3446 2408 2230)  # divide by 1,000,000

# streams a b c d
#seeds_7570=(642309 856827 382011 210878 250085 856365)
#seeds_7704=(892577 758420 985615 131065 250681 787255)
#seeds_8068=(768096 613374 358356 524410 160208 688581)
#seeds_8147=(954979 629458 789310 251736 153323 653614)
#seeds_names=("seeds_7570" "seeds_7704" "seeds_8068" "seeds_8147")

rat_path="/volatile/thermo/laltenko/conf/rat_approx/"
rat_files=("rat.out_ml003946ms019730Nfl2Nfs1Npf1" "rat.out_ml003446ms017230Nfl2Nfs1Npf1" "rat.out_ml002408ms012040Nfl2Nfs1Npf1" "rat.out_ml002230ms011150Nfl2Nfs1Npf1")

visible_dev=(0 1 2 3 4 5 6 7)

joblabels=("12" "34" "56")

# arrange labels in the correct format for the run script.

for ((j=0; j<3; j++)) ; do
conftypes=()
streams=()
Lattice=()
beta=()
mass_ud=()
mass_s=()
#seeds=()
rat_file=()
custom_cmds=()
counter=0
for idx in "${!Nts[@]}"; do
	if [ $j -eq 0 ] ; then
    	streams+=("_1")
	    streams+=("_2")
	elif [ $j -eq 1 ] ; then
	    streams+=("_3")
	    streams+=("_4")
	elif [ $j -eq 2 ] ; then
		streams+=("_5")
		streams+=("_6")
	fi

 #   this_seeds="${seeds_names[idx]}"
  #  declare -n this_seeds

    i_low=$((j*2))
    i_high=$((j*2+2))
    for ((i=$i_low; i<$i_high; i++)); do
        conftypes+=("l$Ns${Nts[idx]}f21b${betas[idx]}m00${mass_light[idx]}m0${mass_strange[idx]}")
        Lattice+=("\"$Ns $Ns $Ns ${Nts[idx]}\"")
        beta+=("$(echo "scale=3; ${betas[idx]}/1000" | bc -l)")
        mass_s+=("0$(echo "scale=5; ${mass_strange[idx]}/100000" | bc -l)")
        mass_ud+=("0$(echo "scale=6; ${mass_light[idx]}/1000000" | bc -l)")
#        seeds+=("${this_seeds[i]}")
        rat_file+=("${rat_path}${rat_files[idx]}")	
		custom_cmds+=("\"unset CUDA_VISIBLE_DEVICES; export ROCR_VISIBLE_DEVICES=${visible_dev[counter]}\"")
		counter=$((counter+1))
    done

    unset -n this_seeds
done

script_call=$(cat <<DELIM
./create_RHMC_job.sh \
--CheckConf_path ~/code_build/SIMULATeQCD/build_new/applications/CheckConf \
--CheckRand_path ~/code_build/SIMULATeQCD/build_new/applications/CheckRand \
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
--seed 0 --rand_file auto \
--jobname RHMC_${Ns}Nt_${joblabels[j]} --mail_user laltenkor@bnl.gov \
--time 48:00:00 --nodes 1 --gpuspernode 8 \
--account thermo21g --partition 21g --qos normal \
--conf_nr auto \
--custom_cmds ${custom_cmds[@]} \
--no_updates 1000 \
--rand_flag 1 \
--always_acc 0 \
--write_every 1 --load_conf 2 \
--no_md 20 20 20 20 20 20 20 20 \
--step_size 0.05 \
--array 0-99%1 \
--replace_srun " " \
--save_jobscript jobscript_21g.sh
DELIM
)

echo "$script_call"

echo -n "Continue y/n? "
read -r input
if [ "$input" == "y" ]; then
    eval $script_call
else
	echo "Did not submit script"
fi

done
