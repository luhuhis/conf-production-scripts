#!/bin/bash
echo "`date +"%F %T"`" >> prev_calls_${0##*/}.log
echo "${0} ${@}" >> prev_calls_${0##*/}.log

# default arguments
mail_user="altenkort@physik.uni-bielefeld.de"
mail_type=FAIL
output_base_path=/work/temp/altenkort/conf/quenched
partition=volta
qos=urgent
nconfs=1000
nodex=1
nodey=1
nodez=1
nodet=1
time="10-00:00:00"
start=one
nsweeps_thermal_HB_only=500
nsweeps_thermal_HBwithOR=4000
nsweeps_ORperHB=4
nsweeps_HBwithOR=500
executable_dir=/home/altenkort/code_build/ParallelGPU/stable_executables/
executable=sampleTopology
measurementsdir=.
conf_nr=0

#start parse command line arguments
POSITIONAL=(); while [[ $# -gt 0 ]]; do key="$1"; case $key in
--mode) mode="$2"; shift; shift; ;; #continue or resume
--conftype) conftype="$2"; shift; shift; ;; #format e.g. s064t16_b0687361 for ns=64, nt=16, beta=6.87361
--str_id) str_id="$2"; shift; shift; ;;
--nconfs) nconfs="$2"; shift; shift; ;;
--conf_nr) conf_nr="$2"; shift; shift; ;;
--nodex) nodex="$2"; shift; shift; ;;
--nodey) nodey="$2"; shift; shift; ;;
--nodez) nodez="$2"; shift; shift; ;;
--nodet) nodet="$2"; shift; shift; ;;
--time) time="$2"; shift; shift; ;;
--start) start="$2"; shift; shift; ;;
--nsweeps_thermal_HB_only) nsweeps_thermal_HB_only="$2"; shift; shift; ;;
--nsweeps_thermal_HBwithOR) nsweeps_thermal_HBwithOR="$2"; shift; shift; ;;
--nsweeps_ORperHB) nsweeps_ORperHB="$2"; shift; shift; ;;
--nsweeps_HBwithOR) nsweeps_HBwithOR="$2"; shift; shift; ;;
--output_base_path) output_base_path="$2"; shift; shift; ;; #folder that contains stream folders
--executable_dir) executable_dir="$2"; shift; shift; ;;
--executable) executable="$2"; shift; shift; ;;
--mail_user) mail_user="$2"; shift; shift; ;;
--mail_type) mail_type="$2"; shift; shift; ;;
--partition) partition="$2"; shift; shift; ;;
--qos) qos="$2"; shift; shift; ;;
--new_random_state) new_random_state="true"; shift; ;;
--prev_conf) prev_conf="$2"; shift; shift; ;;
--conf_nr) conf_nr="$2"; shift; shift; ;;
--measurementsdir) measurementsdir="$2"; shift; shift; ;;
*) echo "ERROR: $key: Unknown argument!"; exit 1; ;; esac ; done; set -- "${POSITIONAL[@]}"
#end parse arguments

if     [ -z ${conftype+x} ] \
|| [ -z ${str_id+x} ] \
|| [ -z ${mode+x} ] ;
then echo "ERROR: Please specify the required arguments!"; exit 1; fi
executable_path=$executable_dir/$executable
if [ ! -f $executable_path ]; then echo "ERROR: Executable does not exist!"; exit 1; fi

numberofgpus=$(($nodex * $nodey * $nodez * $nodet))
if [ $numberofgpus -ge 5 ]; then echo "Script only supports n_gpus=4!"; exit 1; fi
nodes="$nodex $nodey $nodez $nodet"

#create some paths and directories
jobname=gen_${conftype}_$str_id
logdir=$output_base_path/${conftype}/logs
paramdir=$output_base_path/${conftype}/param
paramfile=$paramdir/${conftype}_${str_id}.param
outputdir=$output_base_path/${conftype}/${conftype}_${str_id}

#Start: generate GenerateQuenched parameter file
ns=${conftype#s}; ns=${ns%%t*}
nt=${conftype#*t}; nt=${nt%%_b*}
Lattice="$ns $ns $ns $nt"
beta=${conftype#*_b}; beta=`bc <<< "scale=5;$beta/100000"`

echo "PARAM: ns $ns nt $nt beta $beta"
echo "PARAM: nsweeps_ORperHB $nsweeps_ORperHB nsweeps_HBwithOR $nsweeps_HBwithOR"

#start fresh, resume, or auto resume (finds last conf nr automatically)?
if [ "$mode" == "start" ]; then
echo "PARAM: start $start nsweeps_thermal_HB_only $nsweeps_thermal_HB_only nsweeps_thermal_HBwithOR $nsweeps_thermal_HBwithOR"
start_or_continue="start = $start
nsweeps_thermal_HB_only = $nsweeps_thermal_HB_only
nsweeps_thermal_HBwithOR = $nsweeps_thermal_HBwithOR"


elif [ "$mode" == "resume" ] || [ "$mode" == "resume_auto" ]; then
if [ "$mode" == "resume" ]; then
if [ -z ${conf_nr+x} ]; then echo "ERROR: Please specify --conf_nr!"; exit 1; fi
elif [ "$mode" == "resume_auto" ]; then
working_dir=`pwd` && cd $outputdir
last_conf=`ls -r | grep rand | head -n1`
conf_nr=${last_conf##*_U}
nconfs=`bc <<< $nconfs-$conf_nr/$nsweeps_HBwithOR`
echo "INFO: Changed conf_nr to $conf_nr and nconfs to $nconfs"
cd $working_dir
fi
prev_conf=$outputdir/conf_${conftype}_${str_id}_U$conf_nr
echo "PARAM: conf_nr $conf_nr nconfs $nconfs"
echo "PARAM: prev_conf $prev_conf"
start_or_continue="conf_nr = $conf_nr
prev_conf = $prev_conf"
if  [ ! "$new_random_state" == "true" ]; then
prev_rand=$outputdir/rand_${conftype}_${str_id}_U$conf_nr
start_or_continue="$start_or_continue
prev_rand = $prev_rand"
echo "PARAM: prev_rand $prev_rand"
else
echo "Using new random state for first conf"
fi
elif [ "$mode" == "resume_manual" ]; then
start_or_continue="prev_conf=$prev_conf
conf_nr=$conf_nr"
else
echo "ERROR: Please choose --mode start or resume or resume_manual or resume_auto!"
exit 1
fi

echo "PARAM: executable $executable_path"
echo "PARAM: output_dir $outputdir"
echo "PARAM: nodes $nodes numberofgpus $numberofgpus partition $partition qos $qos time $time"
echo "PARAM: mail_user $mail_user mail_type $mail_type"

echo -en "\nContinue y/n? "
read input
if [ "$input" != "y" ]; then
echo "INFO: Did not start job..."
exit
fi

#-------------------------------------------------------

mkdir -p $outputdir
mkdir -p $logdir
mkdir -p $paramdir

parameters="Lattice = $Lattice
Nodes = $nodes
beta = $beta
format = nersc
endianness = auto
stream = $str_id
output_dir = $outputdir
nconfs = $nconfs
nsweeps_ORperHB = $nsweeps_ORperHB
nsweeps_HBwithOR = $nsweeps_HBwithOR
$start_or_continue

# parameter file for sampleTopology
Lattice    = $Lattice
Nodes = $nodes
beta = $beta
format     = nersc
endianness = auto
stream = $str_id
output_dir = $outputdir
nconfs = $nconfs
nsweeps_ORperHB = $nsweeps_ORperHB
nsweeps_HBwithOR = $nsweeps_HBwithOR
nsweeps_btwn_topology_meas = $nsweeps_HBwithOR

$start_or_continue

prev_conf_has_nonzero_Q = 1

force = zeuthen                                      # specify if you want to have the Wilson flow ("wilson") or Zeuthen flow ("zeuthen").
start_step_size = 0.001                               # The (start) step size of the Runge Kutta integration.
RK_method = fixed_stepsize                      # Set to fixed_stepsize, adaptive_stepsize or adaptive_stepsize_allgpu (see wiki).
accuracy = 0.001                                      # Specify the accuracy of the adaptive step size method.

measurements_dir = $measurementsdir/                                # Measurement output directory
measurement_intervall = 0 1.125                          # Flow time Interval which should be iterated.

# Set the flow-times which shouldn't be skipped by the fixed or adaptive stepsize
necessary_flow_times=0.0010000 0.0370142 0.0737064 0.1142225 0.1580233 0.2065080 0.2604314 0.3188686 0.3850862 0.4586788 0.5380964 0.6326551 0.7200000
# necessary_flow_times=0.0010000 0.0365094 0.0735550 0.1133690 0.1576822 0.2067727 0.2614191 0.3207117 0.3861387 0.4582271 0.5416054 0.6406085 0.7573436 0.9006876 1.0850327 1.1250000

print_all_flowtimes = 0

ignore_start_step_size = 1                        # ignore the fixed stepsize and infer stepsizes from necessary_flow_times. only use with RK_method=fixed_stepsize
save_conf = 0                                        # Save the flowed configuration at each step? (0=no, 1=yes)

# Set to 1 if you want to measure any of these observables (or 0 if not):
plaquette = 0
topCharge_imp = 1
topCharge = 0
topChargeTimeSlices_imp = 1
topChargeTimeSlices = 0

"
echo "$parameters" > $paramfile
#End: parameter file

sbatch << EOF
#!/bin/bash
#SBATCH --job-name=${jobname}
#SBATCH --output=$logdir/${jobname}_%j.out
#SBATCH --error=$logdir/${jobname}_%j.err
#SBATCH --mail-type=$mail_type
#SBATCH --mail-user=$mail_user
#SBATCH --partition=$partition
#SBATCH --qos=$qos
#SBATCH --nodes=1
#SBATCH --gres=gpu:$numberofgpus
#SBATCH --ntasks=$numberofgpus
#SBATCH --gpus-per-task=1
#SBATCH --tasks-per-node=$numberofgpus
#SBATCH --time=$time
#SBATCH --gres-flags=enforce-binding

echo -e "Start \`date +"%F %T"\` | \$SLURM_JOB_ID \$SLURM_JOB_NAME | \`hostname\` | \`pwd\` \\n"
run_command="srun -n $numberofgpus $executable_path $paramfile"
echo -e "\$run_command \\n"
eval "\$run_command"
echo -e "\\nEnd \`date +"%F %T"\` | \$SLURM_JOB_ID \$SLURM_JOB_NAME | \`hostname\` | \`pwd\`"
EOF
echo "^sbatch script submitted" >> prev_calls_${0##*/}.log

