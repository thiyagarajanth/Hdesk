jQuery(function ($) {
  "use strict";

  /* Cropper */
  $.widget('avatars.cropper', {
    options : {
      previewContainer: '#preview-box',
      cropX:            'crop_x',
      cropY:            'crop_y',
      cropW:            'crop_w',
      cropH:            'crop_h',

      // Private Attributes
      $previewOverflow: null, $previewElem: null, $cropboxElem: null,
      $cropboxContainer: null,
    },

    _create: function () { var s = this.options, self = this;
      this.$cropboxContainer = this.element;
      this.$previewContainer = $(this.options.previewContainer)

      this.previewWidth  = this.$previewContainer.width();
      this.previewHeight = this.$previewContainer.height();
    },

    start: function (imageSource) { var s = this.options, self = this;
      $("<img>", {
        src: imageSource,
        load: function () {
          self.imgWidth = this.width; self.imgHeight = this.height;

          self._initElements(imageSource);
          self.$cropboxElem.load(function () {
            self.editWidth  = self.$cropboxElem.width();
            self.editHeight = self.$cropboxElem.height();

            self._initJcrop();
          });
          this.remove();
        }
      });
    },

    stop: function () {
      $(this.$cropboxContainer).contents().remove();
      this.$previewOverflow.remove();
      this.$previewContainer.find('img').show();
    },

    _initJcrop: function () {
      var ratio  = this.previewWidth / this.previewHeight
      var width  = Math.min(this.editWidth, this.editHeight * ratio)
      var height = Math.min(this.editHeight, this.editWidth / ratio)
      var offset = Math.max(0, (this.editWidth - width) / 2)
      this.$cropboxElem.Jcrop({
        onChange: $.proxy(this._updateCrop, this),
        onSelect: $.proxy(this._updateCrop, this),
        setSelect: [offset, 0, width, height],
        aspectRatio: ratio
      })
    },

    _initElements: function (imageSource) {
      // Create the preview element
      this.$previewContainer.find('img').hide();
      this.$previewOverflow = $('<div>', { css: { overflow: 'hidden', width: '100%', height: '100%' } })
      this.$previewElem = $('<img>', { src: imageSource, css: {
          maxWidth: 'inherit', maxHeight: 'inherit',
          minWidth: 'inherit', minHeight: 'inherit'
        }
      })
      this.$previewElem.appendTo(this.$previewOverflow);
      this.$previewOverflow.appendTo(this.$previewContainer);

      // Create the cropbox element
      this.$cropboxElem = $('<img>', {'class': 'cropbox', src: imageSource});
      this.$cropboxElem.appendTo(this.$cropboxContainer);

      // Create the coordinate input elements
      var self = this;
      $.each(['cropX', 'cropY', 'cropW', 'cropH'], function (i, val) {
        self['$' + val + 'Elem'] = $('<input>', {name: self.options[val], type: 'hidden'});
        self['$' + val + 'Elem'].appendTo(self.$cropboxContainer);
      });
    },

    _updateCrop: function (coords) {
      var w = this.editWidth * this.previewWidth / coords.w
      var h = this.editHeight * this.previewHeight / coords.h
      var x = coords.x * this.previewWidth / coords.w
      var y = coords.y * this.previewHeight / coords.h
      this.$previewElem.css({
        width: Math.round(w) + 'px',
        height: Math.round(h) + 'px',
        marginLeft: '-' + Math.round(x) + 'px',
        marginTop: '-' + Math.round(y) + 'px'
      })

      var rx = this.imgWidth  / this.editWidth;
      var ry = this.imgHeight / this.editHeight;
      this.$cropXElem.val(Math.round(coords.x * rx))
      this.$cropYElem.val(Math.round(coords.y * ry))
      this.$cropWElem.val(Math.round(coords.w * rx))
      this.$cropHElem.val(Math.round(coords.h * ry))
    },

    _destroy: function () {
      this.stop()
    }
  });

  /** WebCam Photographer */
  $.widget('avatars.photographer', {
    options: {
      previewWidth: null, previewHeight: null,
      resolutionWidth: null, resolutionHeight: null,
      swffile:         'sAS3Cam.swf',
      captureButton:   '#capture-webcam',
      startButton:     '#start-webcam',
      stopButton:      '#stop-webcam',
      camerasSelect:   '#capture-cameras select',

      filename: null, filefield: null,
      postUrl: '#', postData: {},
      stageScaleMode: 'noScale', stageAlign: 'TL'
    },

    _create: function () {
      this.element.attr('id', 'photographer_' + this._random());

      this.$webcamContainer = this.element;
      this.$startButton   = $(this.options.startButton);
      this.$stopButton    = $(this.options.stopButton);
      this.$captureButton = $(this.options.captureButton);
      this.$camerasSelect = $(this.options.camerasSelect);

      $.extend(this.options, {
        filename: this.options.filename || this._random() + '.jpg',
        previewWidth: this.options.previewWidth || this.$webcamContainer.width(),
        previewHeight: this.options.previewHeight || this.$webcamContainer.height(),
        resolutionWidth: this.options.resolutionWidth || this.$webcamContainer.width(),
        resolutionHeight: this.options.resolutionHeight || this.$webcamContainer.height()
      });

      var self = this;
      this.$stopButton.click(function(e) { e.preventDefault(); self.stop(); });
      this.$startButton.click(function(e) { e.preventDefault(); self.start(); });
    },

    disable: function () { this.$startButton.prop('disabled', true); },
    enable: function () { this.$startButton.prop('disabled', false); },

    start: function () { var s = this.options, self = this;
      this.$startButton.prop('disabled', true);
      self._trigger('beforestart', null);

      $('<div>').appendTo(this.$webcamContainer).webcam($.extend({}, this.options, {
        noCameraFound:  function () { self._error('Web camera is not available') },
        error:          function (e) { self._error('Internal camera plugin error: ' + (e ? e.name || e : e)) },
        cameraDisabled: function () { self._error('Please allow access to your camera') },
        cameraEnabled:  function () { self._cameraEnabled(this); }
      }));
    },

    stop: function () { var s = this.options;
      this._trigger('beforestop');

      this.$webcamContainer.children().remove();
      this.$captureButton.prop('disabled', true).off('click');
      this.$stopButton.hide().off('click');
      this.$startButton.prop('disabled', false).show();
      this.$camerasSelect.parent().hide();
      this.$camerasSelect.children().remove();
      this.isCameraEnabled = false;
    },

    _cameraEnabled: function(api) { var self = this;
      if (this.isCameraEnabled) { return; }

      this.isCameraEnabled = true;
      this.cameraApi = api;

      setTimeout(function () {
        self.$startButton.hide(); self.$stopButton.show();
        self._showCamerasSelect();
        self.cameraApi.setCamera('0');
        self._trigger('afterstart', null, {api: self.cameraApi, cameras: self.cameraApi.getCameraList()});

        self.$captureButton.prop('disabled', false);
      }, 750);

      this.$captureButton.click(function (e) {
        e.preventDefault();
        var id = self.element.attr('id');
        self._trigger('beforeupload', null, {});
        self.cameraApi.saveAndPost({
          url:          self.options.postUrl,
          filename:     self.options.filename,
          filefield:    self.options.filefield,
          data:         self.options.postData,
          js_callback:  '(function (d) {jQuery(\'#' + id + '\').photographer(\'postCallback\', d);})'
        });
      });
    },

    _showCamerasSelect: function () { var self = this;
      var cams = this.cameraApi.getCameraList();
      if (cams.length <= 1) return;

      this.$camerasSelect.parent().show();
      for (var i = 0; i < cams.length; i++) {
        $('<option>', { val: i, text: cams[i] }).appendTo(this.$camerasSelect);
      }
      this.$camerasSelect.change(function () {
        if (!self.cameraApi.setCamera($(this).val())) {
          self._error('Unable to select camera');
        }
      });
    },

    _error: function (msg) {
      this._trigger('error', null, { message: msg })
    },

    postCallback: function (data) {
      this.stop();
      this._trigger('afterupload', null, { text: data });
    },


    _destroy: function () {
      this.stop();
    },

    _random: function () {
      return Math.floor((Math.random()*99999));
    }
  });

  /** File Uploader */
  $.widget('avatars.uploader', {
    options : {
      attachmentId:         1,
      attachmentsContainer: '#attachments_fields',
      fileFieldContainer:   '.add_attachment'
    },

    _create: function () { var self = this;
      this.element.attr('id', 'uploader_' + this._random());
      this.element.on('change', 'input[type=file]', function () { self.addInputFile(this); });

      this.$fileFieldContainer = $(this.options.fileFieldContainer);
      this.$attachmentsContainer = $(this.options.attachmentsContainer);
    },
    disable: function () { this.$fileFieldContainer.find('input').prop('disabled', true); },
    enable: function () { this.$fileFieldContainer.find('input').prop('disabled', false); },

    addInputFile: function (inputEl) {
      var aFilename    = inputEl.value.split(/\/|\\/);
      var filename     = aFilename[aFilename.length - 1];

      var attachmentId = this.options.attachmentId++;
      var fileSpan = this.createInputField(filename, attachmentId);
      this._ajaxUpload(inputEl, filename, fileSpan, attachmentId);
    },

    createInputField: function (filename, attachmentId) { var self = this;
      var $fileSpan = $('<span>', { id: 'attachments_' + attachmentId });

      this.$fileFieldContainer.hide();
      $fileSpan.on('remove', function () {
        self.$fileFieldContainer.show();
        self._trigger('fileremove', null, { attachmentId: attachmentId });
      });

      $fileSpan.append(
        $('<input>', { type: 'text', 'class': 'filename readonly', name: 'attachment[filename]', readonly: 'readonly'}).val(filename),
        $('<a>&nbsp</a>').attr({ href: '#', 'class': 'remove-upload' }).click(this._removeFile).hide()
      ).appendTo(this.$attachmentsContainer);

      return $fileSpan;
    },

    successAfterUpload: function (data) {
      var $fileSpan = $('#attachments_' + data.attachmentId);
      $fileSpan.append(
        $('<input>', { type: 'hidden', name: 'attachment[token]', value: data.token }),
        $('<input>', { type: 'hidden', name: 'attachment[content_type]', value: data.contentType }));
      $fileSpan.find('a.remove-upload')
        .attr({
          'data-remote': true,
          'data-method': 'delete',
          href: data.deletePath
        })
        .css('display', 'inline-block')
        .off('click');

      this._trigger('afterupload', null, data);
    },

    errorAfterUpload: function (data) {
      this._trigger('error', null, data);
    },

    _ajaxUpload: function (inputEl, filename, fileSpan, attachmentId) { var self = this;
      var clearedFileInput = $(inputEl).clone().val('');
      clearedFileInput.prependTo(this.$fileFieldContainer);

      var progressSpan = $('<div>').insertAfter(fileSpan.find('input.filename'));
      progressSpan.progressbar();
      fileSpan.addClass('ajax-waiting');

      $('<form>').append(inputEl).ajaxSubmit({
        type:           'POST',
        url:            self.options.uploadPath,
        data:           {
          filename:      filename,
          attachment_id: attachmentId,
          uploader:      '#' + self.element.attr('id')
        },
        dataType:       'script',
        delegation:     true,
        beforeSend:     function (jqXhr) {
          jqXhr.setRequestHeader('Accept', 'application/js');
        },
        uploadProgress: function (e, pos, total, percentComplete) {
          progressSpan.progressbar('value', percentComplete);
        },
        beforeSubmit:   function (arr, $form, options) {
          fileSpan.removeClass('ajax-waiting').addClass('ajax-loading');
          $('input:submit', fileSpan.parents('form')).prop('disabled', true);
        },
        success:        function (data, statusText, xhr, $form) {
          progressSpan.progressbar('value', 100).remove();
        },
        error:          function (xhr, textStatus, errorThrown) {
          progressSpan.text(textStatus);
        },
        complete:       function (xhr) {
          fileSpan.removeClass('ajax-loading');
          $('input:submit', fileSpan.parents('form')).prop('disabled', false);
          $(inputEl).parent().remove();
        }
      });
    },

    _removeFile: function (e) {
      e.preventDefault();
      $(e.target).parent('span').remove();
    },

    _random: function () {
      return Math.floor((Math.random()*99999));
    }
  });
});
