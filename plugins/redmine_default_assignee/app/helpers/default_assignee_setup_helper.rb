module DefaultAssigneeSetupHelper

  def principals_options_for_select_default(collection, selected=nil)
    s = ''
    if collection.include?(User.current)
      s << content_tag('option', "<< #{l(:label_me)} >>", :value => User.current.id)
    end
    groups = ''
    collection.sort.each do |element|
      selected_attribute = ' selected="selected"' if option_value_selected?(element, selected) || element.id.to_s == selected
      (element.is_a?(Group) ? groups : s) << %(<option value="#{element.id}"#{selected_attribute}>#{h element.name}</option>)
    end
    unless groups.empty?
      s << %(<optgroup label="#{h(l(:label_group_plural))}">#{groups}</optgroup>)
    end
    s.html_safe
  end

  def destory_trackers_and_members(trackers,members)

    @default_assignees = DefaultAssigneeSetup.all
    @default_assignees.each do |each_setup|
      if  !trackers.map(&:id).include?(each_setup.tracker_id)
        each_setup.destroy
      end
      if  !members.map(&:id).include?(each_setup.default_assignee_to)
        each_setup.destroy
      end
    end

  end

end
