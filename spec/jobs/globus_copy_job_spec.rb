require 'rails_helper'
require 'uri'

RSpec.configure do |config|
  config.filter_run_excluding :globus_enabled => :true unless Umrdr::Application.config.globus_enabled
end
describe "GlobusJob :globus_enabled => :true", :globus_enabled => :true do
describe GlobusCopyJob do
  let( :globus_dir ) { Pathname "/tmp/deepbluedata-globus" }
  let( :globus_download_dir ) { globus_dir.join 'download' }
  let( :target_name ) { "DeepBlueData_id321" }
  let( :target_name_prep_dir ) { "#{GlobusJob.server_prefix(str:'_')}#{target_name}" }
  let( :globus_prep_dir ) { globus_dir.join 'prep' }
  let( :error_file ) { globus_prep_dir.join ".test.error.#{target_name}" }
  let( :job_ready_file ) { globus_prep_dir.join ".test.ready.#{target_name}" }
  let( :lock_file ) { globus_prep_dir.join ".test.lock.#{target_name}" }
  let( :email_file ) { globus_prep_dir.join ".test.copy_job_emails.#{target_name}" }

  describe "#perform" do
    let( :user ) { FactoryGirl.build(:user) }
    let( :work ) { FactoryGirl.build(:generic_work, id: 'id321', title: ['test title'], user: user) }
    let( :globus_download_ready_dir ) { globus_download_dir.join target_name }
    let( :globus_download_ready_file1 ) { globus_download_ready_dir.join 'File01' }
    let( :globus_download_ready_file2 ) { globus_download_ready_dir.join 'File02' }
    let( :globus_download_ready_file_metadata ) { globus_download_ready_dir.join 'w_id321_metadata_report.txt' }
    let( :file_set1 ) { FactoryGirl.build(:file_set, label: 'File01', id: 'fs0001') }
    let( :file_set2 ) { FactoryGirl.build(:file_set, label: 'File02', id: 'fs0002') }
    let( :file1 ) { Tempfile.new( "File01-" ) }
    let( :file2 ) { Tempfile.new( "File02-" ) }
    let( :uri1 ) { URI.join('file:///', "#{file1.path}" ) }
    let( :uri2 ) { URI.join('file:///', "#{file2.path}" ) }
    let( :ready_file ) { job_ready_file }
    let( :log_prefix ) { "Globus: globus_copy_job" }
    let( :lock_file_msg ) { "#{log_prefix} lock file #{lock_file}" }
    let( :globus_prep_copy_dir ) { globus_prep_dir.join target_name_prep_dir }
    let( :globus_prep_copy_tmp_dir ) { globus_prep_dir.join( target_name_prep_dir + '_tmp' ) }
    let( :current_token ) { GlobusJob.era_token }
    let( :user_email ) { "test@email.edu" }
    let( :email_addresses ) { [ user_email ] }
    let( :mailer ) { "mailer" }

    context "when can acquire lock" do
      before do
        expect( ActiveFedora::Base ).to receive( :find ).and_return( work )
        file_set1.define_singleton_method( :files ) do nil; end
        file_set2.define_singleton_method( :files ) do nil; end
        file1.define_singleton_method( :uri ) do nil; end
        file2.define_singleton_method( :uri ) do nil; end
        file1.define_singleton_method( :original_name ) do 'File01' end
        file2.define_singleton_method( :original_name ) do 'File02' end
        uri1.define_singleton_method( :value ) do nil; end
        uri2.define_singleton_method( :value ) do nil; end
        allow( file_set1 ).to receive( :files ).and_return( [file1] )
        allow( file_set2 ).to receive( :files ).and_return( [file2] )
        expect( file1 ).to receive( :uri ).and_return( uri1 )
        expect( file2 ).to receive( :uri ).and_return( uri2 )
        expect( uri1 ).to receive( :value ).and_return( file1.path )
        expect( uri2 ).to receive( :value ).and_return( file2.path )
        allow( work ).to receive( :file_sets ).and_return( [file_set1,file_set2] )
        File.delete error_file if File.exist? error_file
        File.delete lock_file if File.exist? lock_file
        #Dir.delete globus_prep_copy_dir if Dir.exist? globus_prep_copy_dir
        #Dir.delete globus_prep_copy_tmp_dir if Dir.exist? globus_prep_copy_tmp_dir
        allow( Rails.logger ).to receive( :debug )
        allow( Rails.logger ).to receive( :error )
        expect( PROV_LOGGER ).to receive( :info ) if Umrdr::Application.config.globus_log_provenance_copy_job_complete
        mailer.define_singleton_method( :deliver_now ) do nil; end
        expect( WorkMailer ).to receive( :globus_job_complete ).with( any_args ).and_return( mailer ).twice
        expect( mailer ).to receive( :deliver_now ).twice
      end
      it "calls globus block." do
        open( file1.path, 'w' ) { |f| f << "File01" << "\n" }
        open( file2.path, 'w' ) { |f| f << "File02" << "\n" }
        described_class.perform_now( "id321", user_email: user_email )
        #expect( Rails.logger ).to have_received( :debug ).with( 'bogus so we can look at the logger output' )
        expect( Rails.logger ).to have_received( :debug ).with( "#{log_prefix} lock file #{lock_file}" )
        expect( Rails.logger ).to have_received( :debug ).with( "#{log_prefix} writing lock token #{current_token} to #{lock_file}" )
        expect( Rails.logger ).to have_received( :debug ).with( "#{log_prefix} begin copy" )
        expect( Rails.logger ).to have_received( :debug ).with( "#{log_prefix} Starting copy to #{globus_prep_copy_tmp_dir}" )
        expect( Rails.logger ).to have_received( :debug ).with( "#{log_prefix} copy complete" )
        #expect( Rails.logger ).to have_received( :debug ).with( 'bogus so we can look at the logger output' )
        expect( Rails.logger ).not_to have_received( :error )
        expect( File.exist? ready_file ).to eq( true )
        expect( Dir.exist? globus_download_ready_dir ).to eq( true )
        expect( Dir.exist? globus_prep_copy_dir ).to eq( false )
        expect( Dir.exist? globus_prep_copy_tmp_dir ).to eq( false )
        expect( File.exist? globus_download_ready_file1 ).to eq( true )
        expect( File.exist? globus_download_ready_file2 ).to eq( true )
        expect( File.exist? globus_download_ready_file_metadata ).to eq( true )
      end
      after do
        File.delete email_file if File.exist? email_file
        File.delete error_file if File.exist? error_file
        File.delete lock_file if File.exist? lock_file
        File.delete ready_file if File.exist? ready_file
        File.delete globus_download_ready_file1 if File.exist? globus_download_ready_file1
        File.delete globus_download_ready_file2 if File.exist? globus_download_ready_file2
        File.delete globus_download_ready_file_metadata if File.exist? globus_download_ready_file_metadata
        Dir.delete globus_download_ready_dir if Dir.exist? globus_download_ready_dir
      end
    end
  end

  describe "#globus_do_copy?" do
    let( :job ) { described_class.new }
    let( :target_file_name ) { "targetfile" }
    let( :prep_file_name ) { globus_prep_dir.join target_file_name }
    before do
      prep_dir = globus_prep_dir
      job.define_singleton_method( :set_parms ) do
        @globus_concern_id = "id321"
        @globus_log_prefix = "Globus: "
        @target_prep_dir = prep_dir
      end
      job.set_parms
    end
    context "when prep file exists" do
      before do
        expect( File ).to receive( :exist? ).with( prep_file_name ).and_return( true )
        msg = "Globus:  skipping copy because #{prep_file_name} already exists"
        expect( Rails.logger ).to receive( :debug ).with( msg )
      end
      it "returns false." do
        expect( job.send( :globus_do_copy?, target_file_name ) ).to eq( false )
      end
    end
    context "when prep file does not exist" do
      before do
        expect( File ).to receive( :exist? ).with( prep_file_name ).and_return( false )
      end
      it "returns true." do
        expect( job.send( :globus_do_copy?, target_file_name ) ).to eq( true )
      end
    end
  end

  describe "#globus_job_complete_file" do
    let( :job ) { described_class.new }
    before do
      job.define_singleton_method( :set_parms ) do @globus_concern_id = "id321"; end
      job.set_parms
    end
    it "returns the ready file name." do
      expect( job.send( :globus_job_complete_file ) ).to eq( job_ready_file )
    end
  end

  describe "#globus_job_complete?" do
    let( :job ) { described_class.new }
    let( :job_complete_dir ) { globus_download_dir.join 'DeepBlueData_id321' }
    before do
      job.define_singleton_method( :set_parms ) do @globus_concern_id = "id321"; end
      job.set_parms
    end
    context "when file exists" do
      before do
        expect( Dir ).to receive( :exist? ).with( job_complete_dir ).and_return( true )
      end
      it "return true." do
        expect( job.send( :globus_job_complete? ) ).to eq( true )
      end
    end
    context "when file does not exist" do
      before do
        expect( Dir ).to receive( :exist? ).with( job_complete_dir ).and_return( false )
      end
      it "return true." do
        expect( job.send( :globus_job_complete? ) ).to eq( false )
      end
    end
  end

  describe "#globus_notify_user" do
    # TODO
  end

  describe "#globus_ready_file" do
    let( :job ) { described_class.new }
    before do
      job.define_singleton_method( :set_parms ) do @globus_concern_id = "id321"; end
      job.set_parms
    end
    it "returns the ready file name." do
      expect( job.send( :globus_ready_file ) ).to eq( job_ready_file )
    end
  end
end
end
