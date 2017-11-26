// Depends on ./ical_events.js

var recur_events = [];

function moment_icaltime(moment, timezone) {
    // TODO timezone
    return new ICAL.Time().fromJSDate(moment.toDate());
}

function expand_recur_events(start, end, timezone, events_callback) {
    var events = [];
    for (var event of recur_events) {
		var event_properties = event.event_properties;
        expand_recur_event(event, moment_icaltime(start, timezone), moment_icaltime(end, timezone), function(event) {
            fc_event(event, event.eID, function(event) {
                events.push(merge_events(event_properties, merge_events({className:['recur-event']}, event)));
            });
        });
    }
    events_callback(events);
}

function fc_events(ics, eID, event_properties) {
    var events = [];
    ical_events(
        ics,
        function(event){
            fc_event(event, eID, function(event){
                events.push(merge_events(event_properties, event));
            });
        },
        function(event){
            event.event_properties = event_properties;
            recur_events.push(event);
        }
    );
    return events;
}

function merge_events(e, f) {
    // f has priority
    for (var k in e) {
        if (k == 'className') {
            f[k] = [].concat(f[k]).concat(e[k]);
        } else if (! f[k]) {
            f[k] = e[k];
        }
    }
    return f;
}

function fc_event(event, eID, event_callback) {
	var e;
	if(showURL) {
		e = {
			title:event.getFirstPropertyValue('summary'),
			description:event.getFirstPropertyValue('description'),
			location:event.getFirstPropertyValue('location'),
			url:event.getFirstPropertyValue('url'),
			id:event.getFirstPropertyValue('uid'),
			eID: eID, 
			allDay:false
		};
	}
	else {
		e = {
			title:event.getFirstPropertyValue('summary'),
			description:event.getFirstPropertyValue('description'),
			location:event.getFirstPropertyValue('location'),
			id:event.getFirstPropertyValue('uid'),
			eID: eID, 
			allDay:false
		};
	}
	try
	{
		e.start = event.getFirstPropertyValue('dtstart').toJSDate();
  }
  catch (TypeError)
  {
  	console.debug('Undefined "dtstart", vevent skipped.');
    return;
  }
  try
  {
  	e.end = event.getFirstPropertyValue('dtend').toJSDate();
  }
  catch (TypeError)
  {
        e.allDay = true;
  }
	event_callback(e);
}

