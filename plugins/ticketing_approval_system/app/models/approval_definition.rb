
require 'rubygems'
require 'pdf-reader'
class ApprovalDefinition < ActiveRecord::Base
  unloadable
  belongs_to :ticket_tag
  has_many :ticket_tags
  belongs_to :approval_role
  belongs_to :interrupter, :class_name => "User", :foreign_key => :interrupter_id
  has_many :issue_approval_details

  def self.aggrement
    code_name = [["02dfa","laptop"],["25ffv","RAM"],["7e3vcv","Mobile"],["5d4gg","Accessrights"]]
    return code_name
  end
  
  def set_rgb_color_for_nonstroking(r, g, b)
      puts "R: #{r}, G: #{g}, B: #{b}"
    end
  
  def self.view_agreement
    data =Base64.encode64(" a class (Diplopoda) of arthropods, characterised by two pairs of jointed legs on most body segments. Most species have long cylindrical or flattened bodies with more than 20 segments, while pill millipedes are shorter and can roll into a ball. There are around 12,000 named species, making Diplopoda the largest class of myriapods. Despite their name (from the Latin for thousand feet), no known species has 1,000 legs; the most recorded is 750. Most species are detritivores, eating decaying leaves and other dead a class (Diplopoda) of arthropods, characterised by two pairs of jointed legs on most body segments. Most species have long cylindrical or flattened bodies with more than 20 segments, while pill millipedes are shorter and can roll into a ball. There are around 12,000 named species, making Diplopoda the largest class of myriapods. Despite their name (from the Latin for thousand feet), no known species has 1,000 legs; the most recorded is 750. Most species are detritivores, eating decaying leaves and other dead a class (Diplopoda) of arthropods, characterised by two pairs of jointed legs on most body segments. Most species have long cylindrical or flattened bodies with more than 20 segments, while pill millipedes are shorter and can roll into a ball. There are around 12,000 named species, making Diplopoda the largest class of myriapods. Despite their name (from the Latin for thousand feet), no known species has 1,000 legs; the most recorded is 750. Most species are detritivores, eating decaying leaves and other dead a class (Diplopoda) of arthropods, characterised by two pairs of jointed legs on most body segments. Most species have long cylindrical or flattened bodies with more than 20 segments, while pill millipedes are shorter and can roll into a ball. There are around 12,000 named species, making Diplopoda the largest class of myriapods. Despite their name (from the Latin for thousand feet), no known species has 1,000 legs; the most recorded is 750. Most species are detritivores, eating decaying leaves and other dead a class (Diplopoda) of arthropods, characterised by two pairs of jointed legs on most body segments. Most species have long cylindrical or flattened bodies with more than 20 segments, while pill millipedes are shorter and can roll into a ball. There are around 12,000 named species, making Diplopoda the largest class of myriapods. Despite their name (from the Latin for thousand feet), no known species has 1,000 legs; the most recorded is 750. Most species are detritivores, eating decaying leaves and other dead a class (Diplopoda) of arthropods, characterised by two pairs of jointed legs on most body segments. Most species have long cylindrical or flattened bodies with more than 20 segments, while pill millipedes are shorter and can roll into a ball. There are around 12,000 named species, making Diplopoda the largest class of myriapods. Despite their name (from the Latin for thousand feet), no known species has 1,000 legs; the most recorded is 750. Most species are detritivores, eating decaying leaves and other dead a class (Diplopoda) of arthropods, characterised by two pairs of jointed legs on most body segments. Most species have long cylindrical or flattened bodies with more than 20 segments, while pill millipedes are shorter and can roll into a ball. There are around 12,000 named species, making Diplopoda the largest class of myriapods. Despite their name (from the Latin for thousand feet), no known species has 1,000 legs; the most recorded is 750. Most species are detritivores, eating decaying leaves and other dead a class (Diplopoda) of arthropods, characterised by two pairs of jointed legs on most body segments. Most species have long cylindrical or flattened bodies with more than 20 segments, while pill millipedes are shorter and can roll into a ball. There are around 12,000 named species, making Diplopoda the largest class of myriapods. Despite their name (from the Latin for thousand feet), no known species has 1,000 legs; the most recorded is 750. Most species are detritivores, eating decaying leaves and other dead a class (Diplopoda) of arthropods, characterised by two pairs of jointed legs on most body segments. Most species have long cylindrical or flattened bodies with more than 20 segments, while pill millipedes are shorter and can roll into a ball. There are around 12,000 named species, making Diplopoda the largest class of myriapods. Despite their name (from the Latin for thousand feet), no known species has 1,000 legs; the most recorded is 750. Most species are detritivores, eating decaying leaves and other dead a class (Diplopoda) of arthropods, characterised by two pairs of jointed legs on most body segments. Most species have long cylindrical or flattened bodies with more than 20 segments, while pill millipedes are shorter and can roll into a ball. There are around 12,000 named species, making Diplopoda the largest class of myriapods. Despite their name (from the Latin for thousand feet), no known species has 1,000 legs; the most recorded is 750. Most species are detritivores, eating decaying leaves and other dead  ")#(File.open("/home/local/OFS1/sabarivigneshn/personal/leave.pdf").read)
    @pdf_file = Base64.decode64(data).html_safe
    return @pdf_file
  end

  def self.get_project_code
    key = Redmine::Configuration['iServ_api_key']    
    base_url = Redmine::Configuration['iServ_url']
    require 'json'
    require 'rest_client'
    url = base_url+"/services/projects/departments"
    #url = "iservstaging.objectfrontier.com/services/projects/departments"
    dept = []
    begin
      dept =  JSON.parse(RestClient::Request.new(:method => :get, :url => url, :headers => {:content_type => 'json',"Auth-key" => key}, :verify_ssl => false).execute.body)
    rescue Exception => e
    dept = []     
    end
    #dept = '[{ "name": "Admin", "department_code": "123"}, { "name": "BD", "department_code": "586ICU"}]'
    codes = []
    dept.each do |rec|
      codes << [rec['name'],rec['department_code']]
    end
    codes
  end
  # def self.view_agreement
  #   key = Redmine::Configuration['iServ_api_key']
  #   base_url = Redmine::Configuration['iServ_url']
  #   url= base_url+"/services/employees/#{id}/avatar"
  # end
end
