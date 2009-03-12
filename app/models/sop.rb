require 'acts_as_resource'

class Sop < ActiveRecord::Base
  acts_as_resource
  
  validates_presence_of :title
  
  acts_as_solr(:fields=>[:description,:title,:original_filename]) if SOLR_ENABLED
  
  belongs_to :content_blob,
             :dependent => :destroy
  
  # TODO
  # add all required validations here
  
  
  # get a list of SOPs with their original uploaders - for autocomplete fields
  # (authorization is done immediately to save from iterating through the collection again afterwards)
  #
  # Parameters:
  # - user - user that performs the action; this is required for authorization
  def self.get_all_as_json(user)
    all_sops = Sop.find(:all, :order => "ID asc")
    sops_with_contributors = all_sops.collect{ |s| 
        Authorization.is_authorized?("show", nil, s, user) ?
        (p = s.asset.contributor.person;
        { "id" => s.id,
          "title" => s.title,
          "contributor" => "by " +
                           (p.first_name.blank? ? (logger.error("\n----\nUNEXPECTED DATA: person id = #{p.id} doesn't have a first name\n----\n"); "(NO FIRST NAME)") : p.first_name) + " " +
                           (p.last_name.blank? ? (logger.error("\n----\nUNEXPECTED DATA: person id = #{p.id} doesn't have a last name\n----\n"); "(NO LAST NAME)") : p.last_name),
          "type" => "SOP"} ) :
        nil }
    
    sops_with_contributors.delete(nil)
    
    return sops_with_contributors.to_json
  end
  
end
