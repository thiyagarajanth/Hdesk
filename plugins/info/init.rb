require 'redmine'

Redmine::Plugin.register :info do
  name 'Info plugin'
  author 'Author name'
  description 'This is a plugin for Redmine'
  version '0.0.1'
  url 'http://example.com/path/to/plugin'
  author_url 'http://example.com/about'

    menu :top_menu, :info, { :controller => 'infos', :action => 'index' }, :caption => 'Info', :after => :administration

end
