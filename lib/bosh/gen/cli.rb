require "thor"

# bosh_cli libraries
module Bosh; end
require "cli/config" 
require "cli/core_ext"

require 'bosh/gen/models'

module Bosh
  module Gen
    class Command < Thor
      include Thor::Actions
    
      desc "new PATH", "Creates a new BOSH release"
      method_option :s3, :alias => ["--aws"], :type => :boolean, :desc => "Use AWS S3 bucket for blobstore"
      method_option :atmos, :type => :boolean, :desc => "Use EMC ATMOS for blobstore"
      def new(path)
        flags = { :aws => options["s3"], :atmos => options["atmos"] }
        
        require 'bosh/gen/generators/new_release_generator'
        Bosh::Gen::Generators::NewReleaseGenerator.start([path, flags])
      end
      
      desc "package NAME", "Create a new package"
      method_option :dependencies, :aliases => ['-d'], :type => :array, :desc => "List of package dependencies"
      method_option :files,        :aliases => ['-f', '--src'], :type => :array, :desc => "List of files copy into release"
      def package(name)
        dependencies = options[:dependencies] || []
        files        = options[:files] || []
        require 'bosh/gen/generators/package_generator'
        Bosh::Gen::Generators::PackageGenerator.start([name, dependencies, files])
      end
      
      desc "source NAME", "Downloads a source item into the named project"
      method_option :blob, :aliases => ['-b'], :type => :boolean, :desc => "Store file in blobstore"
      def source(name, uri)
        flags = { :blob => options[:blob] || false }
        dir = Dir.mktmpdir
        files = []
        if File.exist?(uri)
          files = [uri]
        else
          say "Downloading #{uri}..."
          FileUtils.chdir(dir) do
            `wget '#{uri}'`
            files = Dir['*'].map {|f| File.expand_path(f)}
          end
        end

        require 'bosh/gen/generators/package_source_generator'
        Bosh::Gen::Generators::PackageSourceGenerator.start([name, files, flags])
      end
      
      desc "job NAME COMMAND", "Create a new job to run 'COMMAND' to launch the process"
      method_option :dependencies, :aliases => ['-d'], :type => :array, :desc => "List of package dependencies"
      method_option :ruby, :type => :boolean, :desc => "Use templates for running Ruby/Rack process"
      def job(name, command=nil)
        command ||= 'EXECUTABLE_SERVER'
        flags = { :ruby => options["ruby"] || false }
        dependencies   = options[:dependencies] || []
        require 'bosh/gen/generators/job_generator'
        Bosh::Gen::Generators::JobGenerator.start([name, command, dependencies, flags])
      end
      
      desc "template JOB FILE_PATH", "Add a Job template (example FILE_PATH: config/httpd.conf)"
      def template(job_name, file_path)
        require 'bosh/gen/generators/job_template_generator'
        Bosh::Gen::Generators::JobTemplateGenerator.start([job_name, file_path])
      end
      
      desc "extract SOURCE_RELEASE_PATH SOURCE_JOB_NAME [JOB_NAME]", "Extracts a job from another release and all its dependent packages and source"
      def extract(source_release_path, source_job_name, target_job_name=nil)
        target_job_name ||= source_job_name
        require 'bosh/gen/generators/extract_job_generator'
        Bosh::Gen::Generators::ExtractJobGenerator.start([source_release_path, source_job_name, target_job_name])
      end

      desc "manifest NAME PATH UUID", "Creates a deployment manifest based on the release located at PATH"
      method_option :force, :type => :boolean, :desc => "Force override existing target manifest file"
      method_option :cpi, :aliases => ['-c'], :type => :string, :desc => "Specify the CPI fields to be generated, e.g. \"aws\" or \"vsphere\""
      method_option :disk, :aliases => ['-d'], :type => :string, :desc => "Attach persistent disks to VMs of specific size, e.g. 8196"
      method_option :addresses, :aliases => ['-a'], :type => :array, :desc => "List of IP addresses available for jobs"
      method_option :range, :aliases => ['-r'], :type => :string, :desc => "IP Netmask"
      method_option :gateway, :aliases => ['-g'], :type => :string, :desc => "IP Gateway"
      method_option :dns, :type => :array, :desc => "DNS Servers"
      method_option :workers, :aliases => ['-w'], :type => :numeric, :desc => "Number of worker VMs to spawn when compiling packages"
      method_option :network, :aliases => ['-n'], :type => :string, :desc => "[vSphere Only] Network to bind VMs to"
      def manifest(name, release_path, uuid)
        release_path = File.expand_path(release_path)
        ip_addresses = options["addresses"] || []
        flags = { 
          :force => options["force"] || false, 
          :disk => options[:disk], 
          :cpi => options["cpi"] || "aws", 
          :range =>  options[:range] || "", 
          :gateway => options[:gateway] || "",
          :dns => options[:dns] || [],
          :workers => options[:workers] || 10,
          :network => options[:network] || "NETWORK_NAME"
        }
        require 'bosh/gen/generators/deployment_manifest_generator'
        Bosh::Gen::Generators::DeploymentManifestGenerator.start([name, release_path, uuid, ip_addresses, flags])
      end

      no_tasks do
        def cyan; "\033[36m" end
        def clear; "\033[0m" end
        def bold; "\033[1m" end
        def red; "\033[31m" end
        def green; "\033[32m" end
        def yellow; "\033[33m" end
      end
    end
  end
end
