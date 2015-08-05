$ ->
  $('input[name=birth_date]').mask('0000-00-00')
  $('input[name=phone]').mask('000-0000-0000')
  $('input[name=activity_hour_from]').mask('00')
  $('input[name=activity_hour_to]').mask('00')
  $("input[name=activity_date]").datepicker(
    todayHighlight: true
    autoclose:      true
    startDate: new Date()
  )
