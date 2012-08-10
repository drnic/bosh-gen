require 'yaml'
require 'thor/group'

module Bosh::Gen
  module Generators
    class ExtractPackageGenerator < Thor::Group
      include Thor::Actions

      argument :source_package_path
      
      def check_root_is_release
        unless File.exist?("jobs") && File.exist?("packages")
          raise Thor::Error.new("run inside a BOSH release project")
        end
      end
      
      def check_package_path_within_release
        FileUtils.chdir(source_release_path) do
          unless File.exist?("jobs") && File.exist?("packages")
            raise Thor::Error.new("source package path is not within a BOSH release project")
          end
        end
      end
      
      def check_package_path_is_a_package
        parent_dir = File.basename(File.dirname(source_package_path))
        unless parent_dir == "packages"
          raise Thor::Error.new("source package path is not a BOSH package")
        end
      end
      
      def using_source_release_for_templates
        source_paths << File.join(source_release_path)
      end

      # Extract target package and all its dependencies
      def detect_dependent_packages
        spec = YAML.load_file(source_package_dir("spec"))
        @packages = [source_package_name]
        @packages << spec["packages"] if spec["packages"]
      end
      
      def copy_dependent_packages
        @packages.each {|package| directory "packages/#{package}"}
      end

      def copy_package_spec_files
        @blobs = false
        @packages.each do |package|
          spec = source_file("packages", package, "spec")
          files = YAML.load_file(spec)["files"]
          
          files.each do |relative_file|
            if File.exist?(source_file("src", relative_file))
              copy_file "src/#{relative_file}"
            elsif File.exist?(source_file("blobs", relative_file))
              copy_file "blobs/#{relative_file}"
              @blobs = true
            end
          end
        end
      end
      
      def readme
        if @blobs
          say_status "readme", "Upload blobs with 'bosh upload blobs'"
        end
      end
      
      private
      def source_release_path
        File.expand_path(File.join(source_package_path, "..", ".."))
      end
      
      def source_package_name
        File.basename(source_package_path)
      end
      
      def package_dir(path="")
        File.join("packages", source_package_name, path)
      end
      
      def source_package_dir(path="")
        File.join(source_release_path, "packages", source_package_name, path)
      end
      
      def source_file(*path)
        File.join(source_release_path, *path)
      end
    end
  end
end
