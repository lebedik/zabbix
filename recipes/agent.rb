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

  ruby_block "find_id_template_and_create" do
    block do

      require "zabbixapi"
      zbx = ZabbixApi.connect(
        :url => "http://#{node['zabbix']['zabbixServerAddress']}/api_jsonrpc.php",
        :user => 'Admin',
        :password => 'zabbix'
      )

      zbx.templates.get_id(:host => "d_Mysql_template")
      zbx.templates.get_id(:host => "d_Tomcat_jmx")


  if node.role?('db-server')
    metadataitem = 'db'
    idtemp = [10001, zbx.templates.get_id(:host => "d_Mysql_template")]
  elsif node.role?('app-server')
    metadataitem = 'app'
    idtemp = [10001]
  elsif node.role?('web-server')
    metadataitem = 'web'
    idtemp = [10001]
  elsif node.role?('zabbix-srv')
    metadataitem = 'zbx'
  end

        Chef::Log.info ("================================")
        Chef::Log.info (idtemp)
        Chef::Log.info ("================================")

# Create host on zabbix server


# create group
if zbx.hostgroups.get_id(:name => "#{metadataitem}") == nil
  Chef::Log.info ("================================")
  Chef::Log.info ("Create #{metadataitem} group")
  Chef::Log.info ("================================")
  zbx.hostgroups.create(:name => "#{metadataitem}")
end

# create hosts
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
        :useip => 1
      }
    ],
    :groups => [ :groupid => zbx.hostgroups.get_id(:name => "#{metadataitem}") ]
  )

  zbx.templates.mass_add(
    :hosts_id => [zbx.hosts.get_id(:host => "#{node['fqdn']}")],
    :templates_id => idtemp
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
          :useip => 1
        }
      ],
      :groups => [ :groupid => zbx.hostgroups.get_id(:name => "#{metadataitem}") ]
    )

    zbx.templates.mass_add(
      :hosts_id => [zbx.hosts.get_id(:host => "#{node['fqdn']}")],
      :templates_id => idtemp
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
      :server_ip => "#{node['zabbix']['zabbixServerAddress']}",
      :TLSPSKIdentity => "#{node['zabbix']['agent']['TLSPSKIdentity']}",
      :TLSPSKFile => "#{node['zabbix']['agent']['TLSPSKFile']}",
      :encryption => "#{node['zabbix']['agent']['encryption']}"
        }) }
    notifies :restart, 'service[zabbix-agent]', :delayed
  end
end
