# [2016-01-01] 신정(新正
# [2016-02-07] 설날
# [2016-02-08] 설날
# [2016-02-09] 설날
# [2016-02-10] 설날
# [2016-03-01] 3.1절(三一節)
# [2016-04-05] 식목일
# [2016-05-05] 어린이날
# [2016-05-08] 학부모날
# [2016-05-14] 석가탄신일(釋迦誕辰日)
# [2016-06-06] 현충일(顯忠日)
# [2016-07-17] 제헌절(制憲節)
# [2016-08-15] 광복절(光復節)
# [2016-09-14] 추석(秋夕)
# [2016-09-15] 추석(秋夕)
# [2016-09-16] 추석(秋夕)
# [2016-10-01] 국군 의 날
# [2016-10-03] 개천절(開天節)
# [2016-10-09] 한글날
# [2016-12-24] 크리스마스 이브
# [2016-12-25] 크리스마스 주
# [2016-12-31] 섣달 그믐날
holidays = ['2016-01-01','2016-02-07','2016-02-08','2016-02-09','2016-02-10','2016-03-01','2016-05-05','2016-05-14','2016-06-06','2016-08-15','2016-09-14','2016-09-15','2016-09-16','2016-10-03','2016-10-09','2016-12-25']

$ ->
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
