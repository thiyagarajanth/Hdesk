module EmployeeInfo
  module Patches
    module UserPatch
      def self.included(base)
        #base.extend(ClassMethods)

        #base.send(:include, InstanceMethods)

        base.class_eval do
        has_one :user_official_info


        # validates_presence_of :user_official_info
#         before_save :attributes_save
#         before_update :attributes_save
#
#           def attributes_save
# p 222222222222222222222222
#           end

          # def user_official_info1
          #   p "++++++++++++++++++++++=UserOfficialInfo++++++++++++++++++++++"
          #  if self.user_official_info.present?
          #     return self.user_official_info.employee_id
          #  end
          # end



          def employee_id

            self.user_official_info.employee_id

          end
        end
      end



    end
  end
end



