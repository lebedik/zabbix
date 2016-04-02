# local hash gathering different database options
mysql_opts = {
  :instance_name => 'zabbix',
  :admin_user => 'root',
  :admin_password => 'root123qwe',
  :zabbix_database => 'zabbix',
  :zabbix_user => 'zabbix',
  :zabbix_user_password => 'zabbix123qwe'
}
# connection hash to be used by database cookbook resources
admin_database_connection = {
  :host => '127.0.0.1',
  :socket => "/var/run/mysql-#{mysql_opts[:instance_name]}/mysqld.sock",
  :username => mysql_opts[:admin_user],
  :password => mysql_opts[:admin_password]
}
zabbix_database_connection = {
  :host => '127.0.0.1',
  :socket => "/var/run/mysql-#{mysql_opts[:instance_name]}/mysqld.sock",
  :username => mysql_opts[:zabbix_user],
  :password => mysql_opts[:zabbix_user_password]
}
# zabbix version to be used
zabbix_version = '3.0.1'

# install mysql service for zabbix
mysql_service mysql_opts[:instance_name] do
  port '3306'
  version '5.7'
  initial_root_password mysql_opts[:admin_password]
  mysqld_options(
    :innodb_file_per_table => 'ON'
  )
  action [:create, :start]
end

# prerequisite for database cookbook resources utilizing mysql provider
mysql2_chef_gem 'default' do
  action :install
end

# install epel and webtatic repositories for newer php versions to be available
{
  'epel' => 'https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm',
  'webtatic' => 'https://mirror.webtatic.com/yum/el6/latest.rpm'
}.each do |repo, url|
  package repo do
    source url
    provider Chef::Provider::Package::Rpm
    action :upgrade
  end
end
# install php and complementary packages
['php56w', 'php56w-gd', 'php56w-mysql', 'php56w-bcmath', 'php56w-mbstring', 'php56w-xml', 'php56w-ldap'].each do |pkg|
  package pkg
end
cookbook_file '/etc/php.d/zabbix.ini' do
  source 'zabbix.ini'
  owner 'root'
  group 'root'
  mode '0644'
end

# install zabbix
# create user and group
group 'zabbix' do
  system true
end
user 'zabbix' do
  group 'zabbix'
  system true
end
# download and extract zabbix archive
remote_file "#{Chef::Config[:file_cache_path]}/zabbix-#{zabbix_version}.tar.gz" do
  source "http://sourceforge.net/projects/zabbix/files/ZABBIX%20Latest%20Stable/#{zabbix_version}/zabbix-#{zabbix_version}.tar.gz/download"
  owner 'root'
  group 'root'
  checksum 'e91a8497bf635b96340988e2d9ca1bb3fac06e657b6596fa903c417a6c6b110b'
end
bash 'extract_zabbix_archive' do
  cwd Chef::Config[:file_cache_path]
  code "tar -zxf zabbix-#{zabbix_version}.tar.gz"
  action :run
  not_if { ::File.exists?("#{Chef::Config[:file_cache_path]}/zabbix-#{zabbix_version}") }
end
# import zabbix db schema, images and data only during initial database creation
['schema.sql', 'images.sql', 'data.sql'].each do |sql|
  bash "import_#{sql}" do
    cwd "#{Chef::Config[:file_cache_path]}/zabbix-#{zabbix_version}/database/mysql/"
    code <<-HEREDOC
      mysql \
        -h #{zabbix_database_connection[:host]} \
        -S #{zabbix_database_connection[:socket]} \
        -u #{zabbix_database_connection[:username]} \
        -p$\'#{zabbix_database_connection[:password]}\' \
        #{mysql_opts[:zabbix_database]} < #{sql}
    HEREDOC
    action :nothing
    subscribes :run, "mysql_database[#{mysql_opts[:zabbix_database]}]"
  end
end
# create database user for zabbix
mysql_database_user mysql_opts[:zabbix_user] do
  privileges [:all]
  database_name mysql_opts[:zabbix_database]
  table '*'
  host 'localhost'
  password mysql_opts[:zabbix_user_password]
  connection admin_database_connection
  action [:create, :grant]
end
# create database for zabbix
mysql_database mysql_opts[:zabbix_database] do
  connection admin_database_connection
  encoding 'utf8'
  collation 'utf8_bin'
  action :create
end
# install packages for zabbix compilation
[ 'gcc',
  'mysql-community-devel',
  'libxml2-devel',
  'unixODBC-devel',
  'net-snmp-devel',
  'libcurl-devel',
  'libssh2-devel',
  'OpenIPMI-devel',
  'openssl-devel',
  'openldap-devel' ].each do |pkg|
  package pkg
end
# compile zabbix
bash 'configure_zabbix' do
  cwd "#{Chef::Config[:file_cache_path]}/zabbix-#{zabbix_version}/"
  code <<-HEREDOC
  ./configure \
    --enable-server \
    --enable-agent \
    --with-mysql \
    --enable-ipv6 \
    --with-net-snmp \
    --with-libcurl \
    --with-libxml2 \
    --with-unixodbc \
    --with-ssh2 \
    --with-openipmi \
    --with-openssl
  HEREDOC
  not_if { ::File.file?('/usr/local/sbin/zabbix_server') }
end
bash 'install_zabbix' do
  cwd "#{Chef::Config[:file_cache_path]}/zabbix-#{zabbix_version}/"
  code 'make install'
  not_if { ::File.file?('/usr/local/sbin/zabbix_server') }
end
# import zabbix server configuration file
template '/usr/local/etc/zabbix_server.conf' do
  source 'zabbix_server.conf.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables({
    :db_host => zabbix_database_connection[:host],
    :db_name => mysql_opts[:zabbix_database],
    :db_user => zabbix_database_connection[:username],
    :db_password => zabbix_database_connection[:password],
    :db_socket => zabbix_database_connection[:socket]
  })
end

# create zabbix site
zabbix_site_dir = '/var/www/html/zabbix'
# copy files
bash 'copy_zabbix_files' do
  cwd "#{Chef::Config[:file_cache_path]}/zabbix-#{zabbix_version}/frontends/php/"
  code "mkdir #{zabbix_site_dir} && cp -a . #{zabbix_site_dir}/ && chmod +x #{zabbix_site_dir}/conf/ && chown -R #{node['apache']['user']}:#{node['apache']['group']} #{zabbix_site_dir}"
  not_if { ::File.file?("#{zabbix_site_dir}/zabbix.php") }
end
# create httpd site
web_app 'zabbix' do
  template 'zabbix.conf.erb'
  server_port 80
  template_variables({
    :document_root => zabbix_site_dir,
    :server_name => node['fqdn']
  })
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


['zabbix-java-gateway'].each do |pkg|
  package pkg
end

# install mod_php5
include_recipe 'apache2::mod_php5'

# enable zabbix services
['zabbix_server', 'zabbix_agentd'].each do |init_script|
  remote_file "/etc/init.d/#{init_script}" do
    owner 'root'
    group 'root'
    mode '0755'
    action :create
    source "file://#{Chef::Config[:file_cache_path]}/zabbix-#{zabbix_version}/misc/init.d/fedora/core/#{init_script}"
  end
  service init_script do
    action [:restart, :enable]
  end
end


service 'zabbix-java-gateway' do
  action [:start, :enable]
  ignore_failure true
end

# create zabbix application configuration file
template "#{zabbix_site_dir}/conf/zabbix.conf.php" do
  source 'zabbix.conf.php.erb'
  owner node['apache']['user']
  group node['apache']['group']
  mode '0644'
  variables({
    :server => zabbix_database_connection[:host],
    :database => mysql_opts[:zabbix_database],
    :user => zabbix_database_connection[:username],
    :password => zabbix_database_connection[:password],
    :socket => zabbix_database_connection[:socket],
    :zbx_server_name => node['fqdn']
  })
end
