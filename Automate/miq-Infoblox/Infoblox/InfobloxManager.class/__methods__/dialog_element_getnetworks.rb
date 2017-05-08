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
  infoblox_connection = Infoblox::Connection.new(username: username, password: password, host: hostname)
rescue Exception => e
  $evm.log(:error, "ERROR: Cannot create new connection to #{host}.\n #{e.message} \n #{e.backtrace.inspect}")
  exit MIQ_STOP
end

# get all of the networks
begin
  networks = Infoblox::Network.all(infoblox_connection, {_max_results: 9999, _return_fields: })
rescue Exception => e
  $evm.log(:error, "ERROR: cannot get Infoblox networks. \n #{e.message} \n #{e.backtrace.inspect}")
  exit MIQ_STOP
end

# build the dialog values hash
begin
  dialog_values_hash = {}
  networks.each do |n|
    dialog_values_hash[n._ref] = n.networks
  end

  list_values = {
     'sort_by'    => :value,
     'data_type'  => :string,
     'required'   => false,
     'values'     => dialog_values_hash
  }
  list_values.each { |key, value| $evm.object[key] = value }

  log(:info, "Dynamic Element values: #{$evm.object['values']}")

  return $evm.object['values']

rescue Exception => e
  $evm.log(:error, "ERROR: Cannot build dialog values hash.\n e.message \n e.backtrace.inspect")
end
