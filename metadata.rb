name 'zabbix'
maintainer 'The Authors'
maintainer_email 'you@example.com'
license 'all_rights'
description 'Installs/Configures zabbix'
long_description 'Installs/Configures zabbix'
version '0.2.0'

supports 'centos', '~> 6.7'

depends 'mysql', '~> 6.1.2'
depends 'database', '~> 4.0.9'
depends 'mysql2_chef_gem', '~> 1.0.2'
depends 'apache2', '~> 3.1.0'
