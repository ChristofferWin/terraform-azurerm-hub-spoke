provider "azurerm" {
  features { //The default provider will be our hub
  } //Using command line az login, so the subscription_id is inherited
}

provider "azurerm" {
  features {
  }
  alias = "spoke1"
  subscription_id = "<sub_id_spoke1>" //Make sure the Azure context has write access to the spoke provider
}

provider "azurerm" {
  features {
  }
  alias = "spoke2"
  subscription_id = "<sub_id_spoke2>" //Make sure the Azure context has write access to the spoke provider
}

//The hub and spoke EVEN though they are created in the same call, will still be created on 2 different subscriptions
//THE HUB MUST BE DEPLOYED BEFORE ANY SPOKE MODULE CALLS ARE DEPLOYED
module "hub-and-1-spoke" {
  source = "ChristofferWin/hub-spoke/azurerm"
  
  topology_object = {
    name_prefix = "fabrikam"
    env_name = "prod"
    project_name = "tf"
    dns_servers = ["1.1.1.1", "8.8.8.8"] //All vnets will use these DNS servers
    location = "northeurope" //Overwriting the default location of 'westeurope'
    
    tags = {
      "demo" = "demo1" //This tag will be added to all resource groups within this module call - Tags on this level is added to any specific resource tags set
    }

    hub_object = {
      rg_name = "hub-custom-rg-name" //Overwriting the naming injection defined in the top level object

      tags = {
        "THE_HUB" = "TRUE" //The top level tag will simply be added to this, so nothing is replaced
      }

      network = {
        vnet_name = "hub-custom-vnet-name" //Overwriting the naming injection
        vnet_spoke_address_spaces = ["10.0.1.0/24", "172.16.1.0/24", "172.16.2.0/24"] //We will add these 2 custom address spaces to the two comming spokes (Deployed in other module calls)
        //The first address space comes from the default one deployed within this hub module call
        //The 'vnet_spoke_address_spaces' Attribute is used to help the module to use these directly in the firewall rules being created as well
        //If the firewall object is defined but the 'vnet_spoke_address_spaces' Is not, the module simply skips deploying any Firewall rules - The attribute can always be added
        
        vpn = {
            //Deploying point-2-site VPN with default settings
        }

        firewall = {
          //The firewall can also be created entirely enmpty just like the vpn, simply using default settings
          log_name = "custom-log-analytics-name" //We control settings for the logging for the firewall within the firewaLL object
          log_diag_name = "custom-diagnostic-settings-name"
        }
        
        //Since we want to deploy both the VPN and Firewall, a subnet for each with the exact Microsoft required name must be defined
        subnet_objects = [
          {
             name = "AzureFirewallSubnet" //Name must be exactly this
          },
          {
            name = "GatewaySubnet" //Name must be exactly this
          },
          {
            name = "something-mgmt-something" //Because we add a hub subnet with the text 'mgmt' OR 'management' This SPECIFIC subnet ONLY will be used as the source address space for the rule allowing RDP / SSH to spoke vnets
          }
        ]
      }
    }

    spoke_objects = [
      {
        tags = {
          "SPOKE1" = "SPOKE1"
        }

        network = {
          address_spaces = ["172.16.1.0/24"]

           subnet_objects = [
              {
                address_prefix = ["172.16.1.0/26"] //Because we manually take the first possible /26 of the custom vnet address space, we can no longer use the attribute 'use_first_subnet' In any following subne
              },
              {
                use_last_subnet = true //We can still automatically take from the end of the /24 CIDR vnet address block
              },
              {
                use_last_subnet = true //This 3rd subnet will then take the 2nd last possible subnet
              }
           ]
        }
      }
    ]
  }

  providers = {
    azurerm.hub = azurerm
    azurerm.spoke = azurerm.spoke1
  }
}

module "spoke2" {
  source = "ChristofferWin/hub-spoke/azurerm"

  topology_object = {
    name_suffix = "cool-spoke2"
    subnets_cidr_notation = "/28"

    hub_object = {
      
      network = {
        vnet_resource_id = values(module.hub-and-1-spoke.vnet_return_objects)[0].id //Even if spoke(s) Are created directly with the hub, the first vnet will ALWAYS be the hub
        vnet_peering_name = "some-custom-peering-name" //Name that is set in the HUB vnet
      }
    }

    spoke_objects = [
      {
        tags = {
          "SPOKE2" = "SPOKE2"
        }

        network = {
          address_spaces = ["172.16.2.0/24"]

          subnet_objects = [
            {
              use_last_subnet = true
            },
            {
              use_first_subnet = true
            },
            {
              use_last_subnet = true //As long as their is space in the CIDR block for spoke vnet addres space, we can mix the 2 attributes as much as we like
            }
          ]
        }
      }
    ]
  }

  providers = {
    azurerm.hub = azurerm
    azurerm.spoke = azurerm.spoke2
  }
}

//All the above code will create the following:

/*
  1. Hub consiting of:
     a. resource group
     b. vnet
     c. 2 subnets
     d. peering to spoke1 and spoke2
     e. firewall
     f. 2 firewall rules - 1 for connectivity to the internet for spokes & 1 for connecting mgmt subnet to spoke subnets
     g. point 2 site vpn

  2. Spoke1 consisting of:
     a. resource group
     b. vnet
     c. 3 subnets
     d. peering to hub
     e. 3 route tables - 1 for each subnet

  3. Spoke2 consisting of:
     a. resource group
     b. vnet
     c. 3 subnets
     d. peering to hub
     e. 3 route tables - 1 for each subnet
  We can add so much more to the above configuration
*/