#!/bin/bash
# A simple Azure Storage example script

# ensure az is available
#curl -L https://aka.ms/InstallAzureCli | bash



export AZURE_STORAGE_ACCOUNT=${AZURE_STORAGE_ACCOUNT:-pocgadata}
export container_name=${AZURE_STORAGE_CONTAINER:-hg38}


for i in $@; do 
  export blob_name=$(basename ${i})
  export file_to_upload=$i
  
  #echo "Creating the container..."
  az storage container create --name $container_name
  
  echo "Uploading the file..."
  az storage blob upload --no-progress --container-name $container_name --file $file_to_upload --name $blob_name
  
  echo "Listing the blobs..."
  az storage blob list --container-name $container_name --output table
  
  echo "Done"
done

