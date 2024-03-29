# conf-production-scripts

This is a collection of scripts to run SIMULATeQCD's RHMC and GenerateQuenched as well as Patrick's CPU RHMC on different HPC clusters. 

## create_RHMC_job.sh 
Requirement: bash version >=4.4, python

- This script accepts a lot of parameters which you can see by calling it with the --help option. The parameters can take care of almost any slurm configuration, and can translate its RHMC parameters to parameter files for both Patrick's CPU RHMC as well as SIMULATeQCD's parameters.

- Usage examples for create_RHMC_job.sh can be found in the wrapper scripts. These are real production run examples, which is why they may be a bit complicated. Inside of these scripts there is usually first some definition of sets of RHMC paramaters for the different gauge ensembles, followed by a loop of over these sets, in which create_RHMC_job.sh is then called with the corresponding parameters.

Some notable features include:
- Automatically resume previous runs based on conf nr
- Automatically skip broken configurations and random number files using SIMULATeQCD's "CheckConf" and "CheckRand"
- Automatically use new seed when random number file is missing
- Run multiple job steps SIMULTANEOUSLY on the same node in parallel. Useful if you can only allocate full nodes, for example, with 8 GPUs, but you want to run single GPU jobs. In the second part of /example_usage/wrapper_jlab_ms20.sh you can see an example for this. 
- Detailed log output about the run and whether the RHMC failed or succeeded, even for multiple simulatneous job steps
- Supports loading any modules and other scripts before executing srun using parameters --custom_cmds
- Any slurm parameters can be passed using the custom slurm parameter --sbatch_custom, the srun command can be replaced by something else using --srun_custom
- Arguments are parsed via python's argparse 


Below is an example log file that records what a job for perlmutter generated with ```create_RHMC_job.sh``` is doing. The job contains only one job step. First we print some general info, then we set some custom environment variables for this specific machine, then we check whether the configuration and randfile are corrupted or not. Then the RHMC is launched using srun and the actual run output is routed to another file. In this case the job was aborted due to time limit, which is why no feedback to whether the job succeeded could be printed in the end.

```
Start 2023-02-01 22:29:14

5191218 RHMC_8.068_6472_1 | nid003208 | /global/homes/l/laltenko/scripts/run_GenerateQuenched

export MPICH_GPU_SUPPORT_ENABLED=1;
# [2023-02-01 22:29:14] INFO: Checking Gaugefile /pscratch/sd/l/laltenko/conf/l6472f21b8068m002408m01204/l6472f21b8068m002408m01204_1/l6472f21b8068m002408m01204_1.700
# [2023-02-01 22:30:06] RESULT: Gaugefile OK! (readin, plaquette, unitarity)
# [2023-02-01 22:30:06] INFO: Checking Randfile /pscratch/sd/l/laltenko/conf/l6472f21b8068m002408m01204/l6472f21b8068m002408m01204_1/l6472f21b8068m002408m01204_1_rand.700
# [2023-02-01 22:30:07] RESULT: Randfile OK!
srun --exclusive -n 8 --gres=gpu:4 -u /global/homes/l/laltenko/code/SIMULATeQCD/build_gnu/applications/RHMC /pscratch/sd/l/laltenko/conf/l6472f21b8068m002408m01204/param/l6472f21b8068m002408m01204_1.700.param &> /pscratch/sd/l/laltenko/conf/l6472f21b8068m002408m01204/logs/l6472f21b8068m002408m01204_1.700.out
```
