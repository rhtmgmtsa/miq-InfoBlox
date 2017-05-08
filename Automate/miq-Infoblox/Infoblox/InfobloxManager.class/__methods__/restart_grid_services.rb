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

begin
  grid = Infoblox::Grid.get(infoblox_connection)
  ref = grid[0].restartservices(member_order = "SEQUENTIALLY",restart_option = "RESTART_IF_NEEDED", sequential_delay = 10, service_option = "DHCP")
  $evm.log(:info, "Restarted Infoblox DHCP Grid Services")
rescue Exception => e
  $evm.log(:error, "ERROR: Problem restarting Grid Services. \n #{e.message} \n #{e.backtrace.inspect}")
end
