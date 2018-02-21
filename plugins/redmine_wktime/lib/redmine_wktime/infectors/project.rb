module RedmineWktime
  module Infectors
    module Project
      module ClassMethods; end
  
      module InstanceMethods; end

      def self.included(receiver)
        receiver.extend(ClassMethods)
        receiver.send(:include, InstanceMethods)
        receiver.class_eval do
          unloadable

          has_many :rejections, :class_name => 'Rejection', :foreign_key => 'project_id'
        end
      end
      
    end
  end
end