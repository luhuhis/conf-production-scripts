#!/bin/bash
echo "`date +"%F %T"` ${0} ${@}" >> prev_calls_${0##*/}.log

# default arguments
mail_user="altenkort@physik.uni-bielefeld.de"
mail_type=FAIL
output_base_path=/work/temp/altenkort/conf/quenched
partition=compute_gpu_volta
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
executable=/work/temp/altenkort/conf/quenched/bin/GenerateQuenched

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
        --executable) executable="$2"; shift; shift; ;;
        --mail_user) mail_user="$2"; shift; shift; ;;
        --mail_type) mail_type="$2"; shift; shift; ;;
        --partition) partition="$2"; shift; shift; ;;
*) echo "ERROR: $key: Unknown argument!"; exit 1; ;; esac ; done; set -- "${POSITIONAL[@]}" 
#end parse arguments

if     [ -z ${conftype+x} ] \
    || [ -z ${str_id+x} ] \
    || [ -z ${mode+x} ] ;
then echo "ERROR: Please specify the required arguments!"; exit 1; fi


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
    prev_rand=$outputdir/rand_${conftype}_${str_id}_U$conf_nr
    start_or_continue="conf_nr = $conf_nr
prev_conf = $prev_conf
prev_rand = $prev_rand"
    echo "PARAM: conf_nr $conf_nr nconfs $nconfs"
    echo "PARAM: prev_conf $prev_conf"
    echo "PARAM: prev_rand $prev_rand"
else
echo "ERROR: Please choose --mode start or resume or resume_auto!"
exit 1
fi

echo "PARAM: executable $executable"
echo "PARAM: output_dir $outputdir"
echo "PARAM: nodes $nodes numberofgpus $numberofgpus partition $partition time $time"
echo "PARAM: mail_user $mail_user mail_type $mail_type"

echo -en "\nContinue y/n? "
read input
if [ "$input" != "y" ]; then
    echo "INFO: Did not start job..."
    exit 
fi

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
#SBATCH --nodes=1
#SBATCH --sockets-per-node=1
#SBATCH --cores-per-socket=$numberofgpus
# #SBATCH --gpus-per-socket=$numberofgpus
#SBATCH --gpus-per-node=$numberofgpus
#SBATCH --gpus=$numberofgpus
#SBATCH --ntasks=$numberofgpus
#SBATCH --time=$time

echo -e "Start \`date +"%F %T"\` | \$SLURM_JOB_ID \$SLURM_JOB_NAME | \`hostname\` | \`pwd\` \\n"
run_command="srun -n $numberofgpus $executable $paramfile"
echo -e "\$run_command \\n"
eval "\$run_command"
echo -e "\\nEnd \`date +"%F %T"\` | \$SLURM_JOB_ID \$SLURM_JOB_NAME | \`hostname\` | \`pwd\`"
EOF
