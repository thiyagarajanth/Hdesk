class SyncEntity < ActiveRecord::Base
  belongs_to :group, :foreign_key => "entity_id"
end
