# Install zabbixapi gem
execute 'zabbix_api_install' do
  command '/opt/chef/embedded/bin/gem install zabbixapi'
end


cookbook_file "#{Chef::Config[:file_cache_path]}/linux_os.xml" do
  source 'linux_os.xml'
  action :create
end


ruby "import_template" do
code <<-EOH
require "zabbixapi"
zbx = ZabbixApi.connect(
  :url => "http://#{node['zabbix']['zabbixServerAddress']}/api_jsonrpc.php",
  :user => 'Admin',
  :password => 'zabbix'
)
zbx.configurations.import(
    :format => "xml",
    :rules => {
        :templates => {
            :createMissing => true,
            :updateExisting => true
        },
        :items => {
            :createMissing => true,
            :updateExisting => true
        }
    },
:source => "#{Chef::Config[:file_cache_path]}/linux_os.xml"
)
EOH
end
