$ ->
  holidays = eval $("input[name=activity-date]").data('holidays')
  $('input[name=birth_date]').mask('0000-00-00')
  $('input[name=phone]').mask('000-0000-0000')
  $("input[name=activity-date]").datepicker(
    todayHighlight: true
    autoclose:      true
    startDate: new Date()
    daysOfWeekDisabled: [0]
    datesDisabled: holidays
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
