variable "aci_username" {
  type      = string
  sensitive = true
}

variable "aci_password" {
  type      = string
  sensitive = true
}

variable "aci_host" {
  type = string
}

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



