$ ->
  $('#btn-comment').click (e) ->
    $('#form-comment').toggleClass('hide')

  $('.btn-cancel').click (e) ->
    $(@).closest('form').addClass('hide')

  $dz  = $('#dropzone')
  email = unescape(location.search.substring(7))
  Dropzone.options.dropzone =
    paramName: $dz.data('dz-name')
    ## screen.less => .dropzone .dz-preview .dz-image
    ## partials/dropzone.html.ep, thumbnail => oavatar_url($email, size => *300*)
    thumbnailWidth: 300
    thumbnailHeight: 300
    maxFiles: 1
    init: ->
      mockFile = { name: 'photo', size: 12345 }
      @emit('addedfile', mockFile)
      @emit('thumbnail', mockFile, $dz.data('dz-thumbnail'))
      @emit('complete', mockFile)
      @on 'sending', (file, xhr, formData) ->
        formData.append('key', email)
      @on 'success', (file) ->
        @emit('removedfile', mockFile)
