module CassandraHelpers
  include Chef::Mixin::Language

  def what_cluster?
  # Logic here to dertermine what cluster a node belongs too.
  #
  # For reference, this is the current Cassandra databag schema:
  # {
  #   "id": "hostname",
  #   "location": "DC:RACK",
  #   "initial_token": "",
  #   "cluster_name": ""
  # }

    # Sourcing some initial values from the 'cassandra' databag using the hostname as the key:
    @cassandra = data_bag_item('cassandra', node[:hostname])
    node.normal[:cassandra][:initial_token] = @cassandra['initial_token']
    node.normal[:cassandra][:cluster_name] = @cassandra['cluster_name']
    Chef::Log.info("I am a member of the #{node[:cassandra][:cluster_name]} Cassandra cluster.")
  end


  def setup_cassandra_disks
  # Logic here to discover and setup avaliable drives to spec.
  #
  # We build nodes with the OS/Commitlog on /dev/sda, so below we setup /dev/sdb
  # to be the data dir.

    # Word on the street is that all the cool kids use EXT4.
    package "e4fsprogs" do
      action :install
    end

    if defined?node[:block_device][:sdb]
      # Only proceed if the sdb1 is not mounted.
      if not File.read("/etc/mtab") =~ Regexp.new("^/dev/sdb1")
        execute "Clearing and creating gpt disk label on /dev/sdb" do
          command "/bin/dd if=/dev/zero of=/dev/sdb bs=512 count=1 ; /sbin/parted /dev/sdb --script -- mklabel gpt"
          action :run
        end

        execute "Creating partition /dev/sdb1" do
          command "/sbin/parted /dev/sdb --script -- mkpart primary 0 -1; sleep 5"
          action :run
        end

        execute "Formatting partition /dev/sdb1" do
          command "/sbin/mkfs.ext4 -q -m 0 -E lazy_itable_init -O extent,dir_index /dev/sdb1"
          action :run
        end

        if not File.exists?(node[:cassandra][:data_file_directories])

        end

        mount "#{node[:cassandra][:data_file_directories]}" do
          device "/dev/sdb1"
          fstype "ext4"
          options "rw,noatime,nodiratime,data=writeback,barrier=0,nobh"
          dump 0
          pass 0
          action [:mount, :enable]
        end
      end
    end
  end


  def create_cassandra_directories

    directory node[:cassandra][:data_file_directories] do
      owner "cassandra"
      group "cassandra"
      mode "0755"
      recursive true
      action :create
    end

    directory node[:cassandra][:commitlog_directory] do
      owner "cassandra"
      group "cassandra"
      mode "0755"
      recursive true
      action :create
    end

    directory node[:cassandra][:saved_caches_directory] do
      owner "cassandra"
      group "cassandra"
      mode "0755"
      recursive true
      action :create
    end
  end


  def get_cluster_seeds
  # Grab the first two nodes in the cluster, make them the seeds.
    seeds = []
    search('cassandra', "cluster_name:#{node[:cassandra][:cluster_name]}") do |n|
      id = n['id']
      loc = n['location']

      # Build the node name to search for from it's databag id.  This is a hack
      # to tack on the whole domain to the node name, as derived from its'
      # location data.
      if loc.include?('NY')
        dom = ".ny.example.com"
      elsif loc.include?('LA')
        dom = ".la.example.co"
      elsif loc.include?('CHI')
        dom = ".ch.example.com"
      end

      # Get the node.
      target = search('node', "name:#{id + dom}")

      # Grab it's IP address.
      addr = target[0]['ipaddress']

      # Add it to the topology array.
      seeds << addr
    end

    if seeds.count < 2
      return seeds[0]
    else
      return seeds[0..1].join(", ")
    end
  end


  def discover_cassandra_schema
  # Discover schema information for this host so we can dynamically generate
  # maintenance scripts and collectd config.
    chef_gem "cassandra-cql" do
      action :install
    end

    require 'cassandra-cql'
    schema = {}
    server = "#{node[:ipaddress]}:#{node[:cassandra][:rpc_port]}"

    db = CassandraCQL::Database.new("#{server}") rescue nil

    if db
      db.keyspaces.collect{|s| schema[s.name] = s.column_families.collect{|cfname, cfobj| cfname } }
      schema.delete("system")
      schema.delete("OpsCenter")
      return schema
    end
    return nil
  end


  def build_cassandra_topology
  # Building an array of nodes in this cluster and building stuff to pass to the
  # cassandra-topology.properties template.
  #
  # We grab the location attribute from the databag and glue it to the node's IP.
  #
  # In the end the cassandra-topology.properties should be IP=DC:RACK for each node.

    topology = []
    search('cassandra', "cluster_name:#{node[:cassandra][:cluster_name]}") do |n|
      id = n['id']
      loc = n['location']

      # Build the node name to search for from it's databag id.  This is a hack
      # to tack on the whole domain to the node name, as derived from its'
      # location data.
      if loc.include?('NY')
        dom = ".ny.example.com"
      elsif loc.include?('LA')
        dom = ".la.example.co"
      elsif loc.include?('CHI')
        dom = ".ch.example.com"
      end

      # Get the node.
      target = search('node', "name:#{id + dom}")

      # Grab it's IP address.
      addr = target[0]['ipaddress']

      # Add it to the topology array.
      topology << addr + "=" + loc
    end
    return topology
  end


  def calculate_maintenance_window
  # Here, we dynamically and evenly distibute, across the 168 hours of a week,
  # times for maintenance to run.

    # Grab all of the nodes in this Cluster.
    c = []
    search('cassandra', "cluster_name:#{node[:cassandra][:cluster_name]}") do |x|
      c << x['id']
    end

    # Put them in consistant order.
    c = c.sort

    # Get the number of nodes, starting from zero to line up with the hash index.
    numNodes = c.count - 1

    # Put them in a hash with an index.
    hash = Hash[c.map.with_index{|*ki| ki}]

    # Get my offset/index.
    myOffset = hash[node[:hostname]]

    # Out of 168 hours in a week, divided the number of nodes what hour do I run.
    hourOfWeek = 168 / numNodes * myOffset

    # Further reduce to what day and what hour.
    maint_window = Hash.new
    maint_window['day'] = hourOfWeek / 24
    maint_window['hour'] = hourOfWeek % 24

    return maint_window
  end
end
