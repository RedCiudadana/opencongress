class Amendment < ActiveRecord::Base
  include Tire::Model::Search
  include Tire::Model::Callbacks

  belongs_to :bill
  has_many :actions
  has_many :roll_calls, :order => 'date'
  belongs_to :key_vote_category, :class_name => "PvsCategory", :foreign_key => :key_vote_category_id
  
  def display_number
    if number.nil? or number.empty?
      ""
    else
      prefix = case number[0]
               when 'h' then 'H.Amdt'
               when 's' then 'S.Amdt'
               end
      "#{prefix} #{number[1..-1]}"
    end
  end
  
  def offered_date_short
    Time.at(offered_date).utc.strftime("%b ") + Time.at(offered_date).utc.day.ordinalize    
  end
  
  def thomas_url
    "http://hdl.loc.gov/loc.uscongress/legislation.#{bill.session}#{number[0...1]}amdt#{number[1..-1]}"
  end

  mapping do
    indexes :title
    indexes :purpose
    indexes :description
    indexes :retreived_date
    indexes :status_datetime
    indexes :offered_datetime
    indexes :bill_titles,           :as => proc { bill && bill.bill_titles.map(&:title) }
  end
end
