// Deploy:  az deployment group create -g <resource group name> --template-file gallery.bicep --parameters parameters.json
param location string
param azure_compute_gallery_name string

resource computegallery 'Microsoft.Compute/galleries@2022-01-03' = {
  name: azure_compute_gallery_name
  location: location
  properties: {
    identifier: {
    }
  }
}
