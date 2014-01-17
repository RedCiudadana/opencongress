require_dependency 'viewable_object'
class Sector < ActiveRecord::Base
  include ViewableObject
  validates_uniqueness_of :name

  has_many :person_sectors, :include => :person
  has_many :people, :through => :person_sectors
  has_many :comments, :as => :commentable

  # forward slashes in the URL were breaking the links
  #def to_param
  #  "#{id}_#{url_name}"
  #end

  @@DISPLAY_OBJECT_NAME = 'Industry'
  
  def display_object_name
    @@DISPLAY_OBJECT_NAME
  end

  def ident
    "Industry #{id}"
  end
  
  private
  def url_name
    name.gsub(/[\.\(\)]/, "").gsub(/[-\s]+/, "_").downcase
  end
end
