#!/bin/bash
# File to run RHMC on jlab phi

rat_path="/volatile/thermo/laltenko/conf/rat_approx/"

betas=(7825 7596 7373 7280)
masses_ud=(082 101 125 142)
masses_s=(164 202 250 284)
rat_files=("in.rat_f21b7825m00082m0164.txt" "in.rat_f21b7596m00101m0202.txt" "in.rat_f21b7373m00125m0250.txt" "in.rat_f21b7280m00142m0284.txt")

Ns=64
Nt7825=(28 26 24 22)
Nt7596=(28 26 24 22 20 18 16)
Nt7373=(24 22 20 18 16)
Nt7280=(22 20 18 16)
Nts=("Nt7825" "Nt7596" "Nt7373" "Nt7280")

stream_ids=(_1 _2 _3)	

echo -e "starting with phi KNL jobs\n"

for idx in ${!Nts[@]} ; do
	beta="$(echo "scale=3; ${betas[idx]}/1000" | bc -l)"
	mass_s="0$(echo "scale=5; ${masses_s[idx]}/10000" | bc -l)"
	mass_ud="0$(echo "scale=6; ${masses_ud[idx]}/100000" | bc -l)"
	rat_file="${rat_path}${rat_files[idx]}"

	beta_str=${betas[idx]}
	mass_ud_str=${masses_ud[idx]}
	mass_s_str=${masses_s[idx]}

	# get Nt**** array from above.
	this_Nts="${Nts[idx]}"
	declare -n this_Nts

	for nt in ${this_Nts[@]} ; do
		conftype="l$Ns${nt}f21b${betas[idx]}m00${masses_ud[idx]}m0${masses_s[idx]}"

		for stream_id in "${stream_ids[@]}" ; do
			if [ ! "$(squeue -u $USER | grep ${conftype}$stream_id)" ] ; then
				script_call=$(cat <<DELIM
./create_RHMC_job.sh \
--code patrick \
--output_base_path /volatile/thermo/laltenko/conf \
--executable_dir /home/laltenko/code_build/patrick/build \
--executable main_rhmc \
--CheckConf_path "srun -u --ntasks-per-node=1 -N 1 ~/code_build/SIMULATeQCD/build_cpu/applications/CheckConf" \
--n_sim_steps 1 \
--conftype $conftype \
--stream_id $stream_id \
--Lattice "$Ns $Ns $Ns $nt" \
--Nodes "1 1 1 1" \
--beta $beta --mass_s $mass_s --mass_ud $mass_ud \
--rat_file $rat_file \
--jobname "RHMC_cpu_${conftype}${stream_id}" --mail_user laltenkor@bnl.gov \
--time 48:00:00 --nodes 1 --gpuspernode 0 \
--account thermop --partition phi --qos regular \
--sbatch_custom "constraint cache,quad,16p --mem=0 --dependency=singleton" \
--conf_nr auto \
--custom_cmds "source /dist/intel/parallel_studio_xe_2020_update1/parallel_studio_xe_2020.4.912/bin/psxevars.sh intel64; source /dist/intel/parallel_studio_xe_2020_update1/compilers_and_libraries_2020.4.304/linux/mpi/intel64/bin/mpivars.sh release_mt ; source /dist/intel/parallel_studio_xe_2020_update1/compilers_and_libraries_2020.4.304/linux/bin/compilervars.sh intel64 ; export I_MPI_EXTRA_FILESYSTEM=on ; export I_MPI_EXTRA_FILESYSTEM_FORCE=lustre ; export I_MPI_PMI_LIBRARY=/usr/lib64/libpmi.so ; export I_MPI_FABRICS=shm:ofi ; export I_MPI_PIN=1; export I_MPI_PIN_DOMAIN=node ; export LD_LIBRARY_PATH=\\\\\\\$LD_LIBRARY_PATH:/dist/gcc/9.3.0/lib64:/dist/gcc/9.3.0/lib ; " \
--no_updates 1000 \
--rand_flag 1 --seed random --rand_file auto \
--always_acc 0 \
--write_every 1 --load_conf 2 \
--step_size 0.1 --no_md 10 --no_step_sf 10 --no_sw 10 \
--replace_srun "srun -u --ntasks-per-node=1 -N 1 " \
--array 0-99%1 \
--save_jobscript jobscript.sh
DELIM
				)

				echo "$script_call"

				echo -n "Continue y/n? "
				read -r input
				if [ "$input" == "y" ]; then
					eval $script_call
				else
					echo "Did not submit job"
				fi
			fi
		done
	done
	unset -n this_Nts
done


# jobs for AMD 21G nodes ========================================================

echo -e "\n Moving on to 21g partition jobs \n"

stream_ids=(_4 _5 _6)

arr_conftype=()
arr_stream=()
arr_Lattice=()
arr_beta=()
arr_mass_ud=()
arr_mass_s=()
arr_rat_file=()
arr_custom_cmds=()

counter=0

# loop over all parameter sets and fill arrays with them
for idx in ${!Nts[@]} ; do
	beta="$(echo "scale=3; ${betas[idx]}/1000" | bc -l)"
	mass_s="0$(echo "scale=5; ${masses_s[idx]}/10000" | bc -l)"
	mass_ud="0$(echo "scale=6; ${masses_ud[idx]}/100000" | bc -l)"
	rat_file="${rat_path}${rat_files[idx]}"

	beta_str=${betas[idx]}
	mass_ud_str=${masses_ud[idx]}
	mass_s_str=${masses_s[idx]}

	# get Nt**** array from above.
	this_Nts="${Nts[idx]}"
	declare -n this_Nts

	for nt in ${this_Nts[@]} ; do
		conftype="l$Ns${nt}f21b${betas[idx]}m00${masses_ud[idx]}m0${masses_s[idx]}"

		for stream_id in "${stream_ids[@]}" ; do
			arr_conftype+=("$conftype")
			arr_stream+=("$stream_id")
			arr_Lattice+=("\"$Ns $Ns $Ns ${nt}\"")
			arr_beta+=("$beta")
			arr_mass_ud+=("$mass_ud")
			arr_mass_s+=("$mass_s")
			arr_rat_file+=("$rat_file")
			arr_custom_cmds+=("\"unset CUDA_VISIBLE_DEVICES; export ROCR_VISIBLE_DEVICES=$counter\"")
			counter=$((counter+1))
			if [ $counter -eq 8 ] ; then
				counter=0
			fi
		done
	done
	unset -n this_Nts
done


joblabel="RHMC_gpu_64Nt_ms20"
n_jobs=8

N=8  # job steps per jobs

# loop over "subarrays" of length N for conftype, stream, lattice, beta, masses, , ratfiles, custom_cmds
for ((j = 0 ; j < n_jobs  ; j++)); do

	i=$((j*N))  # array offset
	if [ $j -eq $((n_jobs-1)) ] ; then
		N=4
	fi
	if [ ! "$(squeue -u $USER | grep ${joblabel}_$j)" ] ; then
		script_call=$(cat <<DELIM
./create_RHMC_job.sh \
--CheckConf_path ~/code_build/SIMULATeQCD/build_new/applications/CheckConf \
--CheckRand_path ~/code_build/SIMULATeQCD/build_new/applications/CheckRand \
--module_load mpi/openmpi-x86_64 \
--output_base_path /volatile/thermo/laltenko/conf \
--executable_dir /home/laltenko/code_build/SIMULATeQCD/build/applications \
--n_sim_steps $N \
--conftype ${arr_conftype[@]:i:N} \
--stream_id ${arr_stream[@]:i:N} \
--Lattice ${arr_Lattice[@]:i:N} \
--Nodes "1 1 1 1" \
--beta ${arr_beta[@]:i:N} --mass_s ${arr_mass_s[@]:i:N} --mass_ud ${arr_mass_ud[@]:i:N} \
--rat_file ${arr_rat_file[@]:i:N} \
--jobname "${joblabel}_$j"  --mail_user laltenkor@bnl.gov \
--time 48:00:00 --nodes 1 --gpuspernode 8 \
--account thermo21g --partition 21g --qos normal --sbatch_custom "dependency=singleton" \
--conf_nr auto \
--custom_cmds ${arr_custom_cmds[@]:i:N} \
--no_updates 1000 \
--rand_flag 1 --seed random --rand_file auto \
--always_acc 0 \
--write_every 1 --load_conf 2 \
--step_size 0.1 --no_md 10 --no_step_sf 10 --no_sw 10 \
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
			echo "Did not submit job"
		fi
	fi
done
