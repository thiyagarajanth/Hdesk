class AdminDetail < ActiveRecord::Base
  unloadable
   def self.set_from_params(name, params)
    params = params.dup
    params.delete_if {|v| v.blank? } if params.is_a?(Array)
    m = "#{name}_from_params"
    if respond_to? m
      self[name.to_sym] = send m, params
    else
      self[name.to_sym] = params
    end
  end
end
