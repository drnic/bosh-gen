require "yaml"

module Bosh::Gen::Models
  class DeploymentManifest
    attr_reader :manifest
    
    default_options = {:cpi => "aws", :stemcell_version => "0.5.1"}
    
    def initialize(name, director_uuid, release_properties, cloud_properties, options=default_options)
      @manifest = {}
      @cloud_properties = cloud_properties
      @stemcell = { "name" => "bosh-stemcell", "version" => options[:stemcell_version] }
      @persistent_disk = cloud_properties.delete("persistent_disk").to_i
      @static_ips = cloud_properties["static"]["addresses"] || []
      @options = options

      manifest["name"] = name
      manifest["director_uuid"] = director_uuid
      manifest["release"] = release_properties.dup
      manifest["compilation"] = {
        "workers" => 10,
        "network" => "default",
        "cloud_properties" => YAML.load(YAML.dump(cloud_properties["compilation"]))
      }
      manifest["update"] = {
        "canaries" => 1,
        "canary_watch_time" => 30000,
        "update_watch_time" => 30000,
        "max_in_flight" => 4,
        "max_errors" => 1
      }
      
      if options[:cpi] == "aws"
        manifest["networks"] = [
          {
            "name" => "default",
            "type" => "dynamic",
            "cloud_properties" => YAML.load(YAML.dump(cloud_properties["network"]))
          },
          {
            "name" => "vip_network",
            "type" => "vip",
            "cloud_properties" => YAML.load(YAML.dump(cloud_properties["network"]))
          }
        ]
      elsif options[:cpi] == "vsphere"
        manifest["networks"] = [
          "name" => "default",
          "subnets" => [
            "static" => cloud_properties["static"]["addresses"].dup,
            "range" => cloud_properties["static"]["range"].dup,
            "gateway" => cloud_properties["static"]["gateway"].dup,
            "dns" => cloud_properties["static"]["dns"].dup,
            "cloud_properties" => cloud_properties["network"].dup
          ]
        ]
      end
      
      manifest["resource_pools"] = [
        {
          "name" => "common",
          "network" => "default",
          "size" => 0,
          "stemcell" => @stemcell,
          "cloud_properties" => YAML.load(YAML.dump(cloud_properties["compilation"]))
        }
      ]
      manifest["resource_pools"].first["persistent_disk"] = @persistent_disk if @persistent_disk > 0
      manifest["jobs"] = []
      manifest["properties"] = {}
    end
    
    # Each item of +jobs+ is a hash. 
    # The minimum hash is:
    # { "name" => "jobname" }
    # This is the equivalent to:
    # { "name" => "jobname", "template" => "jobname", "instances" => 1}
    def jobs=(jobs)
      total_instances = 0
      static_ips = @static_ips.dup
      manifest["jobs"] = []
      jobs.each do |job|
        job_instances = job["instances"] || 1
        manifest_job = {
          "name" => job["name"],
          "template" => job["template"] || job["name"],
          "instances" => job_instances,
          "resource_pool" => "common",
        }
        
        # Setup networking specific to AWS
        if @options[:cpi] == "aws"
          manifest_job["networks"] = [
            {
              "name" => "default",
              "default" => %w[dns gateway]
            }
          ]
        
          if static_ips.length > 0
            job_ips, static_ips = static_ips[0..job_instances-1], static_ips[job_instances..-1]
            manifest_job["networks"] << {
              "name" => "vip_network",
              "static_ips" => job_ips
            }
          end
        elsif @options[:cpi] == "vsphere"
          manifest_job["networks"] = [
            {
              "name" => "default"
            }
          ]
          if static_ips.length > 0
            job_ips, static_ips = static_ips[0..job_instances-1], static_ips[job_instances..-1]
            manifest_job["networks"] = [
              {
                "name" => "default",
                "static_ips" => job_ips
              }
            ]
          end
        end
        
        
        manifest_job["persistent_disk"] = @persistent_disk if @persistent_disk > 0
        manifest["jobs"] << manifest_job
      end
      manifest["resource_pools"].first["size"] = manifest["jobs"].inject(0) {|total, job| total + job["instances"]}
    end
    
    def to_yaml
      manifest.to_yaml
    end
  end
end