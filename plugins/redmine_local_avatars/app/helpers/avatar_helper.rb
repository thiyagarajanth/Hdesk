module AvatarHelper
  begin; require 'rmagick'; rescue LoadError;end
  begin; require 'mini_magick'; rescue LoadError; end

  # Images will only be cropped if there are the necessary libraries.
  def can_crop_images?
    !!(defined?(MiniMagick) || defined?(Magick))
  end

  # Crops an image and stores it on a temporary file.
  #
  # <tt>filepath</tt> contains the path to the image that should be cropped and
  # <tt>crop_values</tt> must be a array with the values with the order
  # <tt>[W, H, X, Y]</tt>.
  #
  # If the necessary libraries aren't available <tt>crop_image</tt> returns nil
  # otherwise it returns the result of evaluating the +block+.
  #
  # Examples:
  #
  #     crop_image('/tmp/image.jpeg', [200, 200, 0, 0]) do |file|
  #       send_file file.path, :type => 'image/jpeg', :disposition => 'inline'
  #     end
  def crop_image(*args, &block)
    if defined? Magick
      crop_image_with_rmagick(*args, &block)
    elsif defined? MiniMagick
      crop_image_with_mini_magick(*args, &block)
    end
  end

  def crop_image_with_rmagick(filepath, crop_values, &block)
    img = Magick::Image.read(filepath).first.dup
    if crop_values.all?
      crop_values = crop_values[2..3] + crop_values[0..1]
      img.crop!(*crop_values.map(&:to_i))
    end
    img.resize_to_fill!(125, 125, Magick::NorthGravity)

    temporary_image(
      :writer => lambda {|f| img.write(f.path) },
      :consumer => lambda {|f| block.call(f) }
    )
  end

  def crop_image_with_mini_magick(filepath, crop_values, &block)
    img = MiniMagick::Image.open(filepath)
    img.crop sprintf("%sx%s+%s+%s", *crop_values) if crop_values.all?
    img.combine_options do |c|
      c.thumbnail "125x125^"
      c.gravity "north"
      c.extent "125x125"
    end
    img.format('jpg')

    temporary_image(
      :writer => lambda {|f| img.write(f) },
      :consumer => lambda {|f| block.call(f) }
    )
  end

  def temporary_image(options)
    begin
      file = Tempfile.open(['img', '.jpg'], Rails.root.join('tmp'), :encoding => 'ascii-8bit') do |f|
        options[:writer].call(f); f
      end
      File.open(file.path, 'rb') do |f|
        def f.original_filename; File.basename(path); end
        options[:consumer].call(f)
      end
    ensure
      file.unlink if file
    end
  end

  def plugin_image_path(source, options = {})

    if plugin = options.delete(:plugin)
      source = "/plugin_assets/#{plugin}/images/#{source}"
    elsif current_theme && current_theme.images.include?(source)
      source = current_theme.image_path(source)
    end
    path_to_image(source)
  end

  def get_profile_pic(id)
    key = Redmine::Configuration['iServ_api_key']
    base_url = Redmine::Configuration['iServ_url']
    url = base_url+"/services/employees/#{id}/avatar"
    begin
      APICache.get(id.to_s, :cache => 86400, :timeout => 20) do
        begin
          response = RestClient::Request.new(:method => :get,:url => url, :headers => {:"Auth-key" => key},:verify_ssl => false).execute
        rescue
          return nil
        end
        case response.code
          when 200..202
            # 2xx response code
            Base64.encode64(response).gsub("\n", '')
          else
            raise APICache::InvalidResponse
        end
      end
    rescue APICache::APICacheError
      "Tomeout"
    end

  end

end
