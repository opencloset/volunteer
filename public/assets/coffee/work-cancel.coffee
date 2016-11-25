$ ->
  $('#btn-cancel').click ->
    $this = $(@)
    $.ajax $this.data('url'),
      type: 'PUT'
      dataType: 'json'
      data: { status: 'canceled' }
      success: (data, textStatus, jqXHR) ->
        $('p').remove()
        $('<p>취소되었습니다.</p>').insertAfter('h4')
      error: (jqXHR, textStatus, errorThrown) ->
        $('p').remove()
        $('<p>에러가 발생했습니다 새로고침 후에 다시 시도해주세요.</p>').insertAfter('h4')
      complete: (jqXHR, textStatus) ->
