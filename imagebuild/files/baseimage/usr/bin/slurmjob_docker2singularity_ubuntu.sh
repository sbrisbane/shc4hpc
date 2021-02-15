#!/bin/bash
cd
echo Attempting to pull ubuntu latest, will NOT overwrite if here
singularity  pull  docker://ubuntu:latest
singularity exec ubuntu-latest.simg cat /etc/issue


