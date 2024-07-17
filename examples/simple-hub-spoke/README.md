# Simple hub-spoke

## Description
This example serves to show the automatic core features of the module.

It can completly handle all subnetting

Please take a close look at the comments, enjoy!

```hcl
provider "azurerm" {
  features { //The default provider will be our hub
  } //Using command line az login, so the subscription_id is inherited
}
provider "azurerm" {
  features {
  }
  alias = "spoke"
  subscription_id = "<spoke sub id>" //Make sure the Azure context has write access to the spoke provider
}
//We define the "hub" By itself in its own module call - This is to make sure custom names applied only effects any hub related resource
//The hub must ALWAYS be deployed AHEAD OF TIME of any spokes being created in their own module calls - Any spokes created directly in the module call for the hub will be deployed successfully
module "only_hub" {
  source = "hashicorp/hub-spoke/azurerm"
  topology_object = {
    name_prefix = "contoso" //Because its name_prefix, the resource type of the specific resource being deployed will be the first part of the total name of each resource
    env_name = "test" //env_name and project_name MUST be deployed together - name_prefix or name_suffix can be used by itself
    project_name = "project1"
    hub_object = {
      network = {
        //Not defining anything else will result in a resource group and a vnet without anything else
      }
    }
  }
  providers = {
    azurerm.hub = azurerm //Default provider will be the hub in this example
    azurerm.spoke = azurerm.spoke //Even though we do not deploy any spoke resources, we must parse the spoke provider
  }
}
module "only_spoke" {
  source = "hashicorp/hub-spoke/azurerm"
  topology_object = {
    name_suffix = "contoso" //Any spoke is NOT required to follow ANY naming already done in the hub - We simply use name_suffix to showcase it
    //We wont add ANY env_name or project_name just to showcase - its ALWAYS recommended though, as naming is quite strict in the Microsoft CAF guidance
    hub_object = {
      //We wont create a new hub - but the attribute that will link the spoke to the hub 'vnet_resource_id' Must be defined within this object
      network = {
        vnet_resource_id = values(module.only_hub.vnet_return_objects[0]).id
      }
    }
    //Even though 'spoke_objects' Can take in any number of spoke objects ALL will be created in the same subscription
    //To avoid this, simply create a new module call for all new spokes required to be in different subscriptions
    spoke_objects = [
      {
        network = {
          
          subnet_objects = [
            {
              use_last_subnet = true //Will use the last POSSIBLE CIDR block of /26 from the vnets /24 (This is all default behaviour)
            },
            {
              //By not parsing anything for subnet2, it will default to use attribute 'use_first_subnet'
            }
          ]
        }
      }
    ]
  }
  providers = {
    azurerm.hub = azurerm //Default provider will be the hub in this example
    azurerm.spoke = azurerm.spoke //Even though we do not deploy any spoke resources, we must parse the spoke provider
  }
}
//All the above code will create the following:
/*
  1. Hub consiting of:
     a. resource group
     b. vnet
     c. 0 subnets
     d. peering to spoke1
  2. Spoke consisting of:
     a. resource group
     b. vnet
     c. 2 subnets
     d. peering to hub
  We can add so much more to the above configuration
*/
```