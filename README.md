# shc4hpc

The Securelinx Hybrid Cloud for HPC (SHC4HPC) is a utility that allows you to 
 - Build Images for cloud platforms (openstack, azure, aws, kvm)
 - Launch a HPC 'head node' in cloud platforms
 - Enable this headnode to autoscale based on queue length of the slurm scheduler

# Using shc4hpc

You will need credentials for a cloud service.  Copy the example files in examples/drivers/environ.secret 
and examples/drivers/environ.secrets.example to examples/drivers/environ{.secret}
```bash
cp -p examples/drivers/environ.secret.example examples/drivers/environ.secret
cp -p examples/drivers/environ.example examples/drivers/environ
```

Complete any sections required.  You only need to fill in sections relevant for your cloud provider.  

You will also need a number of third party tools.  

place packer binary in thirdparty/ or run
```bash 
cd third-party && get-packer
```

You will then need to install this code onto a 'build' machine, which will take care of building images
```bash
make -f  Makefile.imagebuilder && sudo make -f Makefile.imagebuilder install
```
this will install into the default location of /usr/lib/shc4hpc and create an /etc/sysconfig file relevant
for pointing shc4hpc at the correct location

To install the BUILDER into a different location, 
```
export SHC4HPCBASE=/apps/shc4hpc 
```
before running make 

Images will still use the default location of /usr/lib/shc4hpc. Installing shc4hpc in a non default location on images is not supported

