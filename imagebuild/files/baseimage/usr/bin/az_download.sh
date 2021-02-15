#!/bin/bash
# A simple Azure Storage example script

# ensure az is available
#curl -L https://aka.ms/InstallAzureCli | bash


export AZURE_STORAGE_ACCOUNT=${AZURE_STORAGE_ACCOUNT:-pocgadata}

for i in $@ ; do 
  export container_name=${AZURE_STORAGE_CONTAINER:-hg38}
  export blob_name=$(basename ${i})
  export destination_file=$(basename $i)
  
  #echo "Creating the container..."
  az storage container create --name $container_name
  
  echo "Listing the blobs..."
  az storage blob list --container-name $container_name --output table
  
  echo "Downloading the file..."
  az storage blob download --no-progress --container-name $container_name --name $blob_name --file $destination_file --output table
 
  echo "Done"
done
