terraform {
  required_version = ">= 1.1.9"
  required_providers {
    aci = {
      source = "CiscoDevNet/aci"
      version = "2.2.0"
    }
  }

}

# Durchloppen und den epgs jeweils den bd name hinzufügen 

locals {
  bd_tenant_parameters = flatten([for tenant in var.tenant_parameters : [for brDom in tenant.bridge_domains : brDom]])
  epg_tenant_parameters = flatten([for tenant in var.tenant_parameters : [for epgs in tenant.epgs : epgs]])
  ports_epg_parameters = flatten([for tenant in var.tenant_parameters : [for key, epg in tenant.epgs : [for k, port in epg.static_ports : merge(epg.static_ports[k], { ref_epg_name = "${tenant.epgs[key].epg_name}" })]]])
  l3node_tenant_parameters = flatten([for tenant in var.tenant_parameters : [for l3node in tenant.l3nodes : l3node]])
  l3outSvi_tenant_parameters = flatten([for tenant in var.tenant_parameters : [for l3Svi in tenant.l3outSvi : l3Svi]])
  l3SviMembers_tenant_parameters= flatten([for tenant in var.tenant_parameters : [for key, l3Svi in tenant.l3outSvi : [for k, member in l3Svi.members : merge(l3Svi.members[k], {ref_svi_path ="${tenant.l3outSvi[key].path}"})]]])

  var1 = floor(var.tenant_parameters[0].cloudId/256) 
  var2 = floor(var.tenant_parameters[0].cloudId%256)
  ospf_areaId = format("0.0.%d.%d", local.var1, local.var2)
  
}

# Wenn ja dann nutze wert in dem beide Domains sind wenn nein dann nur normal ( dazu beide domains in liste oedr so zusammenführen)
data "aci_physical_domain" "pd_domain" {
  name = "pdAUCS"
}

data "aci_physical_domain" "pd_domain_ipsec" {
  name = "pdAUCS-ipsec"
}

data "aci_contract" "default" {
  tenant_dn = data.aci_tenant.common.id
  name      = "default"
}

data "aci_tenant" "common" {
  name = "common"
}

data "aci_l3_domain_profile" "l3domain" {
  name = "l3out-ipsec-domain"
}

data "aci_tenant" "AUCS-FW" {
  name = "AUCS-FW"
}

data "aci_contract" "AUCS-FW-L3out" {
  tenant_dn = data.aci_tenant.AUCS-FW.id
  name      = "AUCS-FW-L3out"
}


# Tenant
resource "aci_tenant" "tenantLocalName" {
  for_each = { for inst in var.tenant_parameters : inst.tenant_name => inst }
  name     = each.value.tenant_name

}

# VRF
resource "aci_vrf" "vrfLocalName" {
  for_each  = { for inst in var.tenant_parameters : "vrf-${inst.cloudId}" => inst }
  tenant_dn = aci_tenant.tenantLocalName[each.value.tenant_name].id
  name      = "vrf-${each.value.cloudId}"

}

# Bridge Domain
resource "aci_bridge_domain" "bdLocalName" {
  for_each           = { for brDom in local.bd_tenant_parameters : brDom.bd_name => brDom }
  tenant_dn          = aci_tenant.tenantLocalName[var.tenant_parameters[0].tenant_name].id
  relation_fv_rs_ctx = aci_vrf.vrfLocalName["vrf-${var.tenant_parameters[0].cloudId}"].id
  relation_fv_rs_bd_to_out = [aci_l3_outside.l3_outside["l3out-ipsec-${var.tenant_parameters[0].cloudId}"].id]
  name               = each.value.bd_name
  unicast_route      = each.value.bd_unicast_route
  bridge_domain_type = each.value.bd_type
  arp_flood          = each.value.bd_arp_flood
  unk_mac_ucast_act  = each.value.bd_unk_mac_unicast
  depends_on               = [aci_l3_outside.l3_outside]

}

# Subnet (Netz was Kunde bei uns in der Cloud hat)
resource "aci_subnet" "bdLocalSubnet" {
  for_each    = { for brDom in local.bd_tenant_parameters : "subnet-${brDom.bd_name}" => brDom }
  parent_dn   = aci_bridge_domain.bdLocalName[each.value.bd_name].id
  description = "Customer Subnet in AU-Cloud"
  ip          = each.value.bd_subnet
  scope       = each.value.subnet_scope
  virtual     = each.value.subnet_virtual
}

# Application Profile 
resource "aci_application_profile" "apLocalName" {
  for_each  = { for inst in var.tenant_parameters : "ap-${inst.tenant_name}" => inst }
  tenant_dn = aci_tenant.tenantLocalName[each.value.tenant_name].id
  name      = "ap-${each.value.tenant_name}"
}

# EPG
resource "aci_application_epg" "epgLocalName" {
  for_each           = { for epg in local.epg_tenant_parameters : epg.epg_name => epg }
  relation_fv_rs_bd      = aci_bridge_domain.bdLocalName[each.value.epg_ref_bd].id
  application_profile_dn = aci_application_profile.apLocalName["ap-${var.tenant_parameters[0].tenant_name}"].id
  name                   = each.value.epg_name
  flood_on_encap         = each.value.flood_on_encap
  pref_gr_memb           = each.value.pref_gr_member
  prio                   = each.value.prio
  pc_enf_pref            = each.value.pc_enf_pref

}

# Assing EPG to Physical Domain
resource "aci_epg_to_domain" "epgToPD" {
  for_each           = { for epg in local.epg_tenant_parameters : "pd-${epg.epg_name}" => epg }
  application_epg_dn = aci_application_epg.epgLocalName[each.value.epg_name].id
  tdn                = data.aci_physical_domain.pd_domain.id
  


}

# Static Ports to Epg 
resource "aci_epg_to_static_path" "epgToPath" {
  for_each           = { for port in local.ports_epg_parameters : "${port.ref_epg_name}-${port.port_path}" => port }
  application_epg_dn = aci_application_epg.epgLocalName[each.value.ref_epg_name].id
  tdn                = each.value.port_path
  encap              = each.value.encap
  instr_imedcy       = each.value.instr_imedcy
  mode               = each.value.mode
}

#### Contracts ####
# Epg to contract ( with Contract Interface not possible so far. Will be enabled in next provider release)
resource "aci_epg_to_contract" "epgToContract" {
  for_each           = { for epg in local.epg_tenant_parameters : "contract-default-${epg.epg_name}" => epg }
  application_epg_dn = aci_application_epg.epgLocalName["${each.value.epg_name}"].id
  contract_dn        = data.aci_contract.default.id
  contract_type      = "provider"
  annotation         = "terraform"
  match_t            = "AtleastOne"
  prio               = "unspecified"
}

#  Import Contract from AUCS-FW (not working so far)
resource "aci_imported_contract" "contract_interface" {
  for_each  = { for tenant in var.tenant_parameters : "contract-import-${tenant.cloudId}" => tenant }
  tenant_dn         = aci_tenant.tenantLocalName[each.value.tenant_name].id
  name              = "contract-internet-fp"
  annotation        = "tag_imported_contract"
  description       = "from terraform"
  relation_vz_rs_if = data.aci_contract.AUCS-FW-L3out.id
}

resource "aci_epg_to_contract_interface" "example" {
  for_each           = { for epg in local.epg_tenant_parameters : "internet-${epg.epg_name}" => epg }
  application_epg_dn = aci_application_epg.epgLocalName["${each.value.epg_name}"].id
  contract_interface_dn = aci_imported_contract.contract_interface["contract-import-${var.tenant_parameters[0].cloudId}"].id
  prio = "unspecified"

}


#### L3Out ####
# L3out Outside 
resource "aci_l3_outside" "l3_outside" {
  for_each  = { for tenant in var.tenant_parameters : "l3out-ipsec-${tenant.cloudId}" => tenant }
  tenant_dn              = aci_tenant.tenantLocalName[each.value.tenant_name].id
  relation_l3ext_rs_ectx = aci_vrf.vrfLocalName["vrf-${each.value.cloudId}"].id
  #relation_l3ext_rs_l3_dom_att = "uni/l3dom-l3out-ipsec-${each.value.vlan-id}-domain"
  #relation_l3ext_rs_l3_dom_att = aci_l3_domain_profile.l3dPlocal["l3out-ipsec-${each.value.cloud-id}-domain"].id
  relation_l3ext_rs_l3_dom_att = data.aci_l3_domain_profile.l3domain.id
  name                         = "l3out-ipsec-${each.value.cloudId}"
}

# External EPG with Contract
resource "aci_external_network_instance_profile" "exEpgLocalName" {
  for_each  = { for tenant in var.tenant_parameters : "l3ext-${tenant.cloudId}" => tenant }
  l3_outside_dn       = aci_l3_outside.l3_outside["l3out-ipsec-${each.value.cloudId}"].id
  name                = "l3ext-${each.value.cloudId}"
  pref_gr_memb        = "exclude"
  relation_fv_rs_cons = [data.aci_contract.default.id]
}

# L3-External-Subnet 0.0.0.0/0 for all nets
resource "aci_l3_ext_subnet" "subnetAlocalName" {
  for_each  = { for tenant in var.tenant_parameters : "l3subnet-${tenant.cloudId}" => tenant }
  external_network_instance_profile_dn = aci_external_network_instance_profile.exEpgLocalName["l3ext-${each.value.cloudId}"].id
  ip                                   = "0.0.0.0/0"
  # scope =["import-rtctrl"]
  # relation_l3ext_rs_subnet_to_profile{
  #   tn_rtctrl_profile_dn = aci_external_network_instance_profile.exEpgLocalName["l3ext-${each.value.vlan-id}"].id
  #   direction = "import"
  # }
}

# L3-Node-Profile
resource "aci_logical_node_profile" "nodeProfilelocalName" {
  for_each  = { for tenant in var.tenant_parameters : "l3out-ipsec-${tenant.cloudId}-nodeProfile" => tenant }
  l3_outside_dn = aci_l3_outside.l3_outside["l3out-ipsec-${each.value.cloudId}"].id
  name          = "l3out-ipsec-${each.value.cloudId}_nodeProfile"
}

# Nodes for L3-Node-Profile 
resource "aci_logical_node_to_fabric_node" "nodeLocalName" {
  for_each                = { for l3node in local.l3node_tenant_parameters : "${l3node.node_name}-${var.tenant_parameters[0].tenant_name}-${var.tenant_parameters[0].cloudId}" => l3node }
  logical_node_profile_dn = aci_logical_node_profile.nodeProfilelocalName["l3out-ipsec-${var.tenant_parameters[0].cloudId}-nodeProfile"].id
  tdn              = each.value.node_path
  rtr_id           = each.value.rtr_id
  rtr_id_loop_back = each.value.rtr_id_loop_back
}

# Logical-Interface-Profile for L3-Node-Profile 
resource "aci_logical_interface_profile" "intPlocalName" {
  for_each  = { for tenant in var.tenant_parameters : "l3out-ipsec-${tenant.cloudId}-interfaceProfile" => tenant }
  logical_node_profile_dn = aci_logical_node_profile.nodeProfilelocalName["l3out-ipsec-${each.value.cloudId}-nodeProfile"].id
  name                    = "l3out-ipsec-${each.value.cloudId}_interfaceProfile"
}

# L3out-OSPF-Policy  Area_id is cloudID modulo 256 = 888/256 = 3 rest 120 => 0.0.3.120
resource "aci_l3out_ospf_external_policy" "L3OutOSPFextPolicy" {
  for_each  = { for tenant in var.tenant_parameters : "l3out-ospf-${tenant.cloudId}" => tenant }
  # l3_outside_dn  = "uni/tn-kunde0815/out-l3out-ipsec-${each.value.cloud-id}"
  l3_outside_dn     = aci_l3_outside.l3_outside["l3out-ipsec-${each.value.cloudId}"].id
  area_id           = local.ospf_areaId
  annotation        = "example"
  description       = "from terraform"
  area_cost         = "1"
  area_ctrl         = ["redistribute", "summary"]
  area_type         = "regular"
  multipod_internal = "no"
}

# L3out-ospf-interface-profile 
resource "aci_l3out_ospf_interface_profile" "L3Out-OPSF-interface-profile" {
  for_each  = { for tenant in var.tenant_parameters : "ospf-interface-${tenant.cloudId}-profile" => tenant }
  logical_interface_profile_dn = aci_logical_interface_profile.intPlocalName["l3out-ipsec-${each.value.cloudId}-interfaceProfile"].id
  description                  = "from terraform"
  annotation                   = "example"
  auth_key                     = "key"
  auth_key_id                  = "1"
  auth_type                    = "none"
  name_alias                   = "example"
  #relation_ospf_rs_if_pol      = aci_ospf_interface_policy.fooospf_interface_policy["ospf-${each.value.cloud-id}-policy"].id
}

# SVI l3out_path_attachment
resource "aci_l3out_path_attachment" "l3outPathAttachment" {
  for_each                = { for l3Svi in local.l3outSvi_tenant_parameters : "svi-${l3Svi.path}-${var.tenant_parameters[0].cloudId}" => l3Svi }
  logical_interface_profile_dn = aci_logical_interface_profile.intPlocalName["l3out-ipsec-${var.tenant_parameters[0].cloudId}-interfaceProfile"].id
  target_dn                    = each.value.path
  addr                         = each.value.addr
  encap                        = format("vlan-1%d",var.tenant_parameters[0].cloudId)
  if_inst_t                    = "ext-svi"
  description                  = "from terraform"
  annotation                   = "example"
  autostate                    = "disabled"
  encap_scope                  = "ctx"
  ipv6_dad                     = "enabled"
  ll_addr                      = "::"
  mode                         = "regular"
  mtu                          = "1500"
  target_dscp                  = "unspecified"
}

# L3out-vpc-member side A side B
resource "aci_l3out_vpc_member" "l3out_vpc_member" {
  for_each                = { for l3member in local.l3SviMembers_tenant_parameters : "svi-${l3member.side}-${l3member.ref_svi_path}-${var.tenant_parameters[0].cloudId}" => l3member }
  leaf_port_dn = aci_l3out_path_attachment.l3outPathAttachment["svi-${each.value.ref_svi_path}-${var.tenant_parameters[0].cloudId}"].id
  side         = each.value.side
  addr         = each.value.addr
  annotation   = "example"
  ipv6_dad     = "enabled"
  ll_addr      = "::"
  description  = "from terraform"
  name_alias   = "example"
}