# This will install Apache Cassandra and can be used to manage multiple clusters.
include_recipe "java"
include_recipe "collectd"
include_recipe "monit"

# Grab some useful functions from our libraries.
class ::Chef::Recipe
  include ::CassandraHelpers
end

what_cluster?()

package "#{node[:cassandra][:Package]}" do
  action :install
  version node[:cassandra][:Version]
end

package "#{node[:cassandra][:DSC][:Package]}" do
  action :install
  version node[:cassandra][:DSC][:Version]
end

# Drop the JNA Jar.
remote_file "/usr/share/cassandra/lib/jna.jar" do
  source "http://java.net/projects/jna/sources/svn/content/trunk/jnalib/dist/jna.jar?rev=1193"
  owner "cassandra"
  group "cassandra"
  mode "0755"
  not_if do
    File.exists?("/usr/share/cassandra/lib/jna.jar")
  end
end

# Drop MX4J jar.
bash "installMX4J" do
user "root"
  cwd "/tmp"
  code <<-EOH
    wget http://sourceforge.net/projects/mx4j/files/MX4J%20Binary/3.0.2/mx4j-3.0.2.tar.gz/download
    tar zxvf mx4j-3.0.2.tar.gz mx4j-3.0.2/lib/mx4j-tools.jar
    cp mx4j-3.0.2/lib/mx4j-tools.jar /usr/share/cassandra/lib/
    chown cassandra:cassandra /usr/share/cassandra/lib/mx4j-tools.jar
    chmod 755 /usr/share/cassandra/lib/mx4j-tools.jar
  EOH
  ignore_failure true
  not_if do
    File.exists?("/usr/share/cassandra/lib/mx4j-tools.jar")
  end
end

service "cassandra" do
  supports :status => true, :start => true, :stop => true, :restart => true, :reload => true
end

create_cassandra_directories()
setup_cassandra_disks()

# Drop the config.
template "/etc/cassandra/conf/cassandra-env.sh" do
  owner "cassandra"
  group "cassandra"
  mode "0755"
  source "cassandra-env.sh.erb"
end

topology = build_cassandra_topology()

template "/etc/cassandra/conf/cassandra-topology.properties" do
  owner "cassandra"
  group "cassandra"
  mode "0755"
  source "cassandra-topology.properties.erb"
  variables(:t => topology)
end

node.normal[:cassandra][:seeds] = get_cluster_seeds()

template "/etc/cassandra/conf/cassandra.yaml" do
  owner "cassandra"
  group "cassandra"
  mode "0755"
  source "cassandra.yaml.erb"
end

# Drop a custom init script.
cookbook_file "/etc/init.d/cassandra" do
  source "cassandra.init"
  mode "0755"
  owner "root"
  group "root"
end

s = discover_cassandra_schema()

node.normal[:cassandra][:Keyspaces] = s if s

template "/outbrain/cassandra/cassandra-maintenance.sh" do
  source "cassandra-maintenance.sh.erb"
  mode "0775"
  owner "root"
  group "root"
  ignore_failure true
end

template "/etc/collectd/collectd.d/cassandra.conf" do
  owner "cassandra"
  group "cassandra"
  mode "0644"
  source "cassandra.conf.erb"
  notifies :restart, "service[collectd]"
  ignore_failure true
end

maint_window = calculate_maintenance_window()

cron "Cassandra Maintence" do
  weekday "#{maint_window['day']}"
  hour "#{maint_window['hour']}"
  minute "0"
  command '/usr/local/bin/cassandra-maintenance.sh > /dev/null 2>&1'
end

# Crons to toggle compaction thresholding.
cron "Mr. Batch, no compaction thresholding for these hours." do
  hour "18"
  minute "0"
  command "nodetool -h #{node[:fqdn]} setcompactionthroughput 999 > /dev/null 2>&1"
end

cron "Dr. Realtime, compaction thresholding limited during hours of peak load." do
  hour "6"
  minute "0"
  command "nodetool -h #{node[:fqdn]} setcompactionthroughput 4 > /dev/null 2>&1"
end

# Manage Snapshotting.
template "/usr/local/bin/cassandra-snapshot.sh" do
  source "cassandra-snapshot.sh.erb"
  mode "0755"
  owner "root"
  group "root"
end

cron "Cassandra Snapshots" do
  hour "0,6,12,18"
  minute "0"
  command "/usr/local/bin/cassandra-snapshot.sh > /dev/null 2>&1"
end
