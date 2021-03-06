# frozen_string_literal: true

# Ported to DBDv2

require 'tasks/new_content_service2'

# Given a configuration hash read from a yaml file, build the contents in the repository.
class AppendContentService2 < Umrdr::NewContentService2

  def self.call( path_to_yaml_file:, ingester: nil, mode: nil, args: )
    cfg_hash = YAML.load_file( path_to_yaml_file )
    base_path = File.dirname( path_to_yaml_file )
    bcs = AppendContentService2.new( args: args,
                                    path_to_yaml_file: path_to_yaml_file,
                                    cfg_hash: cfg_hash,
                                    ingester: ingester,
                                    mode: mode,
                                    base_path: base_path )
    bcs.run
  rescue Exception => e # rubocop:disable Lint/RescueException
    Rails.logger.error "AppendContentService2.call(#{path_to_yaml_file}) #{e.class}: #{e.message} at\n#{e.backtrace.join("\n")}"
  end

  def initialize( args:, path_to_yaml_file:, cfg_hash:, base_path:, ingester:, mode: )
    initialize_with_msg( args: args,
                         options: {},
                         path_to_yaml_file: path_to_yaml_file,
                         cfg_hash: cfg_hash,
                         base_path: base_path,
                         ingester: ingester,
                         mode: mode,
                         msg: "NEW CONTENT SERVICE AT YOUR ... SERVICE" )
  end

  protected

  def build_repo_contents
    # user = find_or_create_user
    find_works_and_add_files
    # build_collections
    report_measurements( first_label: 'work id' )
  end

end
