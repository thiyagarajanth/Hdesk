class UserOfficialInfo < ActiveRecord::Base
  unloadable
  belongs_to :user
  validates :employee_id, :presence => true,length: { maximum: 8 }

  def self.update_employee_ids
   # Active users employee id updation
    User.active.flatten.each do |user|
      user.custom_field_values.each_with_index do |c,index|
        custom_field =CustomField.where(:id=>c.custom_field_id)
        if custom_field.present? && (custom_field.last.name=="Emp_code") && user.custom_field_values[index].to_s.present?

          #user_emp_code << {:user_id=>user.id,:employee_id=> user.custom_field_values[index].to_s}
           UserOfficialInfo.build(user.id,user.custom_field_values[index].to_s.to_i)
        end
      end
    end

  end

  def self.build(user_id,employee_id)
     user_info = UserOfficialInfo.find_or_create_by_user_id(:user_id=>user_id)
     user_info.employee_id=employee_id
     user_info.save
   end

end
