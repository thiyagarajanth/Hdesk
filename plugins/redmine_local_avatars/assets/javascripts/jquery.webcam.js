/**
* jQuery Webcam
*
* Copyright (c) 2014, Sergey Shilko (sergey.shilko@gmail.com)
*
* @author Sergey Shilko
* @see https://github.com/thorin/jquery-webcam
*
**/
jQuery(function($) {
  "use strict"; // jshint ;_;

  var WebcamSwf = function (element, options) {
    this.init(element, options)
  }

  var WebcamGum = function (element, options) {
    this.init(element, options)
  }

  var WebcamBase = {
    cameraEnabled:   function()  { return this.options.cameraEnabled.call(this) },
    cameraDisabled:  function()  { return this.options.cameraDisabled.call(this) },
    noCameraFound:   function()  { return this.options.noCameraFound.call(this) },
    isClientReady:   function()  { return this.options.isClientReady.call(this) },
    cameraReady:     function()  { return this.options.cameraReady.call(this) },
    error:           function(e) { return this.options.error.call(this, e) },
    debug:           function()  { return this.options.debug.call(this) },

    setUid: function($elem) {
      var uid = $elem.attr('id')
      while (!uid) {
        var randomUid = 'webcam' + Math.floor((Math.random()*99999))
        if (document.getElementById(randomUid)) continue
        $elem.attr('id', uid = randomUid)
      }
      return uid
    },
    getOptions: function (options) {
      return $.extend({}, $.fn.webcam.defaults, this.$element.data(), options)
    }
  }

  WebcamSwf.prototype = $.extend({}, WebcamBase, {
    constructor: WebcamSwf,

    init: function(container, options) {
      this.$element = $(container)
      this.id = this.setUid(this.$element)
      this.options = this.getOptions(options)
      var callTarget = "jQuery('#" + this.id + "').data('webcam')"
      var flashvars = $.param({
          callTarget: callTarget,
          resolutionWidth: this.options.resolutionWidth,
          resolutionHeight: this.options.resolutionHeight,
          smoothing: this.options.videoSmoothing,
          deblocking: this.options.videoDeblocking,
          StageScaleMode: this.options.stageScaleMode,
          StageAlign: this.options.stageAlign
      })
      var embed = '<object id="'+this.id+'Object" type="application/x-shockwave-flash" data="'+this.options.swffile+'" ' +
            'width="'+this.options.previewWidth+'" height="'+this.options.previewHeight+'">' +
          '<param name="movie" value="'+this.options.swffile+'" />' +
          '<param name="FlashVars" value="' + flashvars + '" />' +
          '<param name="bgcolor" value="'+this.options.bgcolor+'" />' +
          '<param name="allowScriptAccess" value="always" />' +
          '<param name="wmode" value="opaque" />' +
          '</object>'

      this.$cam = $(embed)

      this.$element.append(this.$cam)
      this.cam = this.$cam[0]
    },
    cameraConnected: function () {
      this.isSwfReady = true
      this.cam = document.getElementById(this.id + 'Object')
      this.cameraReady()
    },

    save:            function()  { try { return this.cam.save()          } catch(e) { this.error(e) } },
    saveAndPost:     function(o) { try { return this.cam.saveAndPost(o)  } catch(e) { this.error(e) } },
    setCamera:       function(i) { try { return this.cam.setCamera(i)    } catch(e) { this.error(e) } },
    getCameraList:   function()  { try { return this.cam.getCameraList() } catch(e) { this.error(e) } },
    getResolution:   function()  { try { return this.cam.getResolution() } catch(e) { this.error(e) } },
    pause:           function()  { try { return this.cam.pause()         } catch(e) { this.error(e) } },
    play:            function()  { try { return this.cam.playCam()       } catch(e) { this.error(e) } }
  })

  WebcamGum.prototype = $.extend({}, WebcamBase, {
    constructor: WebcamGum,

    init: function(container, options) {
      this.$element = $(container)
      this.id = this.setUid(this.$element)
      this.options = this.getOptions(options)
      this.$element.bind("webcamdestroy", $.noop)

      this.$wrapper = $('<div>', {
        css: {
          overflow: 'hidden',
          maxWidth: 'inherit',
          maxHeight: 'inherit',
          width: this.options.previewWidth,
          height: this.options.previewHeight
        }
      })
      this.$video = $('<video style="visibility:hidden" width="'+this.options.previewWidth+'" height="'+this.options.previewHeight+'" >')
      this.$wrapper.append(this.$video)
      this.$element.append(this.$wrapper)
      this.$canvas = $('<canvas>')
      this.video = this.$element.find('video')[0]

      navigator.getUserMedia({
          video: {
            mandatory: {
              minWidth:  this.options.resolutionWidth,
              minHeight: this.options.resolutionHeight
            }
          },
          audio: false
        },
        $.proxy(this.cameraConnected, this),
        $.proxy(this.cameraError, this)
      )
    },

    cameraConnected: function (stream) {
      this.stream = stream
      var video = this.video

      if (video.mozSrcObject !== undefined) {
        video.mozSrcObject = stream;
      } else {
        video.src = (window.URL && window.URL.createObjectURL(stream)) || stream;
      }

      stream.oninactive = function () { this.cameraDisabled() }

      video.play();
      this.cameraReady();

      this.$video.bind('loadeddata', $.proxy(this.checkVideo, this, 10));
    },

    cameraError: function (e) {
      if (e == 'MANDATORY_UNSATISFIED_ERROR' || e.name === 'MANDATORY_UNSATISFIED_ERROR') {
        this.noCameraFound()
      }
      this.error(e)
    },

    checkVideo: function(attempts) {
      if (attempts <= 0) {
        this.error("Unable to play video stream. Is webcam working?"); return
      }
      if (this.video.videoWidth <= 0 || this.video.videoHeight <= 0) {
        window.setTimeout($.proxy(this.checkVideo, this, attempts - 1), 500); return
      }

      var vratio = this.video.videoWidth / this.video.videoHeight
      this.$video.css({
        visibility: 'inherit',
        width:      Math.max(this.options.previewWidth, this.options.previewHeight * vratio),
        height:     Math.max(this.options.previewHeight, this.options.previewWidth / vratio),
        marginLeft: Math.min(0, - (this.options.previewHeight * vratio - this.options.previewWidth) / 2),
        marginTop:  Math.min(0, - (this.options.previewWidth / vratio - this.options.previewHeight) / 2)
      })
      var pratio = this.options.previewWidth / this.options.previewHeight
      this.$canvas.attr({
        width:  Math.min(this.video.videoWidth, this.video.videoHeight * pratio),
        height: Math.min(this.video.videoHeight, this.video.videoWidth / pratio)
      })
      this.cameraEnabled()
    },

    saveAndPost: function(options) {
      this.captureToCanvas()

      this.canvaToBlob(function(blob) {
        // Fill in the form with the received data
        var formData = new FormData()
        formData.append(options.filefield, blob, options.filename)
        $.each(options.data, function (key, value) {
          formData.append(key, value)
        })

        var self = this
        // Send the data and expect a result
        $.ajax({
          url: options.url,
          data: formData,
          type: 'POST',
          dataType: 'text',
          processData: false,
          contentType: false,
          success: function(data) { eval(options.js_callback)(data) },
          error: function(xhr, status, e) { self.error(e) }
        })
      }, 'image/jpeg', 1.0);
    },

    save: function() {
      try {
        this.captureToCanvas()
        var data = this.$canvas[0].toDataURL('image/jpeg', 1.0);
        this.$canvas.remove();
        return data.substring(data.indexOf(',')+1);
      } catch(e) {
        this.error(e);
      }
    },

    canvaToBlob: function(callback, mimeType, q) {
      if (this.$canvas.toBlob) {
        return this.$canvas(callback, mimeType, q)
      }

      // take apart data URL
      var url = this.$canvas[0].toDataURL('image/jpeg', 1.0)
      var parts = url.match(/^data:([^;]+)(;base64)?,(.*)$/)

      // assume base64 encoding
      var binStr = atob(parts[3])

      //convert to binary in ArrayBuffer
      var buf  = new ArrayBuffer(binStr.length)
      var view = new Uint8Array(buf)
      for(var i = 0; i < view.length; i++)
        view[i] = binStr.charCodeAt(i)

      callback(new Blob([view], {'type': parts[1]}))
    },

    captureToCanvas: function()  {
      this.video.pause()

      var canvas = this.$canvas[0]
      var ctx = canvas.getContext('2d')

      // The source video ratio might not be the same as
      // the preview window and needs to be cropped
      var sWidth = canvas.width
      var sHeight = canvas.height
      var sx = (this.video.videoWidth - sWidth) / 2
      var sy = (this.video.videoHeight - sHeight) / 2
      ctx.drawImage(this.video, sx, sy, sWidth, sHeight, 0, 0, sWidth, sHeight)

      this.video.play()
    },
    setCamera:     function(i) { return true; },
    getCameraList: function()  { return [] },
    getResolution: function()  { return [this.video.videoWidth, this.video.videoHeight] },
    pause:         function()  { this.video.pause() },
    play:          function()  { this.video.play() },

    destroy: function() {
      if (this.video.mozSrcObject !== undefined) {
        this.video.mozSrcObject = null
      } else {
        this.video.src = ''
      }
      this.stream.stop()
    }
  })


  navigator.getUserMedia = navigator.getUserMedia || navigator.webkitGetUserMedia || navigator.mozGetUserMedia || navigator.msGetUserMedia
  window.URL = window.URL || window.webkitURL || window.mozURL || window.msURL

  var Webcam;
  if (navigator.getUserMedia) { Webcam = WebcamGum }
  else                        { Webcam = WebcamSwf }

  var old = $.fn.webcam

  $.fn.webcam = function (option) {
    var isMethodCall = typeof option === "string",
      args = Array.prototype.slice.call(arguments, 1),
      returnValue = this

    if (isMethodCall) {
      this.each(function () {
        var methodValue,
          instance = $.data(this, "webcam")

        if (!instance) {
          return $.error("cannot call methods on webcam prior to initialization; " +
            "attempted to call method '" + option + "'")
        }
        if (option.charAt(0) === "_" || !$.isFunction(instance[option])) {
          return $.error( "no such method '" + option + "' for webcam instance")
        }
        methodValue = instance[option].apply(instance, args);
        if (methodValue !== instance && methodValue !== undefined) {
          returnValue = methodValue && methodValue.jquery ?
            returnValue.pushStack(methodValue.get()) :
            methodValue
          return false
        }
      })
    } else {
      return this.each(function () {
        var $this = $(this)
          , data = $this.data('webcam')
          , options = typeof option == 'object' && option
        if (!data) $this.data('webcam', (data = new Webcam(this, options)))
      })
    }
    return returnValue;
  }

  $.fn.webcam.Constructor = Webcam

  $.fn.webcam.defaults = {
    previewWidth: 320,
    previewHeight: 240,

    resolutionWidth: 320,
    resolutionHeight: 240,

    videoDeblocking: 0,
    videoSmoothing: 0,

    bgcolor: '#000000',
    isCameraEnabled: false,
    cameraEnabled:   function () { },
    cameraDisabled:  function () { },
    noCameraFound:   function () { },
    isClientReady:   function () { return true; },
    cameraReady:     function () { },
    error:           function (e) { },
    debug:           function ()  { }
  }

  if (Webcam === WebcamSwf) {
    $.extend($.fn.webcam.defaults, {
      /**
       * Determine if we need to stretch or scale the captured stream
       *
       * @see http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/display/Stage.html#scaleMode
       * @see http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/display/StageScaleMode.html
       */
      stageScaleMode: 'noScale',

      /**
       * Aligns video output on stage
       *
       * @see http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/display/StageAlign.html
       * @see http://help.adobe.com/en_US/FlashPlatform/reference/actionscript/3/flash/display/Stage.html#align
       * Empty value defaults to "centered" option
       */
      stageAlign: 'TL',

      swffile: "sAS3Cam.swf"
    })
  }

  $.fn.webcam.noConflict = function () {
    $.fn.webcam = old
    return this
  }

  $.event.special.webcamdestroy = {
    teardown: function(){
      $(this).data("webcam").destroy();
    }
  }
});
