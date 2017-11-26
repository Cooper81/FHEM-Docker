$(document).on('ready', function() {
  if ($('#screensaver')) {
    $('#screensaver').hide();
    var mousetimeout;
    var screensaver_active = false;
    var idletime = 60;

    function show_screensaver(){
        $('#screensaver').fadeIn();
        screensaver_active = true;
    }

    function stop_screensaver(){
        $('#screensaver').fadeOut();
        screensaver_active = false;
    }
