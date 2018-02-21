 module ApplicationHelperPatch
      def self.included(base)
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

      end

      module ClassMethods
      end

      module InstanceMethods
        def call_method
          p 'am here ----------------'
        end


      end
 end


