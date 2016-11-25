$.facebox.settings.closeImage   = '/assets/components/facebox/src/closelabel.png'
$.facebox.settings.loadingImage = '/assets/components/facebox/src/loading.gif'

$ ->
  holidays = eval $("input[name=activity-date]").data('holidays')
  $('input[name=birth_date]').mask('0000-00-00')
  $('input[name=phone]').mask('000-0000-0000')
  $("input[name=activity-date]").datepicker(
    todayHighlight: true
    autoclose:      true
    startDate: '+1d'
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

  $('a[rel*=facebox]').facebox()
