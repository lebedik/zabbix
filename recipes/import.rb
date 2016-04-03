# Install zabbixapi gem
execute 'zabbix_api_install' do
  command '/opt/chef/embedded/bin/gem install zabbixapi'
end


cookbook_file "#{Chef::Config[:file_cache_path]}/linux_os.xml" do
  source 'linux_os.xml'
  action :create
end


ruby_block "import_template" do
block do
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
          }
    },
:source => File.read("#{Chef::Config[:file_cache_path]}/linux_os.xml")
)
zbx.configurations.import(
    :format => "xml",
    :rules => {
      :templates => {
          :createMissing => true,
          :updateExisting => true
      },
      :applications => {
          :createMissing => true,
          :updateExisting => true
      }
    },
:source => File.read("#{Chef::Config[:file_cache_path]}/linux_os.xml")
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
:source => File.read("#{Chef::Config[:file_cache_path]}/linux_os.xml")
)
zbx.configurations.import(
    :format => "xml",
    :rules => {
      :templates => {
          :createMissing => true,
          :updateExisting => true
      },
      :triggers => {
          :createMissing => true,
          :updateExisting => true
      }
    },
:source => File.read("#{Chef::Config[:file_cache_path]}/linux_os.xml")
)
zbx.configurations.import(
    :format => "xml",
    :rules => {
      :templates => {
          :createMissing => true,
          :updateExisting => true
      },
      :graphs => {
          :createMissing => true,
          :updateExisting => true
      }
    },
:source => File.read("#{Chef::Config[:file_cache_path]}/linux_os.xml")
)
zbx.configurations.import(
    :format => "xml",
    :rules => {
      :templates => {
          :createMissing => true,
          :updateExisting => true
      },
      :screens => {
          :createMissing => true,
          :updateExisting => true
      }
    },
:source => File.read("#{Chef::Config[:file_cache_path]}/linux_os.xml")
)
zbx.configurations.import(
    :format => "xml",
    :rules => {
      :templates => {
          :createMissing => true,
          :updateExisting => true
      },
      :discoveryRules => {
          :createMissing => true,
          :updateExisting => true
      }
    },
:source => File.read("#{Chef::Config[:file_cache_path]}/linux_os.xml")
)
  end
end
