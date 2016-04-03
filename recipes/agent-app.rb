if node['platform'] == 'centos'

hostname = node['fqdn']
zabbix_srv_hostname = search('node', "name:zabbix-srv").first['ipaddress']

if node.role?('db-server')
  metadataitem = 'db'
elsif node.role?('app-server')
  metadataitem = 'app'
elsif node.role?('web-server')
  metadataitem = 'web'
elsif node.role?('zabbix-srv')
  metadataitem = 'zbx'
end

gem_package 'zabbixapi' do
  gem_binary '/opt/chef/embedded/bin/gem'
  action :install
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
        :url => "http://#{zabbix_srv_hostname}/api_jsonrpc.php",
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
    idtemp = [10001, zbx.templates.get_id(:host => "d_Tomcat_jmx")]
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
        :ip => "#{node['ipaddress']}",
        :dns => "#{node['fqdn']}",
        :port => 10050,
        :useip => 1
      },
      {
        :type => 4,
        :main => 1,
        :ip => "#{node['ipaddress']}",
        :dns => "#{node['fqdn']}",
        :port => 8090,
        :useip => 1
      }
    ],
    :groups => [ :groupid => zbx.hostgroups.get_id(:name => "#{metadataitem}") ]
  )
  zbx.templates.mass_add(
    :hosts_id => [zbx.hosts.get_id(:host => "#{node['fqdn']}")],
    :templates_id => idtemp
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
          :ip => "#{node['ipaddress']}",
          :dns => "#{node['fqdn']}",
          :port => 10050,
          :useip => 1
        },
        {
          :type => 4,
          :main => 1,
          :ip => "#{node['ipaddress']}",
          :dns => "#{node['fqdn']}",
          :port => 8090,
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

 directory '/etc/zabbix/scripts' do
  owner 'zabbix'
  group 'zabbix'
  mode 00755
  recursive true
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
      :server_ip => "#{zabbix_srv_hostname}",
      :TLSPSKIdentity => "#{node['zabbix']['agent']['TLSPSKIdentity']}",
      :TLSPSKFile => "#{node['zabbix']['agent']['TLSPSKFile']}",
      :encryption => "#{node['zabbix']['agent']['encryption']}"
        }) }
    notifies :restart, 'service[zabbix-agent]', :delayed
  end

   # Add apache status config
  if node.role?('web-server')
    cookbook_file '/etc/httpd/sites-enabled/000_apache_status.conf' do
      source '000-apache-status.conf'
      owner 'apache'
      group 'apache'
      mode 00644
      notifies :restart, 'service[zabbix-agent]', :delayed
    end

    directory '/etc/zabbix/scripts' do
      owner 'zabbix'
      group 'zabbix'
      mode 00755
      recursive true
      action :create
      notifies :restart, 'service[zabbix-agent]', :delayed
    end

    cookbook_file '/etc/zabbix/scripts/zapache' do
      source 'zapache'
      owner 'zabbix'
      group 'zabbix'
      mode 00755
      notifies :restart, 'service[zabbix-agent]', :delayed
    end

    cookbook_file '/etc/zabbix/zabbix_agentd.d/userparameter_zapache.conf' do
      source 'userparameter_zapache.conf'
      owner 'zabbix'
      group 'zabbix'
      mode 00644
      notifies :restart, 'service[zabbix-agent]', :delayed
    end
  end
end
