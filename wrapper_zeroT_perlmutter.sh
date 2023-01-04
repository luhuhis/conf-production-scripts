#!/bin/bash

# File to run RHMC on perlmutter

thermalize="false"
if [ "$thermalize" == "true" ] ; then
	step_size=0.2
	no_md=5
	no_step_sf=5
	no_sw=5
	load_conf=0
	write_every=1
	always_acc=1
	array="0-0"
else
	step_size=0.05
	no_md=20
	no_step_sf=20
	no_sw=20
	load_conf=2
	write_every=5
	always_acc=0
	array="0-100%1"
fi

arr_Ns=(       64   64   64   64   64   64   64   64   64   64)
arr_Nt=(       72   72   60   72   60   72   60   72   66   60)
arr_beta=(   8249 7777 7570 7913 7704 8068 7857 8249 8147 8036)
arr_mass_s=( 1011 1601 1973 1400 1723 1204 1479 1011 1115 1241)
arr_mass_ud=(2022 3202 3946 2800 3446 2408 2958 2022 2230 2482)

Nodes="1 2 4 1"

for idx in "${!arr_Nt[@]}"; do
echo $idx
Ns=${arr_Ns[idx]}
Nt=${arr_Nt[idx]}

beta_str=${arr_beta[idx]}
mass_ud_str=${arr_mass_ud[idx]}
mass_s_str=${arr_mass_s[idx]}


beta="$(echo "scale=3; $beta_str/1000" | bc -l)"
mass_s="0$(echo "scale=5; $mass_s_str/100000" | bc -l)"
mass_ud="0$(echo "scale=6; $mass_ud_str/1000000" | bc -l)"

rat_file="/pscratch/sd/l/laltenko/conf/rat_approx/rat_ml00${mass_ud_str}ms0${mass_s_str}_f21.txt"

stream="_1"
if [ ! "$(squeue -u $USER | grep RHMC_${beta}_${Ns}${Nt}${stream})"  ] ; then

./create_RHMC_job.sh \
--CheckConf_path ~/code/SIMULATeQCD/build_gnu/applications/CheckConf \
--CheckRand_path ~/code/SIMULATeQCD/build_gnu/applications/CheckRand \
--module_load cudatoolkit/11.5 craype-accel-nvidia80 PrgEnv-gnu gcc/10.3.0 \
--output_base_path /pscratch/sd/l/laltenko/conf \
--executable_dir /global/homes/l/laltenko/code/SIMULATeQCD/build_gnu/applications \
--n_sim_steps 1 \
--conftype l${Ns}${Nt}f21b${beta_str}m00${mass_ud_str}m0${mass_s_str} \
--stream_id $stream \
--Lattice "$Ns $Ns $Ns $Nt" \
--Nodes "$Nodes" \
--beta $beta --mass_s $mass_s --mass_ud $mass_ud \
--step_size $step_size --no_md $no_md --no_step_sf $no_step_sf --no_sw $no_sw \
--rat_file $rat_file \
--rand_file auto --rand_flag 1 --load_conf $load_conf --write_every $write_every --conf_nr auto --seed random \
--always_acc $always_acc \
--jobname RHMC_${beta}_${Ns}${Nt}${stream} --mail_user laltenkor@bnl.gov \
--time 12:00:00 --nodes 2 --gpuspernode 4 --array "$array" \
--account m3760_g --qos regular --sbatch_custom "constraint gpu" \
--custom_cmds "export MPICH_GPU_SUPPORT_ENABLED=1;" \
--no_updates 1000 \
--save_jobscript ./generated_jobscripts/jobscript_${Ns}${Nt}_${beta_str}${stream}.sh

fi

done
