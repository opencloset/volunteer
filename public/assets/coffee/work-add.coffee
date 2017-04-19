$ ->
  holidays = eval $("input[name=activity-date]").data('holidays')
  $('input[name=birth_date]').mask('0000-00-00')
  $('input[name=phone]').mask('000-0000-0000')
  $("input[name=activity-date]").datepicker(
    todayHighlight: true
    autoclose:      true
    datesDisabled: holidays
    language: 'kr'
  ).on 'changeDate', (e) ->
    $select = $('select[name=activity-hours]')
    $select.get(0).selectedIndex = -1
    ymd = e.currentTarget.value
    $.ajax "/works/hours/#{ymd}",
      type: 'GET'
      dataType: 'json'
      success: (data, textStatus, jqXHR) ->
        $('select[name=activity-hours] option').each ->
          value = $(@).val()
          $(@).prop('disabled', (i, v) -> false)
          $(@).prop('disabled', true) unless data[value]
      error: (jqXHR, textStatus, errorThrown) ->
      complete: (jqXHR, textStatus) ->

  $('select[name=activity-hours]').on 'change', (e) ->
    date = $("input[name=activity-date]").val()
    hour = $(@).find(':selected').val()
    label = $(@).find(':selected').text()
    template = JST['work/activity-datetime-list-item']
    html     = template({ date: date, hour: hour, label: label })
    $('#activity-datetime').append(html)

  $('#activity-datetime').on 'click', '.btn-delete', (e) ->
    $(@).closest('li').remove()

  $('.agree').click ->
    $(@).prev().prop('checked', true)

  $('form[data-toggle]').validator({
    custom:
      highteen: ($el) ->
        ymd = $el.val()
        yyyy = ymd.substr(0, 4)
        return unless yyyy
        return false unless yyyy.length is 4
        return new Date().getFullYear() - yyyy + 1 >= 17
    errors:
      highteen: '17세(고등학생)이상 봉사신청이 가능합니다'
  })
