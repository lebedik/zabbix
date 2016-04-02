if node['platform'] == 'centos'

hostname = node['fqdn']


if node.role?('db-server')
  metadataitem = 'db'
elsif node.role?('app-server')
  metadataitem = 'app'
elsif node.role?('web-server')
  metadataitem = 'web'
elsif node.role?('zabbix-srv')
  metadataitem = 'zbx'
end

execute 'zabbix_api_install' do
        command '/opt/chef/embedded/bin/gem install zabbixapi'
end

  if node['platform_version'].to_i >= 7
      zabbix_release = "#{Chef::Config[:file_cache_path]}/zabbix-release-3.0-1.el7.noarch.rpm"
      source = "http://repo.zabbix.com/zabbix/3.0/rhel/7/x86_64/zabbix-release-3.0-1.el7.noarch.rpm"
    else
      zabbix_release = "#{Chef::Config[:file_cache_path]}/zabbix-release-3.0-1.el7.noarch.rpm"
      source = "http://repo.zabbix.com/zabbix/3.0/rhel/6/x86_64/zabbix-release-3.0-1.el6.noarch.rpm"
    end


  remote_file zabbix_release do
    source source
    action :create_if_missing
  end

  rpm_package "zabbix-release" do
    source "#{zabbix_release}"
    action :install
    subscribes :install, "remote_file[#{zabbix_release}]"
  end

# Create host on zabbix server
ruby_block "create_host" do
  block do
require "zabbixapi"

zbx = ZabbixApi.connect(
  :url => "http://#{node['zabbix']['zabbixServerAddress']}/api_jsonrpc.php",
  :user => 'Admin',
  :password => 'zabbix'
)

# create group
if zbx.hostgroups.get_id(:name => "global-group") == nil
  Chef::Log.info ("================================")
  Chef::Log.info ("create global-group")
  Chef::Log.info ("================================")
  zbx.hostgroups.create(:name => "global-group")
end

# create hosts
Chef::Log.info ("================================")
Chef::Log.info ("================================")
Chef::Log.info ("================================")
Chef::Log.info (zbx.hosts.get_id(:host => "#{node['fqdn']}"))


if (zbx.hosts.get_id(:host => "#{node['fqdn']}")) != nil

  zbx.hosts.delete zbx.hosts.get_id(:host => "#{node['fqdn']}")

  zbx.hosts.create(
    :host => "#{node['fqdn']}",
    :interfaces => [
      {
        :type => 1,
        :main => 1,
        :ip => "#{node[:network][:interfaces][:eth1][:addresses].detect{|k,v| v[:family] == "inet" }.first}",
        :dns => "#{node['fqdn']}",
        :port => 10050,
        :useip => 1,
        :tls_connect => "2",
        :tls_accept => "2",
        :tls_psk_identity => "Team3",
        :tls_psk => "d374ff595cf8435bd3269c44176742d2db49d665892a4dbbfda998a2e6f50316"

      }
    ],
    :groups => [ :groupid => zbx.hostgroups.get_id(:name => "global-group") ]
  )

  zbx.templates.mass_add(
    :hosts_id => [zbx.hosts.get_id(:host => "#{node['fqdn']}")],
    :templates_id => [10001]
  )
  else
    zbx.hosts.create(
      :host => "#{node['fqdn']}",
      :interfaces => [
        {
          :type => 1,
          :main => 1,
          :ip => "#{node[:network][:interfaces][:eth1][:addresses].detect{|k,v| v[:family] == "inet" }.first}",
          :dns => "#{node['fqdn']}",
          :port => 10050,
          :useip => 1,
          :tls_connect => "2",
          :tls_accept => "2",
          :tls_psk_identity => "Team3",
          :tls_psk => "d374ff595cf8435bd3269c44176742d2db49d665892a4dbbfda998a2e6f50316"

        }
      ],
      :groups => [ :groupid => zbx.hostgroups.get_id(:name => "global-group") ]
    )

    zbx.templates.mass_add(
      :hosts_id => [zbx.hosts.get_id(:host => "#{node['fqdn']}")],
      :templates_id => [10001]
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
        :source => "<!--?xmlversion=\"1.0\"encoding=\"UTF-8\">?--><zabbix_export><version>3.0</version><date>2016-04-02T17:40:22Z</date><groups><group><name>global-group</name></group></groups><hosts><host><host>web.budapest.epam.com</host><name>web.budapest.epam.com</name><description/><proxy/><status>0</status><ipmi_authtype>0</ipmi_authtype><ipmi_privilege>2</ipmi_privilege><ipmi_username/><ipmi_password/><tls_connect>1</tls_connect><tls_accept>1</tls_accept><tls_issuer/><tls_subject/><tls_psk_identity/><tls_psk/><templates><template><name>TemplateOSLinux</name></template></templates><groups><group><name>global-group</name></group></groups><interfaces><interface><default>1</default><type>1</type><useip>1</useip><ip>192.168.33.113</ip><dns>web.budapest.epam.com</dns><port>10050</port><bulk>1</bulk><interface_ref>if1</interface_ref></interface></interfaces><applications/><items/><discovery_rules/><macros/><inventory/></host></hosts></zabbix_export>"    )

end



  end
  #ignore_failure true
end


  # execute "clear_cache" do
  #   command "/usr/bin/yum clean all"
  #   action :run
  # end

  yum_package "zabbix-agent"  do
    flush_cache [ :before ]
    action :install
  end

  service "zabbix-agent" do
    action [:enable, :nothing]
  end

  template '/etc/zabbix/zabbix_agentd.conf' do
    source "zabbix_agentd.conf.erb"
    mode '0640'
    owner 'zabbix'
    group 'zabbix'
    variables lazy { ({
      :metadataitem => metadataitem,
      :hostname => hostname,
      :server_ip => "#{node['zabbix']['zabbixServerAddress']}"
        }) }
    notifies :start, 'service[zabbix-agent]', :delayed
  end
end
