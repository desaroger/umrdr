# Generated by curation_concerns:models:install
class Collection < ActiveFedora::Base                            
  include ::CurationConcerns::CollectionBehavior
  # You can replace these metadata if they're not suitable
  include CurationConcerns::BasicMetadata

  after_initialize :set_defaults
  
  property :isReferencedBy, predicate: ::RDF::Vocab::DC.isReferencedBy, multiple: true do |index|
   index.type :text
   index.as :stored_searchable
  end

  def set_defaults
    return unless new_record?
    self.visibility = 'open'
  end
end 
