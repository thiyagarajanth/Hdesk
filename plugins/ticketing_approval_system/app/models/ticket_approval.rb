
require 'csv'
class TicketApproval < ActiveRecord::Base
  unloadable
  belongs_to :ticket_tag
  has_many :ticket_tags
  belongs_to :approval_role
  belongs_to :user
  has_many :issue_approval_details
  has_many :ticket_approval_flows
  belongs_to :parent, class_name: "TicketApproval", foreign_key: 'ref_id'
  has_one :child, :class_name => "TicketApproval", foreign_key: 'ref_id'


  def self.tags_export(tags,project_id)
    column_names=["category","cat_values","max_validity","self"]
    approval_roles = ApprovalRole.where(:project_id=>project_id)
    if approval_roles.present?
      column_names = column_names+ approval_roles.map(&:name)
    end
    options = {}
    CSV.generate(options) do |csv|
      csv << column_names
       tags.each do |product|
       @export_values = product.attributes.values
        approval_roles.each do |each_role|
          value_to_find = product.cat_values.present? && product.cat_values.split('>').count > 1  ? product.cat_values.split('>').last : product.cat_values.split('>').first
          find_cat = TicketTag.find_by_name(value_to_find)
          if find_cat.present?
            find_ticket_approval = TicketApproval.where(:ticket_tag_id=>find_cat.id,:approval_role_id=>each_role.id)
            if find_ticket_approval.present?
              @export_values << true
            else
              @export_values << false
            end
          end
        end
        csv << @export_values
       end
    end
  end

  def self.import_categories(file)
    CSV.foreach(file.path, headers: true) do |row|
      product_hash = row.to_hash # exclude the price field
      product_hash.each do |each_hash|
        errors=[]
        if each_hash["category"].present?
          find_category = ProjectCategory.find_by_cat_name(each_hash["category"])
          if find_category.present?
           cat_tags = each_hash["category"].split(">")
           init_ticket_tag = TicketTag.find_or_intialize_by_project_id_and_name(:project_id=> @project.id,:name=>cat_tags.first)
            init_ticket_tag.root=1
            init_ticket_tag.category_id = find_category.id
            if init_ticket_tag.save
              init_ticket_tag_child = TicketTag.find_or_intialize_by_project_id_and_name(:project_id=> @project.id,:name=>cat_tags.last)
              init_ticket_tag_child.root=1
              init_ticket_tag_child.category_id = find_category.id
              init_ticket_tag_child.parent_id=init_ticket_tag.id
              init_ticket_tag.save
            end
          else
            errors << "Category Not found for #{each_hash["category"]} ,Please create and try."
          end
        end
        each_hash["cat_values"]
      end
    end # end C
  end 

end
