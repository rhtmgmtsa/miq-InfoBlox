# Copyright 2017 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Greg Jones <gjones@redhat.com>
#


required_gems = ["infoblox"]

# Make sure we can load gems in required_gems[] and load them
required_gems.each do | g |
  $evm.log(:info,"Checking if the ruby gem #{g} is available")
  begin
    gem "#{g}"
    require "#{g}"
  rescue Gem::LoadError
    $evm.log(:error, "ERROR: The ruby gem #{g} is not installed and/or cannot be loaded")
    exit MIQ_STOP
  rescue
    $evm.log(:error, "ERROR: An error occured checking for the ruby gem #{g}")
    exit MIQ_STOP
  end
end

# Get the values from the miq instance
hostname = nil || $evm.object['hostname']
username = nil || $evm.object['username']
password = nil || $evm.object.decrypt('password')

# leverage the infoblox gem to instantiate a connection
begin
  infoblox_connection = Infoblox::Connection.new(username: username, password: password, host: hostname, ssl_opts: {verify: false})
rescue Exception => e
  $evm.log(:error, "ERROR: Cannot create new connection to #{host}.\n #{e.message} \n #{e.backtrace.inspect}")
  exit MIQ_STOP
end


count = 0
network.each do |net|
  # Use the network_cidr to determine gateway and domain
  log(:info, "#{net[:network]}")
  network_cidr, netmask, gateway, domain, hostname = get_network("#{net[:network]}")
  network_infoblox = call_infoblox(:get)
  # only pull out the network and the _ref values
  network_infoblox_hash = Hash[*network_infoblox['value'].collect { |x| [x['network'], x['_ref'][0]] }.flatten]
  raise "network_infoblox_hash returned nil" if network_infoblox_hash.nil?
  log(:info, "Inspecting network_infoblox_hash:<#{network_infoblox_hash}>")

  # call Infoblox to get the next available IP Address
  # query for the next available IP address

  body_get_nextip = {:_function => 'next_available_ip', :num => '1'}
  next_ip = call_infoblox(:post, network_infoblox_hash[network_cidr], nil, body_get_nextip)
  log(:info, "#{next_ip}")

  #get the IP Address returned from Infoblox
  ipaddr = next_ip['ips'][0]['list'][0]['value'].first
  log(:info, "Found next_ip:<#{ipaddr}>")

  body_set_recordhost = {
    :name => "#{hostname}.#{domain}",
    :ipv4addrs =>[ {
      :ipv4addr => "#{ipaddr}",
      :configure_for_dhcp => false } ],
    }

  record_host = call_infoblox(:post, 'record:host', :json, body_set_recordhost)
  log(:info, "Infoblox returned record_host:<#{record_host}>")

  $evm.log("info", "GetIP --> NIC = #{netcount}")
  $evm.log("info", "GetIP --> IP Address =  #{ipaddr}")
  $evm.log("info", "GetIP -->  Netmask = #{netmask}")
  $evm.log("info", "GetIP -->  Gateway = #{gateway}")
  $evm.log("info", "GetIP -->  dnsname = #{}")

  prov.set_option(:sysprep_spec_override, 'true')

  if netcount == 0
    prov.set_nic_settings('#{count}', {:ip_addr=>ipaddr, :subnet_mask=>netmask, :gateway=>gateway, :addr_mode=>["static", "Static"]})
  else
    prov.set_nic_settings('#{count}', {:ip_addr=>ipaddr, :subnet_mask=>netmask, :addr_mode=>["static", "Static"]})
  end
  #log(:info, "Provision object updated: [:ip_addr=>#{prov.options[:ip_addr].inspect},:subnet_mask=>#{prov.options[:subnet_mask].inspect},:gateway=>#{prov.options[:gateway].inspect},:addr_mode=>#{prov.options[:addr_mode].inspect}]")
  $evm.log("info", "GetIP --> #{prov.inspect}")

  count += 1
end
