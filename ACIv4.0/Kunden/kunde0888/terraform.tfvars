# ACI-Provider information
aci_host     = "https://10.81.79.71/"
aci_username = "terraform"
aci_password = "sJUT+0e2ZGoB"


#######################################################################################
# Do only edit Variables which are borderd with Hashtags like the message inside here #
#######################################################################################

# Data for Tenant 
  tenant_parameters = [
    {
      "tenant_name" = "kunde0888"
      "cloudId"     = "888"
      "bridge_domains" = [
        {
          ####################################
          "bd_name"   = "bd-kunde0888",
          "bd_subnet" = "192.168.88.1/24",
          ####################################
          "bd_unicast_route"   = "yes",
          "bd_type"            = "regular",
          "bd_arp_flood"       = "yes",
          "bd_unk_mac_unicast" = "flood",
          "subnet_scope"       = ["public", "shared"],
          "subnet_virtual"     = "no"
        }
      ]
      "epgs" = [
        {
        ###############################
        "epg_name"   = "epg-kunde0888",
        "epg_ref_bd" = "bd-kunde0888",
        ###############################
        "pref_gr_member" = "exclude",
        "prio"           = "level3",
        "pc_enf_pref"    = "unenforced",
        "flood_on_encap" = "disabled"
        "static_ports" = [
          {
            "port_path"    = "topology/pod-1/protpaths-1101-1102/pathep-[ACI-Host-SIM-1]",
            ###############################
            "encap"        = "vlan-888",
            ###############################
            "mode"         = "regular",
            "instr_imedcy" = "immediate"
          },
          {
            "port_path"    = "topology/pod-2/protpaths-2101-2102/pathep-[ACI-Host-SIM-2]",
            ###############################
            "encap"        = "vlan-888",
            ###############################
            "mode"         = "regular",
            "instr_imedcy" = "immediate"
          }
        ]
        }]
      "l3nodes" = [
        {
        "node_name" : "l3Node-1101",
        "node_path" : "topology/pod-1/node-1101",
        "rtr_id" : "100.65.110.1",
        "rtr_id_loop_back" : "yes"
        },
        {
          "node_name" : "l3Node-1102",
          "node_path" : "topology/pod-1/node-1102",
          "rtr_id" : "100.65.110.2",
          "rtr_id_loop_back" : "yes"
        },
        {
          "node_name" : "l3Node-2101",
          "node_path" : "topology/pod-2/node-2101",
          "rtr_id" : "100.65.210.1",
          "rtr_id_loop_back" : "yes"
        },
        {
          "node_name" : "l3Node-2102",
          "node_path" : "topology/pod-2/node-2102",
          "rtr_id" : "100.65.210.2",
          "rtr_id_loop_back" : "yes"
      }]
      "l3outSvi" = [
        {
        "path" = "topology/pod-1/protpaths-1101-1102/pathep-[rtAUCSipsec-8500fr2]",
        "addr" = "0.0.0.0"
        "members" = [
          {
            "side" = "A"
            "addr" = "100.66.115.2/24"
          },
          {
            "side" = "B"
            "addr" = "100.66.115.3/24"

        }]

        }, 
        {
        "path" = "topology/pod-2/protpaths-2101-2102/pathep-[rtAUCSipsec-8500fr4]",
        "addr" = "0.0.0.0"
        "members" = [
          {
            "side" = "A"
            "addr" = "100.66.115.5/24"
          },
          {
            "side" = "B"
            "addr" = "100.66.115.6/24"
        }]
      }]
    }
  ]
