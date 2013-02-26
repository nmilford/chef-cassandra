# At outbrain, we can derive a node's cluster membership from it's name.
# However, you can grab this info from the databag or however you like.
case node[:hostname]
when /^cass1/
  default[:cassandra][:MajorVersion] = "1.0"
when ^/cass2/
  default[:cassandra][:MajorVersion] = "1.1"
when /^cass3/
  default[:cassandra][:MajorVersion] = "1.2"
else
  default[:cassandra][:MajorVersion] = "1.0"
end

case node[:cassandra][:MajorVersion]
when "1.2"
  default[:cassandra][:Version] = "1.2.2-1"
  default[:cassandra][:Package] = "cassandra12"
  default[:cassandra][:DSC][:Version] = "1.2.2-1"
  default[:cassandra][:DSC][:Package] = "dsc12"
when "1.1"
  default[:cassandra][:Version] = "1.1.9-1"
  default[:cassandra][:Package] = "apache-cassandra11"
  default[:cassandra][:DSC][:Version] = "1.1.9-1"
  default[:cassandra][:DSC][:Package] = "dsc1.1"
when "1.0"
  default[:cassandra][:Version] = "1.0.11-1"
  default[:cassandra][:Package] = "apache-cassandra1"
  default[:cassandra][:DSC][:Version] = "1.0.11-1"
  default[:cassandra][:DSC][:Package] = "dsc"
end

default[:cassandra][:MAX_HEAP_SIZE] = "8G"
default[:cassandra][:HEAP_NEWSIZE] = "800M"
default[:cassandra][:JMX_PORT] = "7199"

default[:cassandra][:auto_bootstrap] = false
default[:cassandra][:hinted_handoff_enabled] = true
default[:cassandra][:max_hint_window_in_ms] = 3600000
default[:cassandra][:hinted_handoff_throttle_delay_in_ms] = 50
default[:cassandra][:authenticator] = "org.apache.cassandra.auth.AllowAllAuthenticator"
default[:cassandra][:authority] = "org.apache.cassandra.auth.AllowAllAuthority"
default[:cassandra][:partitioner] = "org.apache.cassandra.dht.RandomPartitioner"
default[:cassandra][:data_file_directories] =  "/var/lib/cassandra/data"
default[:cassandra][:commitlog_directory] = "/var/lib/cassandra/commitlog"
default[:cassandra][:saved_caches_directory] = "/var/lib/cassandra/saved_caches"
default[:cassandra][:commitlog_rotation_threshold_in_mb] = 128
default[:cassandra][:commitlog_sync] = "periodic"
default[:cassandra][:commitlog_sync_period_in_ms] = 10000
default[:cassandra][:flush_largest_memtables_at] = 0.75
default[:cassandra][:reduce_cache_sizes_at] = 0.85
default[:cassandra][:reduce_cache_capacity_to] = 0.6
default[:cassandra][:seed_provider_class_name] = "org.apache.cassandra.locator.SimpleSeedProvider"
default[:cassandra][:disk_access_mode] = "auto"
default[:cassandra][:concurrent_writes] = "#{node[:cpu][:total] * 8}".to_i
default[:cassandra][:concurrent_reads] = 80
default[:cassandra][:memtable_flush_queue_size] = 4
default[:cassandra][:memtable_flush_writers] = 1
default[:cassandra][:sliced_buffer_size_in_kb] = 64
default[:cassandra][:storage_port] = 7000
default[:cassandra][:rpc_port] = 9160
default[:cassandra][:rpc_keepalive] = true
default[:cassandra][:rpc_server_type] = "sync"
default[:cassandra][:thrift_framed_transport_size_in_mb] = 15
default[:cassandra][:thrift_max_message_length_in_mb] = 16
default[:cassandra][:incremental_backups] = false
default[:cassandra][:snapshot_before_compaction] = false
default[:cassandra][:column_index_size_in_kb] = 64
default[:cassandra][:in_memory_compaction_limit_in_mb] = 64
default[:cassandra][:compaction_throughput_mb_per_sec] = 16
default[:cassandra][:compaction_preheat_key_cache] = true
default[:cassandra][:rpc_timeout_in_ms] = 10000
default[:cassandra][:phi_convict_threshold] = 8
default[:cassandra][:endpoint_snitch] = "org.apache.cassandra.locator.PropertyFileSnitch"
default[:cassandra][:dynamic_snitch_badness_threshold] = 0.0
default[:cassandra][:request_scheduler] = "org.apache.cassandra.scheduler.NoScheduler"
default[:cassandra][:index_interval] = 128
default[:cassandra][:memtable_total_space_in_mb] = 4096
default[:cassandra][:multithreaded_compaction] = false
default[:cassandra][:commitlog_total_space_in_mb] = 3072
