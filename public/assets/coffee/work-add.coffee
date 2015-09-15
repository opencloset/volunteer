# [2015-01-01] 신정(新正
# [2015-02-18] 설날
# [2015-02-19] 설날
# [2015-02-20] 설날
# [2015-03-01] 3.1절(三一節)
# [2015-04-05] 식목일
# [2015-05-05] 어린이날
# [2015-05-08] 학부모날
# [2015-05-25] 석가탄신일(釋迦誕辰日)
# [2015-06-06] 현충일(顯忠日)
# [2015-07-17] 제헌절(制憲節)
# [2015-08-14] 광복절(光復節)
# [2015-08-15] 광복절(光復節)
# [2015-09-26] 추석(秋夕)
# [2015-09-27] 추석(秋夕)
# [2015-09-28] 추석(秋夕)
# [2015-09-29] 추석(秋夕)
# [2015-10-01] 국군 의 날
# [2015-10-03] 개천절(開天節)
# [2015-10-09] 한글날
# [2015-12-24] 크리스마스 이브
# [2015-12-25] 크리스마스 주
# [2015-12-31] 섣달 그믐날
holidays = ['2015-01-01','2015-02-18','2015-02-19','2015-02-20','2015-03-01','2015-05-05','2015-05-08','2015-05-25','2015-06-06','2015-07-17','2015-08-14','2015-08-15','2015-09-26','2015-09-27','2015-09-28','2015-09-29','2015-10-03','2015-10-09','2015-12-25']

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
