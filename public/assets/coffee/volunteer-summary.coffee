$ ->
  $('#btn-comment').click (e) ->
    $('#form-comment').toggleClass('hide')

  $('.btn-cancel').click (e) ->
    $(@).closest('form').addClass('hide')
