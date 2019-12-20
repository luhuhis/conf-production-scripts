#!/bin/bash

# default arguments
nconfs=1000
output_partition=temp
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

#start parse command line arguments
POSITIONAL=(); while [[ $# -gt 0 ]]; do key="$1"; case $key in 
        --mode) mode="$2"; shift; shift; ;; #continue or resume
        --conftype) conftype="$2"; shift; shift; ;; #format: sNNNtNN_bNNNNNNN
        --str_id) str_id="$2"; shift; shift; ;;
        --nconfs) nconfs="$2"; shift; shift; ;;
        --output_partition) output_partition="$2"; shift; shift; ;; #temp or conf
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
*) echo "$key: Unknown argument!"; exit 1; ;; esac ; done; set -- "${POSITIONAL[@]}" 
#end parse arguments

if     [ -z ${conftype+x} ] \
    || [ -z ${str_id+x} ] \
    || [ -z ${mode+x} ] ;
then echo "Please specify required arguments!"; exit 1; fi


numberofgpus=$(($nodex * $nodey * $nodez * $nodet))
if [ $numberofgpus -ge 5 ]; then echo "Script only supports n_gpus=4!"; exit 1; fi
nodes="$nodex $nodey $nodez $nodet"

if [[ "$output_partition" == temp ]]; then
    output_base_path=/work/temp/altenkort/conf
elif [[ "$output_partition" == conf ]]; then
    output_base_path=/work/conf/altenkort/
fi

echo "conftype str_id nconfs output_partition conf_nr nodes = numberofgpus"
echo "$conftype $str_id $nconfs $output_partition $conf_nr $nodes = $numberofgpus"
echo -n "Continue y/n? "
read input
if [ "$input" != "y" ]; then
    echo "Did not start job..."
    exit 
fi
read -p "Really continue? Press enter..."

#create some paths and directories
jobname=gen_${conftype}_$str_id
logdir=$output_base_path/quenched/${conftype}/logs
paramdir=$output_base_path/quenched/${conftype}/param
paramfile=$paramdir/${conftype}_${str_id}.param
outputdir=$output_base_path/quenched/${conftype}/${conftype}_${str_id}
mkdir -p $outputdir
mkdir -p $logdir
mkdir -p $paramdir


#Start: generate GenerateQuenched parameter file
ns=${conftype#s}; ns=${ns%%t*}
nt=${conftype#*t}; nt=${nt%%_b*}
Lattice="$ns $ns $ns $nt"
beta=${conftype#*_b}; beta=`bc <<< "scale=5;$beta/100000"`

if [ "$mode" == "start" ]; then
start_or_continue="start = $start
nsweeps_thermal_HB_only = $nsweeps_thermal_HB_only
nsweeps_thermal_HBwithOR = $nsweeps_thermal_HBwithOR"
elif [ "$mode" == "resume" ]; then
if [ -z ${conf_nr+x} ]; then echo "Please specify --conf_nr!"; exit 1; fi
start_or_continue="conf_nr = $conf_nr
prev_conf = $outputdir/conf_${conftype}_${str_id}_U$conf_nr
prev_rand = $outputdir/rand_${conftype}_${str_id}_U$conf_nr"
else
echo "Please choose --mode start or resume!"
exit 1
fi

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
#SBATCH --mail-type=FAIL
#SBATCH --mail-user=altenkort@physik.uni-bielefeld.de
#SBATCH --partition=compute_gpu_volta
#SBATCH --nodes=1
#SBATCH --sockets-per-node=1
#SBATCH --cores-per-socket=$numberofgpus
#SBATCH --gpus-per-socket=$numberofgpus
#SBATCH --gpus-per-node=$numberofgpus
#SBATCH --gpus=$numberofgpus
#SBATCH --ntasks=$numberofgpus
#SBATCH --time=$time

echo -e "Start \`date +"%F %T"\` | \$SLURM_JOB_ID \$SLURM_JOB_NAME | \`hostname\` | \`pwd\` \\n"
srun -n $numberofgpus /work/temp/altenkort/conf/quenched/bin/GenerateQuenched $paramfile
echo -e "Start \`date +"%F %T"\` | \$SLURM_JOB_ID \$SLURM_JOB_NAME | \`hostname\` | \`pwd\` \\n"
EOF
