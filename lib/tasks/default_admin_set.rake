
# TODO: does this need to be ported to DBDv2?

# pull this up to UMRDR level from gem so it can get the correct default admin set id (it's different in gem)
namespace :hyrax do
  namespace :default_admin_set do
    desc "Create the Default Admin Set"
    task create: :environment do
      AdminSet.find_or_create_default_admin_set_id
    end
  end
end