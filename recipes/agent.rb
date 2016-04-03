if node['platform'] == 'centos'

hostname = node['fqdn']
zabbix_srv_hostname = node['epc-provisioning']['instances'].find { |i| i[1]['role'] == 'zabbix-srv' }[1]['private_ip_address']


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
        command 'gem install zabbixapi'
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
  :url => "http://#{zabbix_srv_hostname}/api_jsonrpc.php",
  :user => 'Admin',
  :password => 'zabbix'
)

# create group
if zbx.hostgroups.get_id(:name => "global-group") == nil
  Chef::Log.info ("================================")
  Chef::Log.info ("create global-group")
  Chef::Log.info ("#{zabbix_srv_hostname}")
  Chef::Log.info ("================================")
  zbx.hostgroups.create(:name => "global-group")
end

# create hosts
Chef::Log.info ("================================")
Chef::Log.info (zbx.hosts.get_id(:host => "#{node['fqdn']}"))
Chef::Log.info ("================================")



if (zbx.hosts.get_id(:host => "#{node['fqdn']}")) != nil

  zbx.hosts.delete zbx.hosts.get_id(:host => "#{node['fqdn']}")

  zbx.hosts.create(
    :host => "#{node['fqdn']}",
    :interfaces => [
      {
        :type => 1,
        :main => 1,
        :ip => "#{node['ipaddress']}",
        :dns => "#{node['fqdn']}",
        :port => 10050,
        :useip => 1
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
          :ip => "#{node['ipaddress']}",
          :dns => "#{node['fqdn']}",
          :port => 10050,
          :useip => 1
        }
      ],
      :groups => [ :groupid => zbx.hostgroups.get_id(:name => "global-group") ]
    )

    zbx.templates.mass_add(
      :hosts_id => [zbx.hosts.get_id(:host => "#{node['fqdn']}")],
      :templates_id => [10001]
    )

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

 directory "#{node['zabbix']['agent']['HomeDir']}" do
  mode '0755'
  owner "zabbix"
  group "zabbix"
  action :create
 end

 file "#{node['zabbix']['agent']['TLSPSKFile']}" do
  owner "zabbix"
  group "zabbix"
  mode '0440'
  content "#{node['zabbix']['agent']['TLSPSKKey']}"
 end


  template '/etc/zabbix/zabbix_agentd.conf' do
    source "zabbix_agentd.conf.erb"
    mode '0640'
    owner 'zabbix'
    group 'zabbix'
    variables lazy { ({
      :metadataitem => metadataitem,
      :hostname => hostname,
      :server_ip => zabbix_srv_hostname,
      :TLSPSKIdentity => "#{node['zabbix']['agent']['TLSPSKIdentity']}",
      :TLSPSKFile => "#{node['zabbix']['agent']['TLSPSKFile']}",
      :encryption => "#{node['zabbix']['agent']['encryption']}"
        }) }
    notifies :restart, 'service[zabbix-agent]', :delayed
  end
end
