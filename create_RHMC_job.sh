#!/bin/bash

# requires bash 4.4 or greater
if (( BASH_VERSINFO[0]*100 + BASH_VERSINFO[1] < 404 )); then
    echo "ERROR: Need bash version 4.4 or greater."
    exit 1
fi

# parse arguments from command line
source src/create_RHMC_job/parse_args.sh
# now, lots of environment variables are set which we can use to populate the jobscript template.

#===========================SAVE SCRIPT CALLS IN FILE==========================
scriptname=${0##*/}
prevcallfile=prev_calls_${scriptname%\.*}.log
echo -e "\n$(date +"%F %T")" >> "$prevcallfile"
echo "${0}" "${@}" >> "$prevcallfile"

# check if parameters make sense
executable_path=$executable_dir/$executable
if [ ! -f "$executable_path" ]; then echo "ERROR: Executable $executable_path does not exist!"; exit 1; fi
if [ "$CheckConf_path" ] && [ ! -f "$CheckConf_path" ]; then echo "ERROR: CheckConf executable does not exist!"; exit 1; fi
if [ "$CheckRand_path" ] && [ ! -f "$CheckRand_path" ]; then echo "ERROR: CheckRand executable does not exist!"; exit 1; fi

if [ "$rand_flag" -eq 1 ] && [ ! "$rand_file" ] ; then
    echo "ERROR: rand_flag=1 but no --rand_file was given!"
    exit 1
fi

if [ "$load_conf" -eq 2 ] && [ ! "$conf_nr" ] ; then
    echo "ERROR: load_conf=2 but no --conf_nr was given!"
    exit 1
fi

# this is a list of variable names that may contain different parameters for each job step.
parameters=("${ARGS_VAR[@]}")

# if there is only a single parameter given, then we need to duplicate it a few times until there are n_sim_steps copies of it.
# so now we make all these parameters be a bash array with n_sim_steps entries by appending the single entry n_sim_steps-1 times.
for param in "${parameters[@]}" ; do

    param_name=${param}
    declare -n param

    if [ ${#param[@]} -eq 1 ] ; then
        echo "INFO: Only a single argument was given for ${param_name}. This will be used for all ${n_sim_steps} job steps."

        # append n_sim_steps-1 copies of the parameter.
        for ((i=1; i<n_sim_steps; i++)) ; do
            param+=("${param[0]}")
        done
    fi
    unset -n param
done

parameters+=("seed")  # seeds should always be different

# check if all parameters now have the correct number of entries  (=n_sim_steps)
for param in "${parameters[@]}" ; do
    param_name=${param}
    declare -n param
    if [ ${#param[@]} -ne "$n_sim_steps" ] ; then
        echo "ERROR: --$param_name should have either a single or $n_sim_steps (=n_sim_steps) arguments."
        exit 1
    fi
    unset -n param
done


# parse slurm options
if [ "$qos" ] ; then
    SBATCH_QOS="#SBATCH --qos=$qos"
fi
if [ "$partition" ] ; then
    SBATCH_PARTITION="#SBATCH --partition=$partition"
fi
if [ "$account" ] ; then
    SBATCH_ACCOUNT="#SBATCH --account=$account"
fi
if [ "$constraint" ] ; then
    SBATCH_CONSTRAINT="#SBATCH --constraint=$constraint"
fi
if [ "$array" ] ; then
    SBATCH_ARRAY="#SBATCH --array=$array"
fi
if [ "$sbatch_custom" ] ; then
    SBATCH_CUSTOM="#SBATCH --$sbatch_custom"
fi
if [ "$code" == "SIMULATeQCD" ] ; then
    SBATCH_GPUS="#SBATCH --gres=gpu:${gpuspernode}"
fi

# decide which parameter file layout to use
param_func="set_parameters_SIMULATeQCD"
if [ "$code" == "patrick" ] ; then
    param_func="set_parameters_patrick"
fi


logdir=${output_base_path}/logs
mkdir -p "$logdir"

# create jobscript from template and fill it with given parameters.
source src/create_RHMC_job/jobscript_template.sh
# now the variable "sbatchscript" contains the job script.


echo -ne "\n===== BEGIN SBATCHSCRIPT ===\n"
echo "$sbatchscript"
echo -ne "===== END   SBATCHSCRIPT ===\n\n"

if [ "$save_jobscript" ] ; then
    echo "$sbatchscript" > "$save_jobscript"
fi

echo -en "\nSubmit y/n? "
read -r input
if [ "$input" != "y" ]; then
    echo "INFO: Did not submit job..."
    exit
fi

(sbatch <<< "$sbatchscript")

echo "sbatch script submitted" >> "$prevcallfile"
