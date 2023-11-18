#!/bin/bash
# Job name
#SBATCH --job-name NXTFLW
# Submit to the gpu QoS, the requeue QoS can also be used for gpu's 
#SBATCH -q secondary
# Request one node
#SBATCH -N 1
# Total number of cores, in this example it will 1 node with 1 core each.
#SBATCH -n 1
# Request memory
#SBATCH --mem=8G
# Mail when the job begins, ends, fails, requeues
#SBATCH --mail-type=ALL
# Where to send email alerts
#SBATCH --mail-user=go2432@wayne.edu
# Create an output file that will be output_<jobid>.out
#SBATCH -o output_%j.out
# Create an error file that will be error_<jobid>.out
#SBATCH -e errors_%j.err
# Set maximum time limit
#SBATCH -t 14-0:0:0

# List assigned GPU: 
source "${HOME}/mambaforge/etc/profile.d/mamba.sh"
source activate nextflow
module load singularity
export NXF_EXECUTOR=slurm
export NXF_OPTS="-Xms2G -Xmx8G" 
export NXF_SINGULARITY_CACHEDIR=${HOME}/singularity_cache
nf-core download . --compress none --container singularity --singularity-cache-only
nextflow run -profile slurm . --param_name nextflow.config
