if node['platform'] == 'centos'

hostname = node['fqdn']

# Install zabbixapi gem
execute 'zabbix_api_install' do
        command '/opt/chef/embedded/bin/gem install zabbixapi'
end

# Create host on zabbix server
ruby "create_host" do
code <<-EOH
require "zabbixapi"
        zbx = ZabbixApi.connect(
  :url => "http://#{node['zabbix']['zabbixServerAddress']}/api_jsonrpc.php",
  :user => 'Admin',
  :password => 'zabbix'
)
zbx.hosts.create_or_update(
  :host => "#{node['fqdn']}",
  :interfaces => [
    {
      :type => 1,
      :main => 1,
      :ip => "#{node['ipaddress']}",
      :dns => "#{node['fqdn']}",
      :port => 10050,
      :useip => 0
    }
  ],
  :groups => [ :groupid => zbx.hostgroups.get_id(:name => "db-test") ]
)
EOH
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

  # execute "clear_cache" do
  #   command "/usr/bin/yum clean all"
  #   action :run
  # end

  yum_package "zabbix-agent"  do
    flush_cache [ :before ]
    action :install
  end

  service "zabbix-agent" do
    action [:enable :nothing]
  end

  template '/etc/zabbix/zabbix_agentd.conf' do
    source "zabbix_agentd.conf.erb"
    mode '0640'
    owner 'zabbix'
    group 'zabbix'
    variables lazy { ({
      :hostname => hostname,
      :server_ip => "#{node['zabbix']['zabbixServerAddress']}"
        }) }
    notifies :restart, 'service[zabbix-agent]', :delayed
  end
end
