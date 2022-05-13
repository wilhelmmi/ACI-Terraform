# Terraform ACI-Tenant Onboarding Modul 
---
## Inhalt
1. [Allgemein](#example)
2. [Funktion](#example2)
3. [Anwendung](#third-example)




## Allgemein 

   Für Onboardings neuer Kunden in die AU-Cloud Umgebung kann zukünftig das folgende Modul in das entsprechende Terraform Projekt eingbunden werden. Man muss dem Modul nur die benötigten Daten übergeben und sich nicht um den Code dahinter kümmern. Da das Modul speziell für Cloud-Onboardings entwickelt wurde, kann es vermutlich nicht 1 zu 1 für andere Projekte eingesetzt werden, könnte jedoch als Denkanstoß dienen. 

## Funktion

Mindestens **Terraform v1.1.9**


##### Das Modul erzeugt:

* 1x Tenant
* 1x Vrf
* 1x Application Profile
* Bridge Domains ( Anzahl je nach Bedarf)
* EPGS           ( Anzahl je nach Bedarf)
* Static Ports
* OSPF L3out mit den entsprechenden Zugehörigkeiten (external Epgs, NodeProfiles usw.)
* Contracts 
* SVIS ...

##### Erwarteter Modul Input
Das Modul erwartet einen Input. Sprich all diese Variablen müssen so mit den entsprechenden types an das Modul übergeben werden. 

```
variable "tenant_parameters" {
  type = list(object({
    tenant_name = string
    cloudId     = string
    bridge_domains = list(object({
      bd_name            = string
      bd_unicast_route   = string
      bd_type            = string
      bd_arp_flood       = string
      bd_unk_mac_unicast = string
      bd_subnet          = string
      subnet_scope       = list(string)
      subnet_virtual     = string
    }))
    epgs = list(object({
      epg_name       = string
      pref_gr_member = string
      prio           = string
      pc_enf_pref    = string
      flood_on_encap = string
      epg_ref_bd     = string
      static_ports = list(object({
        port_path    = string
        encap        = string
        mode         = string
        instr_imedcy = string
      }))

    }))
    l3nodes = list(object({
      node_name        = string
      node_path        = string
      rtr_id           = string
      rtr_id_loop_back = string
    }))
    l3outSvi = list(object({
      path        = string
      addr           = string
      members = list(object({
        side = string
        addr = string
      }))

    }))
  }))
}     
```



##### Mehrere Bridge Domains und EPGS
Werden mehrere BDs und EPGs benötigt, kann der Variable welche den Typ **list(object)** hat, einfach ein weiteres Object hinzugefügt werden. 

**!!!Das wird aber nicht im Modul erledigt, sondern in dem Terraform-Projekt in welchem das Modul eingebuden wird. Diese Variable wird dann dem Modul nur übergeben!!!**

Bsp:
1 x Bridge Domain: 

      
```
        "bridge_domains" = [
        {
          "bd_name"   = "bd-kunde123",
          "bd_subnet" = "192.168.1.1/24",

          "bd_unicast_route"   = "yes",
          "bd_type"            = "regular",
          "bd_arp_flood"       = "yes",
          "bd_unk_mac_unicast" = "flood",
          "subnet_scope"       = ["public", "shared"],
          "subnet_virtual"     = "no"
        }
      ]
```      
Bsp:
2 x Bridge Domain: 
```    

        "bridge_domains" = [
        {
          "bd_name"   = "bd-kunde123",
          "bd_subnet" = "192.168.1.1/24",

          "bd_unicast_route"   = "yes",
          "bd_type"            = "regular",
          "bd_arp_flood"       = "yes",
          "bd_unk_mac_unicast" = "flood",
          "subnet_scope"       = ["public", "shared"],
          "subnet_virtual"     = "no"
        },
        {
          "bd_name"   = "bd-kunde123-Server",
          "bd_subnet" = "192.168.2.1/24",

          "bd_unicast_route"   = "yes",
          "bd_type"            = "regular",
          "bd_arp_flood"       = "yes",
          "bd_unk_mac_unicast" = "flood",
          "subnet_scope"       = ["public", "shared"],
          "subnet_virtual"     = "no"
        }
      ]
```

## Anwendung 

Um das Modul zu verwenden muss es in das main.tf (oder dort wo es verwendet werden soll) eingebunden werden. Das Modul kann entweder local abgelegt oder von git aus eingebunde und verwendet werden. 
**-->**[Modul-Sources-Terraform](https://www.terraform.io/language/modules/sources)**<--**

##### Bsp: Anwendung des Moduls (local) in einem Terraform Projekt 
```
# Provider declaraion
terraform {
  required_providers {
    aci = {
      source = "CiscoDevNet/aci"
      version = "2.2.0"
    }
  }
}

# Provider configuration
provider "aci" {
  url      = var.aci_host
  username = var.aci_username
  password = var.aci_password
}

# Configure Variables for ACI-Tenant modul in terraform.tfvars file !!!

module "aci-tenat" {
  source            = "../../modules/aci-tenant"
  tenant_parameters = var.tenant_parameters

}
```

