#!/bin/bash
#PBS -l nodes=2
if [ -z $SLURM_JOB_ID ]; then
   PERSISTENTLOCATION=$HOME/joboutputs/headnodetest
   UNIQUENODEFILE=/tmp/beegfsnodefile.headnodetest
   hostname -s > $UNIQUENODEFILE
else
   PERSISTENTLOCATION=$HOME/joboutputs/$SLURM_JOB_ID
   UNIQUENODEFILE=/tmp/beegfsnodefile.$SLURM_JOB_ID
   scontrol show hostnames "$SLURM_NODELIST" > $UNIQUENODEFILE
fi

SCRATCH=/var/tmp
SCRATCHINTERNAL=$SCRATCH/$USER
SCRATCHPFS=/mnt/beeond

if ! [ -d $SCRATCHINTERNAL ] ; then 
   mkdir -p $SCRATCHINTERNAL 

fi
if ! [ -d $PERSISTENTLOCATION ] ; then 
   mkdir -p $PERSISTENTLOCATION
fi
sudo beeond start -n $UNIQUENODEFILE -d $SCRATCHINTERNAL -c $SCRATCHPFS

env 
hostname


cat << EOF > hello.c
/* program hello */
/* Adapted from mpihello.f by drs */

#include <mpi.h>
#include <stdio.h>

#include <unistd.h>

int main(int argc, char **argv)
{
  int rank;
  char hostname[256];

  MPI_Init(&argc,&argv);
  MPI_Comm_rank(MPI_COMM_WORLD, &rank);
  gethostname(hostname,255);

  char filename[512];
  /* Write a file to the scratch pfs location */
  sprintf(filename, "$SCRATCHPFS/%s-%d", hostname, rank);
  FILE* f = fopen(filename,"w");
  fclose(f);

  printf("Hello world!  I am process number: %d on host %s\n", rank, hostname);

  MPI_Finalize();

  return 0;
}
EOF
/usr/lib64/openmpi/bin/mpicc hello.c -o $HOME/hello.exe
/usr/lib64/openmpi/bin/mpirun  --hostfile $UNIQUENODEFILE $HOME/hello.exe
#stage out all remaining data
beeond-cp copy -n $UNIQUENODEFILE $SCRATCHPFS  $PERSISTENTLOCATION 

sudo beeond stop -n $UNIQUENODEFILE -L -d
