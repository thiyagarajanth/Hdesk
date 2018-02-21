class User < ActiveRecord::Base
  # establish_connection "sync_prod"
  self.inheritance_column = :_type_disabled
  attr_accessible :lastmodified
  has_one :user_official_info

  USER_FORMATS = {
      :firstname_lastname => {
          :string => '#{firstname} #{lastname}',
          :order => %w(firstname lastname id),
          :setting_order => 1
      },
      :firstname_lastinitial => {
          :string => '#{firstname} #{lastname.to_s.chars.first}.',
          :order => %w(firstname lastname id),
          :setting_order => 2
      },
      :firstinitial_lastname => {
          :string => '#{firstname.to_s.gsub(/(([[:alpha:]])[[:alpha:]]*\.?)/, \'\2.\')} #{lastname}',
          :order => %w(firstname lastname id),
          :setting_order => 2
      },
      :firstname => {
          :string => '#{firstname}',
          :order => %w(firstname id),
          :setting_order => 3
      },
      :lastname_firstname => {
          :string => '#{lastname} #{firstname}',
          :order => %w(lastname firstname id),
          :setting_order => 4
      },
      :lastname_coma_firstname => {
          :string => '#{lastname}, #{firstname}',
          :order => %w(lastname firstname id),
          :setting_order => 5
      },
      :lastname => {
          :string => '#{lastname}',
          :order => %w(lastname id),
          :setting_order => 6
      },
      :username => {
          :string => '#{login}',
          :order => %w(login id),
          :setting_order => 7
      },
  }


  def name(formatter = nil)
    f = self.class.name_formatter(formatter)
    if formatter
      eval('"' + f[:string] + '"')
    else
      @name ||= eval('"' + f[:string] + '"')
    end
  end

  def self.name_formatter(formatter = nil)
    USER_FORMATS[formatter ] || USER_FORMATS[:firstname_lastname]
  end
  
end