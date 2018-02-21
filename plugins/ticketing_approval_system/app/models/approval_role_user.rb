class ApprovalRoleUser < ActiveRecord::Base
  # extend Enumerize

  belongs_to :inia_project
  belongs_to :project
  belongs_to :approval_role
  belongs_to :user
  # belongs_to :primary_user, :class_name => :User,:foreign_key => "primary_user_id"
  # belongs_to :secondary_user, :class_name => :User,:foreign_key => "secondary_user_id"
  # belongs_to :updated_by, :class_name => :User,:foreign_key => "updated_by"


  # enumerize :active_user, in: [:primary_user, :secondary_user], default: :primary_user

  # alias_attribute :user_id, :primary_user_id

  # before_save :update_current_user
  # before_create :add_created_by

  # def add_created_by
  #   self.created_by = User.current.id
  # end

  # def update_current_user
  #   self.updated_by = User.current
  # end

  # def get_active_user
  #   if self.active_user == 'primary_user' || self.active_user == nil
  #     self.primary_user
  #   elsif self.active_user == 'secondary_user'
  #     self.secondary_user
  #   end
  # end

  # def active
  #   if self.active_user == 'primary_user'
  #     return self.primary_user
  #   elsif self.active_user == 'secondary_user'
  #     return self.secondary_user
  #   end
  # end

  # def active_users

  # end


end