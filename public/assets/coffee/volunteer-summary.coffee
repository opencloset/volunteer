$ ->
  $('#btn-comment').click (e) ->
    $('#form-comment').toggleClass('hide')

  $('.btn-cancel').click (e) ->
    $(@).closest('form').addClass('hide')

  $dz  = $('#dropzone')
  email = unescape(location.search.substring(7))
  Dropzone.options.dropzone =
    paramName: $dz.data('dz-name')
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
